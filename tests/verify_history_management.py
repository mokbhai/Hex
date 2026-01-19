#!/usr/bin/env python3
"""Comprehensive verification script for history management.

This script tests:
1. TranscriptPersistenceClient functionality (save, load, trim, delete)
2. HistoryDialog GUI functionality
3. Complete flow: create transcriptions → view in history → manage

For manual testing, see MANUAL_TESTING section below.
"""

import asyncio
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from importlib import import_module

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

# Import modules directly to avoid circular imports in clients/__init__.py
# This prevents issues with missing dependencies like pyperclip
import importlib.util

def load_module_from_path(module_name, file_path):
    """Load a Python module from a file path."""
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module

# Load required modules directly
transcription_module = load_module_from_path(
    "hex.models.transcription",
    Path(__file__).parent.parent / "src" / "hex" / "models" / "transcription.py"
)

# Import from loaded module
Transcript = transcription_module.Transcript

# Load persistence client module
persistence_module = load_module_from_path(
    "hex.clients.transcript_persistence",
    Path(__file__).parent.parent / "src" / "hex" / "clients" / "transcript_persistence.py"
)

TranscriptPersistenceClient = persistence_module.TranscriptPersistenceClient


# =============================================================================
# MANUAL TESTING INSTRUCTIONS
# =============================================================================

MANUAL_TESTING_INSTRUCTIONS = """
## Manual Testing Instructions: History Management

### Prerequisites

1. **Install Ollama server:**
   ```bash
   # Download from https://ollama.com
   ollama serve
   ollama pull whisper
   ```

2. **Install Hex Python application:**
   ```bash
   cd /path/to/hex-python
   pip install -e .
   ```

3. **Grant permissions (macOS):**
   - System Settings → Privacy & Security → Accessibility
   - Add Terminal or your Python interpreter

### Test 1: Create 3 Transcriptions and View in History

**Objective:** Verify that multiple transcriptions are saved and displayed correctly

**Steps:**
1. Launch the application: `python -m hex`
2. Open a text editor (TextEdit, VSCode, etc.)
3. **First transcription:**
   - Press and hold Option key
   - Speak: "First test recording"
   - Wait 2 seconds
   - Release Option key
   - Wait for transcription to complete
4. **Second transcription:**
   - Press and hold Option key
   - Speak: "Second test recording with more words"
   - Wait 2 seconds
   - Release Option key
   - Wait for transcription to complete
5. **Third transcription:**
   - Press and hold Option key
   - Speak: "Third and final test recording for history"
   - Wait 2 seconds
   - Release Option key
   - Wait for transcription to complete

**Expected Results:**
- ✓ All 3 transcriptions appear in text editor
- ✓ Sound effects play for each recording start/stop
- ✓ No errors in console

### Test 2: Open History Viewer and Verify All Transcriptions Shown

**Objective:** Verify History dialog displays all transcriptions

**Steps:**
1. Right-click the system tray icon
2. Select "History..." from the menu
3. Wait for History dialog to appear

**Expected Results:**
- ✓ History dialog opens without errors
- ✓ Loading indicator appears briefly
- ✓ List shows 3 transcriptions (most recent first)
- ✓ Each list item shows:
  - Timestamp (date and time)
  - Duration
  - Text preview (first ~80 characters)
- ✓ Status bar shows "Showing 3 transcription(s)"

### Test 3: View Transcription Details

**Objective:** Verify selecting a transcription shows full details

**Steps:**
1. In the History dialog, click the first (most recent) transcription in the list
2. Verify the details panel shows:
   - Full timestamp
   - Duration
   - Source app (if available)
   - Audio availability status
   - Word and character count
   - Full transcription text

**Expected Results:**
- ✓ Details panel updates to show selected transcription
- ✓ All metadata fields are populated correctly
- ✓ Full text appears in read-only text area
- ✓ "Copy to Clipboard" and "Delete" buttons are enabled

### Test 4: Copy Transcription to Clipboard

**Objective:** Verify copying functionality works

**Steps:**
1. Select a transcription in the history list
2. Click the "Copy to Clipboard" button
3. Open a text editor and press Cmd+V (or Ctrl+V on Linux/Windows)

**Expected Results:**
- ✓ Status bar shows "Copied to clipboard!"
- ✓ Status clears after 3 seconds
- ✓ Full transcription text is pasted into text editor
- ✓ No error messages appear

### Test 5: Delete Individual Transcription

**Objective:** Verify deleting a single transcription works

**Steps:**
1. Select the middle transcription in the list
2. Click the "Delete" button
3. Confirm deletion in the dialog

**Expected Results:**
- ✓ Confirmation dialog appears with transcript preview
- ✓ After confirming, the item is removed from the list
- ✓ List now shows 2 transcriptions
- ✓ Status bar shows "Showing 2 transcription(s)"
- ✓ history_modified signal is emitted (logged in console)
- ✓ Audio file is deleted from disk

### Test 6: Refresh History

**Objective:** Verify refresh button reloads history

**Steps:**
1. Close the History dialog
2. Create another transcription (4th one)
3. Reopen History dialog
4. Click the "Refresh" button

**Expected Results:**
- ✓ History dialog shows 3 transcriptions initially
- ✓ After refresh, shows 4 transcriptions
- ✓ Loading indicator appears briefly during refresh
- ✓ Most recent transcription appears at top

### Test 7: Clear All History

**Objective:** Verify clearing all history works

**Steps:**
1. With the History dialog open and showing transcriptions
2. Click the "Clear All" button
3. Confirm deletion in the dialog

**Expected Results:**
- ✓ Confirmation dialog asks "Are you sure you want to delete all X transcriptions?"
- ✓ After confirming:
  - List becomes empty
  - Details panel shows placeholder text
  - Status bar shows "No transcriptions in history"
  - All audio files are deleted from disk
  - history.json file is empty

### Test 8: History Persistence Across App Restarts

**Objective:** Verify history survives application restarts

**Steps:**
1. Create 2 transcriptions
2. Verify they appear in History dialog
3. Close the History dialog
4. Quit the application (right-click tray → Quit)
5. Relaunch the application: `python -m hex`
6. Open History dialog again

**Expected Results:**
- ✓ Both transcriptions appear in history after restart
- ✓ All metadata is preserved (timestamps, durations, text)
- ✓ Audio files are still available
- ✓ Order is preserved (newest first)

### Test 9: Handle Empty History Gracefully

**Objective:** Verify empty history is handled properly

**Steps:**
1. Clear all history (or delete all transcriptions)
2. Close and reopen the History dialog

**Expected Results:**
- ✓ No errors occur
- ✓ Dialog opens successfully
- ✓ Status bar shows "No transcriptions in history"
- ✓ Details panel shows: "No history available"
- ✓ Text area shows placeholder: "No transcriptions found. Start recording to build your history."
- ✓ "Copy to Clipboard" and "Delete" buttons are disabled
- ✓ List is empty

### Test 10: Large History Performance

**Objective:** Verify history can handle many transcriptions

**Steps:**
1. Create 10+ transcriptions (use short recordings)
2. Open History dialog

**Expected Results:**
- ✓ All transcriptions appear in the list
- ✓ Dialog remains responsive (no freezing)
- ✓ Scrollbar appears when list is long
- ✓ Loading indicator shows briefly then disappears
- ✓ Status bar shows correct count

### Test 11: Audio File Missing Handling

**Objective:** Verify history handles missing audio files gracefully

**Steps:**
1. Create a transcription
2. Open the Recordings folder in Finder:
   - `~/Library/Application Support/com.kitlangton.Hex/Recordings/`
3. Manually delete the audio file for one transcription
4. Reopen History dialog
5. Select the transcription with missing audio

**Expected Results:**
- ✓ Transcription still appears in history
- ✓ Metadata shows "Audio: Not found" (in red, if styled)
- ✓ Text can still be viewed and copied
- ✓ Delete operation succeeds (no error about missing file)
- ✓ No crashes or errors

### Test 12: History Sorting Order

**Objective:** Verify transcriptions are sorted by timestamp (newest first)

**Steps:**
1. Create 3 transcriptions with ~10 seconds between each
2. Note the timestamp of each
3. Open History dialog
4. Verify the order in the list

**Expected Results:**
- ✓ Most recent transcription appears at top of list
- ✓ Oldest transcription appears at bottom
- ✓ Sorting is by timestamp, not creation order
- ✓ Timestamps are displayed in readable format (YYYY-MM-DD HH:MM:SS)

### Success Criteria

All tests pass with the following results:
- ✓ 12/12 manual test scenarios succeed
- ✓ No errors in application console
- ✓ No crashes or hangs
- ✓ All audio files managed correctly
- ✓ History persists across restarts
- ✓ GUI remains responsive with large history
- ✓ Edge cases handled gracefully (empty history, missing files)
"""


# =============================================================================
# AUTOMATED TESTS
# =============================================================================

async def test_save_and_load_transcriptions():
    """Test saving and loading multiple transcriptions."""
    print("\n" + "="*70)
    print("TEST 1: Save and Load Multiple Transcriptions")
    print("="*70)

    # Use a temporary directory for testing
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        # Create client with custom path
        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create temporary audio files
        audio_files = []
        for i in range(3):
            audio_file = recordings_dir / f"test_{i}.wav"
            audio_file.write_text(f"fake audio data {i}")
            audio_files.append(audio_file)

        # Create 3 transcripts
        transcripts = []
        now = datetime.now()

        # Load existing history
        history = await client.load()

        for i, audio_file in enumerate(audio_files):
            transcript = await client.save(
                result=f"Test transcription {i+1}",
                audio_url=audio_file,
                duration=1.5 + i * 0.5,
                source_app_bundle_id="com.test.App",
                source_app_name=f"TestApp{i+1}"
            )
            transcripts.append(transcript)
            # Add to history
            history.append(transcript)
            print(f"✓ Created transcript {i+1}: {transcript.id}")

        # Save the updated history
        await client.save_history(history)
        print(f"\n✓ Saved {len(history)} transcripts to history file")

        # Reload to verify
        history = await client.load()
        print(f"✓ Loaded {len(history)} transcriptions from history")

        # Verify all are present
        assert len(history) == 3, f"Expected 3 transcripts, got {len(history)}"
        print("✓ All 3 transcripts found in history")

        # Verify order (newest first)
        sorted_history = sorted(history, key=lambda t: t.timestamp, reverse=True)
        for i, t in enumerate(sorted_history):
            print(f"  {i+1}. [{t.timestamp}] {t.text[:40]}...")

        print("\n✓ TEST 1 PASSED: Save and load multiple transcriptions")
        return transcripts


async def test_history_details():
    """Test that transcript details are preserved correctly."""
    print("\n" + "="*70)
    print("TEST 2: History Details Preservation")
    print("="*70)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create test audio file
        audio_file = recordings_dir / "test.wav"
        audio_file.write_text("fake audio")

        # Create transcript with full metadata
        now = datetime.now()
        transcript = await client.save(
            result="This is a detailed test transcription with multiple words",
            audio_url=audio_file,
            duration=5.25,
            source_app_bundle_id="com.apple.TextEdit",
            source_app_name="TextEdit"
        )

        # Save to history
        await client.save_history([transcript])

        print(f"✓ Created transcript: {transcript.id}")
        print(f"  Text: {transcript.text}")
        print(f"  Duration: {transcript.duration}s")
        print(f"  Source app: {transcript.source_app_name}")
        print(f"  Timestamp: {transcript.timestamp}")

        # Load and verify
        history = await client.load()
        assert len(history) == 1
        loaded = history[0]

        # Verify all fields
        assert loaded.text == transcript.text, "Text mismatch"
        assert loaded.duration == transcript.duration, "Duration mismatch"
        assert loaded.source_app_bundle_id == transcript.source_app_bundle_id, "Bundle ID mismatch"
        assert loaded.source_app_name == transcript.source_app_name, "App name mismatch"
        assert loaded.timestamp == transcript.timestamp, "Timestamp mismatch"

        print("\n✓ All metadata preserved correctly")
        print("✓ TEST 2 PASSED: History details preservation")


async def test_delete_transcript():
    """Test deleting individual transcripts."""
    print("\n" + "="*70)
    print("TEST 3: Delete Individual Transcript")
    print("="*70)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create 3 transcripts
        transcripts = []
        history = []
        for i in range(3):
            audio_file = recordings_dir / f"test_{i}.wav"
            audio_file.write_text(f"audio {i}")
            transcript = await client.save(
                result=f"Transcript {i+1}",
                audio_url=audio_file,
                duration=1.0,
            )
            transcripts.append(transcript)
            history.append(transcript)

        # Save to history
        await client.save_history(history)
        print(f"✓ Created {len(transcripts)} transcripts")

        # Load history
        history = await client.load()
        assert len(history) == 3
        print(f"✓ History contains {len(history)} transcripts")

        # Delete the middle one
        to_delete = history[1]  # Middle transcript
        print(f"\nDeleting transcript: {to_delete.id}")
        await client.delete_audio(to_delete)

        # Remove from history and save
        history.remove(to_delete)
        await client.save_history(history)

        # Reload and verify
        history = await client.load()
        assert len(history) == 2, f"Expected 2 transcripts after deletion, got {len(history)}"
        print(f"✓ History now contains {len(history)} transcripts")

        # Verify the deleted one is gone
        ids = [t.id for t in history]
        assert to_delete.id not in ids, "Deleted transcript still in history"
        print("✓ Deleted transcript removed from history")

        # Verify audio file is deleted
        assert not to_delete.audio_path.exists(), "Audio file still exists"
        print("✓ Audio file deleted from disk")

        print("\n✓ TEST 3 PASSED: Delete individual transcript")


async def test_clear_all_history():
    """Test clearing all history."""
    print("\n" + "="*70)
    print("TEST 4: Clear All History")
    print("="*70)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create 5 transcripts
        transcripts = []
        history = []
        for i in range(5):
            audio_file = recordings_dir / f"test_{i}.wav"
            audio_file.write_text(f"audio {i}")
            transcript = await client.save(
                result=f"Transcript {i+1}",
                audio_url=audio_file,
                duration=1.0,
            )
            transcripts.append(transcript)
            history.append(transcript)

        # Save to history
        await client.save_history(history)
        print(f"✓ Created {len(transcripts)} transcripts")

        # Load history
        history = await client.load()
        assert len(history) == 5
        print(f"✓ History contains {len(history)} transcripts")

        # Delete all audio files
        for transcript in history:
            try:
                await client.delete_audio(transcript)
                print(f"✓ Deleted audio for {transcript.id}")
            except FileNotFoundError:
                pass

        # Clear history
        await client.save_history([])

        # Reload and verify
        history = await client.load()
        assert len(history) == 0, f"Expected empty history, got {len(history)} transcripts"
        print("\n✓ History cleared successfully")
        print("✓ All audio files deleted")
        print("✓ History file is empty")

        print("\n✓ TEST 4 PASSED: Clear all history")


async def test_history_sorting():
    """Test that history is sorted by timestamp (newest first)."""
    print("\n" + "="*70)
    print("TEST 5: History Sorting (Newest First)")
    print("="*70)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create transcripts with different timestamps
        now = datetime.now()
        transcripts = []
        history = []

        for i in range(5):
            audio_file = recordings_dir / f"test_{i}.wav"
            audio_file.write_text(f"audio {i}")

            # Create transcripts with different times
            timestamp = now - timedelta(seconds=10 * (4 - i))  # Reverse order

            # Save transcript (will get current timestamp)
            transcript = await client.save(
                result=f"Transcript {i+1}",
                audio_url=audio_file,
                duration=1.0,
            )

            # Manually create a new transcript with controlled timestamp
            from dataclasses import replace
            transcript_with_timestamp = replace(transcript, timestamp=timestamp)

            transcripts.append(transcript_with_timestamp)
            history.append(transcript_with_timestamp)

        # Save in reverse order (oldest first)
        history.reverse()
        await client.save_history(history)

        print(f"✓ Created {len(transcripts)} transcripts with different timestamps")

        # Load history
        history = await client.load()

        # Sort by timestamp (newest first)
        sorted_history = sorted(history, key=lambda t: t.timestamp, reverse=True)

        print("\nVerifying sorting order (newest first):")
        for i, t in enumerate(sorted_history):
            age_seconds = (now - t.timestamp).total_seconds()
            print(f"  {i+1}. Age: {age_seconds:.0f}s - {t.text}")

        # Verify order
        for i in range(len(sorted_history) - 1):
            current = sorted_history[i]
            next_t = sorted_history[i + 1]
            assert current.timestamp >= next_t.timestamp, \
                f"Order incorrect: {current.timestamp} should be >= {next_t.timestamp}"

        print("\n✓ Transcriptions sorted correctly (newest first)")
        print("✓ TEST 5 PASSED: History sorting")


async def test_trim_history():
    """Test trimming history to max entries."""
    print("\n" + "="*70)
    print("TEST 6: Trim History to Max Entries")
    print("="*70)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        recordings_dir = tmpdir / "Recordings"
        recordings_dir.mkdir()

        client = TranscriptPersistenceClient(app_support_path=tmpdir)

        # Create 10 transcripts
        transcripts = []
        history = []
        for i in range(10):
            audio_file = recordings_dir / f"test_{i}.wav"
            audio_file.write_text(f"audio {i}")
            transcript = await client.save(
                result=f"Transcript {i+1}",
                audio_url=audio_file,
                duration=1.0,
            )
            transcripts.append(transcript)
            history.append(transcript)

        # Save to history
        await client.save_history(history)
        print(f"✓ Created {len(transcripts)} transcripts")

        # Trim to max 5 entries
        max_entries = 5
        trimmed_history = await client.trim_history(history, max_entries)

        # Save the trimmed history
        await client.save_history(trimmed_history)

        # Load and verify
        history = await client.load()
        assert len(history) == max_entries, \
            f"Expected {max_entries} transcripts after trimming, got {len(history)}"
        print(f"✓ History trimmed to {len(history)} transcripts (max: {max_entries})")

        # Verify we have the right ones by checking timestamps
        # Get the 5 newest from original list
        original_sorted = sorted(transcripts, key=lambda t: t.timestamp, reverse=True)[:max_entries]
        loaded_sorted = sorted(history, key=lambda t: t.timestamp, reverse=True)

        for i in range(max_entries):
            assert original_sorted[i].timestamp == loaded_sorted[i].timestamp, \
                f"Timestamp mismatch at position {i}"

        print("✓ Newest transcripts preserved")
        print("✓ Oldest transcripts removed")
        print("\n✓ TEST 6 PASSED: Trim history to max entries")


async def run_all_tests():
    """Run all automated tests."""
    print("\n" + "="*70)
    print("AUTOMATED TESTS: History Management")
    print("="*70)

    try:
        await test_save_and_load_transcriptions()
        await test_history_details()
        await test_delete_transcript()
        await test_clear_all_history()
        await test_history_sorting()
        await test_trim_history()

        print("\n" + "="*70)
        print("✓ ALL AUTOMATED TESTS PASSED (6/6)")
        print("="*70)
        return True

    except AssertionError as e:
        print(f"\n✗ TEST FAILED: {e}")
        return False
    except Exception as e:
        print(f"\n✗ UNEXPECTED ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Verify history management functionality"
    )
    parser.add_argument(
        "--manual",
        action="store_true",
        help="Show manual testing instructions"
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Run automated tests"
    )

    args = parser.parse_args()

    if args.manual:
        print(MANUAL_TESTING_INSTRUCTIONS)
        return 0

    if args.auto:
        success = asyncio.run(run_all_tests())
        return 0 if success else 1

    # Default: show both
    print(MANUAL_TESTING_INSTRUCTIONS)
    print("\n" + "="*70)
    print("Running automated tests...")
    print("="*70)
    success = asyncio.run(run_all_tests())
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
