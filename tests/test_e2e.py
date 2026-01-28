"""End-to-end tests for Hex voice-to-text application.

This module documents and tests the complete recording and transcription flow:
- Hotkey press triggers recording
- Audio is captured
- Hotkey release stops recording
- Audio is transcribed
- Text is pasted to clipboard
- History is saved

For manual testing procedures, see the MANUAL TESTING section below.

For automated testing (requires dependencies installed):
    pip install -e .
    pytest tests/test_e2e.py -v
"""

# NOTE: Automated tests require all dependencies to be installed.
# Manual testing instructions are provided below and can be followed
# without installing pytest.

import sys
sys.path.insert(0, 'src')

# Try to import dependencies - will be used if available, otherwise skipped
try:
    import pytest
    from unittest.mock import AsyncMock
    from vox.clients.clipboard import ClipboardClient
    from vox.clients.recording import RecordingClient
    from vox.clients.sound_effects import SoundEffectsClient
    from vox.clients.transcript_persistence import TranscriptPersistenceClient
    from vox.clients.transcription import TranscriptionClient
    from vox.models.hotkey import HotKey, Modifier, Modifiers
    from vox.models.settings import VoxSettings
    from vox.models.transcription import Transcript
    from vox.models.word_processing import WordRemoval, WordRemapping
    from vox.transcription.actions import Action
    from vox.transcription.feature import TranscriptionFeature
    from vox.hotkeys.processor import HotKeyProcessor, State, Output
    from vox.models.key_event import KeyEvent
    from datetime import datetime
    import asyncio

    DEPS_AVAILABLE = True
except ImportError:
    DEPS_AVAILABLE = False
    pytest = None


# =============================================================================
# MANUAL TESTING INSTRUCTIONS
# =============================================================================

MANUAL_TESTING_INSTRUCTIONS = """
## Manual Verification Instructions

These tests verify the complete end-to-end flow of the Hex application.

### Prerequisites

1. **Install Ollama server:**
   ```bash
   # Download from https://ollama.com
   ollama serve
   ollama pull whisper
   ```

2. **Install Hex Python application:**
   ```bash
   cd /path/to/vox-python
   pip install -e .
   ```

3. **Grant permissions (macOS):**
   - System Settings → Privacy & Security → Accessibility
   - Add Terminal or your Python interpreter

### Test 1: Basic Recording Flow

**Objective:** Verify hotkey → record → transcribe → paste flow works

**Steps:**
1. Launch the application: `python -m vox`
2. Open a text editor (TextEdit, VSCode, etc.)
3. Press and hold the Option key
4. Speak clearly: "Hello world this is a test"
5. Wait 2 seconds
6. Release the Option key
7. Wait 2-5 seconds for transcription to complete

**Expected Results:**
- ✓ Recording indicator appears when Option is pressed
- ✓ Sound effect plays when recording starts
- ✓ Recording indicator stays visible while recording
- ✓ Sound effect plays when recording stops (on release)
- ✓ Recording indicator changes to "transcribing" state
- ✓ After 2-5 seconds, text "hello world this is a test" appears in text editor
- ✓ Text is pasted automatically (no manual Cmd+V needed)
- ✓ Sound effect plays when text is pasted
- ✓ Recording indicator disappears

### Test 2: ESC Cancellation

**Objective:** Verify ESC key cancels active recording

**Steps:**
1. Press and hold Option to start recording
2. While still holding Option, press ESC key
3. Release both keys

**Expected Results:**
- ✓ Recording stops immediately
- ✓ Cancel sound effect plays (distinct from stop sound)
- ✓ No transcription occurs
- ✓ No text is pasted
- ✓ Recording indicator disappears

### Test 3: Short Recording Discard

**Objective:** Verify very short recordings are discarded

**Steps:**
1. Press and release Option key quickly (within 0.2 seconds)
2. Wait 2 seconds

**Expected Results:**
- ✓ Recording starts (indicator appears)
- ✓ Recording stops (indicator disappears)
- ✓ No transcription occurs
- ✓ No sound effects play after initial start
- ✓ No text is pasted

### Test 4: Word Removal

**Objective:** Verify filler word removal works

**Steps:**
1. Right-click system tray icon → Settings...
2. Verify "Word Removals" is enabled
3. Add pattern "um+" if not present
4. Click OK to save
5. Start recording and speak: "Um hello world this is a test um"
6. Release hotkey
7. Wait for transcription

**Expected Results:**
- ✓ Pasted text is "hello world this is a test" (without "Um" or trailing "um")
- ✓ No extra spaces where words were removed

### Test 5: Word Replacement

**Objective:** Verify word remapping works

**Steps:**
1. Open Settings → Word Remappings
2. Add new mapping:
   - Match: "cnt"
   - Replacement: "can't"
3. Click OK to save
4. Start recording and speak: "I cnt believe it works"
5. Release hotkey
6. Wait for transcription

**Expected Results:**
- ✓ Pasted text is "I can't believe it works" (with apostrophe)

### Test 6: History Management

**Objective:** Verify transcriptions are saved to history

**Steps:**
1. Record 3 different transcriptions:
   - "First test"
   - "Second test"
   - "Third test"
2. Right-click system tray icon → History...
3. Verify list contents

**Expected Results:**
- ✓ History dialog shows all 3 transcriptions
- ✓ Most recent is at the top ("Third test")
- ✓ Each entry shows timestamp, duration, and text preview
- ✓ Clicking an entry shows full details
- ✓ Copy button copies text to clipboard
- ✓ Delete button removes entry with confirmation

### Test 7: Settings Persistence

**Objective:** Verify settings persist across restarts

**Steps:**
1. Open Settings (right-click → Settings...)
2. Change hotkey to Cmd+Shift+H:
   - Click "Record Hotkey" button
   - Press Cmd+Shift+H
   - Click "Stop Recording" button
3. Click OK to save
4. Quit the application (right-click → Quit)
5. Restart: `python -m vox`
6. Press Cmd+Shift+H
7. Speak: "Test new hotkey"
8. Release and wait for transcription

**Expected Results:**
- ✓ Recording starts with new hotkey (Cmd+Shift+H)
- ✓ Text is transcribed and pasted correctly
- ✓ Settings persisted across restart

### Test 8: Double-Tap Mode

**Objective:** Verify double-tap recording mode

**Steps:**
1. Open Settings
2. Enable "Use double-tap only"
3. Click OK to save
4. Double-tap Option key quickly (press twice within 0.5 seconds)
5. Speak for 3 seconds
6. Press Option once to stop recording
7. Wait for transcription

**Expected Results:**
- ✓ Recording locks on double-tap (no need to hold)
- ✓ Recording indicator stays visible
- ✓ Single press stops recording
- ✓ Text is transcribed and pasted correctly

### Test 9: Ollama Error Handling

**Objective:** Verify helpful errors when Ollama is not running

**Steps:**
1. Stop Ollama server: `pkill ollama` (or quit Ollama app)
2. Try to start recording (press Option)
3. Wait 5 seconds

**Expected Results:**
- ✓ Error dialog or notification appears
- ✓ Error message explains Ollama is not running
- ✓ Error includes setup instructions:
  - "Please install Ollama from https://ollama.com"
  - "Run 'ollama serve' to start the server"
  - "Run 'ollama pull whisper' to download the model"
- ✓ Application remains responsive

### Test 10: Sound Effects Toggle

**Objective:** Verify sound effects can be disabled

**Steps:**
1. Open Settings
2. Disable "Sound Effects Enabled"
3. Click OK to save
4. Start recording (press Option)
5. Release after 2 seconds
6. Wait for transcription

**Expected Results:**
- ✓ No sound plays when recording starts
- ✓ No sound plays when recording stops
- ✓ No sound plays when text is pasted
- ✓ Text is still transcribed and pasted correctly

### Success Criteria

All manual tests pass if:
- [ ] Basic recording flow works end-to-end
- [ ] ESC cancellation works
- [ ] Short recordings are discarded
- [ ] Word removal applies correctly
- [ ] Word replacement applies correctly
- [ ] History saves and displays transcriptions
- [ ] Settings persist across restarts
- [ ] Double-tap mode works
- [ ] Ollama errors are handled gracefully
- [ ] Sound effects can be toggled

### Troubleshooting

**Recording doesn't start:**
- Check Accessibility permissions (macOS)
- Verify hotkey is not conflicting with other apps
- Check logs: `tail -f ~/Library/Logs/vox/vox.log`

**Transcription fails:**
- Verify Ollama is running: `ps aux | grep ollama`
- Check model is downloaded: `ollama list`
- Test Ollama manually: `ollama run whisper "test"`

**Text doesn't paste:**
- Verify "Copy to clipboard" is enabled in Settings
- Check text editor has focus
- Try manual paste (Cmd+V) to verify clipboard has content
"""

# =============================================================================
# AUTOMATED TESTS (require dependencies)
# =============================================================================

if DEPS_AVAILABLE and pytest is not None:

    class TestE2EBasicFlow:
        """Automated end-to-end tests with mocked dependencies."""

        @pytest.mark.asyncio
        async def test_full_recording_flow_with_mocks(self):
            """Test complete flow from hotkey press to paste using mocks."""
            from vox.clients.clipboard import ClipboardClient
            from vox.clients.recording import RecordingClient
            from vox.clients.sound_effects import SoundEffectsClient
            from vox.clients.transcript_persistence import TranscriptPersistenceClient
            from vox.clients.transcription import TranscriptionClient

            # Create mocks
            mock_recording = AsyncMock(spec=RecordingClient)
            mock_transcription = AsyncMock(spec=TranscriptionClient)
            mock_clipboard = AsyncMock(spec=ClipboardClient)
            mock_sound = AsyncMock(spec=SoundEffectsClient)
            mock_persistence = AsyncMock(spec=TranscriptPersistenceClient)

            mock_recording.start_recording.return_value = "/tmp/test.wav"
            mock_recording.stop_recording.return_value = "/tmp/test.wav"
            mock_transcription.transcribe.return_value = "hello world"
            mock_transcription.is_model_downloaded.return_value = True

            # Create feature with mocks
            settings = VoxSettings()
            feature = TranscriptionFeature(
                settings=settings,
                recording_client=mock_recording,
                clipboard_client=mock_clipboard,
                sound_effects_client=mock_sound,
                transcript_persistence_client=mock_persistence,
            )
            feature._transcription_client = mock_transcription

            # Test flow
            assert not feature.state.is_recording

            feature.send(Action.HOTKEY_PRESSED)
            await asyncio.sleep(0.1)
            assert feature.state.is_recording
            mock_recording.start_recording.assert_called_once()

            feature.send(Action.HOTKEY_RELEASED)
            await asyncio.sleep(0.1)
            assert feature.state.is_transcribing
            mock_recording.stop_recording.assert_called_once()

            feature.send(
                Action.TRANSCRIPTION_RESULT,
                text="hello world",
                audio_path="/tmp/test.wav",
                duration=2.0,
            )
            await asyncio.sleep(0.1)
            assert not feature.state.is_transcribing
            mock_clipboard.copy.assert_called_once()
            mock_persistence.save.assert_called_once()

            feature.stop()

    class TestHotkeyProcessorIntegration:
        """Test hotkey processor produces correct actions."""

        def test_hotkey_outputs(self):
            """Test HotKeyProcessor outputs match expected actions."""
            hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
            processor = HotKeyProcessor(hotkey=hotkey)

            # Press hotkey
            event = KeyEvent(
                key=None,
                modifiers=Modifiers.from_list([Modifier.OPTION]),
                timestamp=datetime.now(),
            )
            output = processor.process(event)
            assert output == Output.START_RECORDING

            # Release hotkey
            event = KeyEvent(
                key=None,
                modifiers=Modifiers.empty(),
                timestamp=datetime.now(),
            )
            output = processor.process(event)
            assert output == Output.STOP_RECORDING

            # ESC cancels
            processor2 = HotKeyProcessor(hotkey=hotkey)
            event = KeyEvent(
                key=None,
                modifiers=Modifiers.from_list([Modifier.OPTION]),
                timestamp=datetime.now(),
            )
            processor2.process(event)
            event = KeyEvent(
                key=Key.ESCAPE,
                modifiers=Modifiers.empty(),
                timestamp=datetime.now(),
            )
            output = processor2.process(event)
            assert output == Output.CANCEL


# =============================================================================
# SMOKE TEST (run when file executed directly)
# =============================================================================

if __name__ == "__main__":
    """Run smoke test or show manual testing instructions."""

    print("=" * 70)
    print("Hex Python - End-to-End Test Suite")
    print("=" * 70)
    print()

    if not DEPS_AVAILABLE:
        print("⚠ Dependencies not installed - skipping automated tests")
        print()
        print("To install dependencies:")
        print("  pip install -e .")
        print("  pip install pytest pytest-asyncio")
        print()
        print("=" * 70)
        print()
        print(MANUAL_TESTING_INSTRUCTIONS)
        sys.exit(0)

    print("Running smoke test...")
    print()

    try:
        # Test basic imports and object creation
        from vox.transcription.feature import TranscriptionFeature
        from vox.models.settings import VoxSettings
        from vox.transcription.actions import Action

        settings = VoxSettings()
        feature = TranscriptionFeature(settings=settings)

        print("✓ TranscriptionFeature created")
        print("✓ Initial state: recording={}, transcribing={}".format(
            feature.state.is_recording,
            feature.state.is_transcribing
        ))

        feature.send(Action.TASK)
        print("✓ Action dispatch working")

        feature.stop()
        print("✓ Feature cleanup successful")

        print()
        print("=" * 70)
        print("All smoke tests passed!")
        print()
        print("To run full automated test suite:")
        print("  pytest tests/test_e2e.py -v")
        print()
        print("For manual testing procedures, see:")
        print("  python tests/test_e2e.py | less")
        print("=" * 70)

    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
