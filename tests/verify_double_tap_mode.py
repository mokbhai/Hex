#!/usr/bin/env python3
"""Verification script for double-tap recording mode.

This script tests the double-tap recording feature to ensure:
1. Double-tap detection works correctly
2. Recording locks on double-tap
3. Single press stops locked recording
4. Timing thresholds are respected

Usage:
    python tests/verify_double_tap_mode.py

This will run automated tests and display manual testing instructions.
"""

import sys
sys.path.insert(0, 'src')

from datetime import datetime, timedelta
from vox.hotkeys.processor import HotKeyProcessor, State, Output
from vox.models.hotkey import HotKey, Modifier, Modifiers, Key
from vox.models.key_event import KeyEvent
from vox.models.settings import VoxSettings


class TestResults:
    """Track test results."""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.tests = []

    def add_pass(self, test_name):
        self.passed += 1
        self.tests.append((test_name, "PASS"))
        print(f"  ✓ {test_name}")

    def add_fail(self, test_name, reason):
        self.failed += 1
        self.tests.append((test_name, f"FAIL: {reason}"))
        print(f"  ✗ {test_name}")
        print(f"    Reason: {reason}")

    def print_summary(self):
        total = self.passed + self.failed
        print(f"\n{'='*60}")
        print(f"Test Results: {self.passed}/{total} passed")
        if self.failed > 0:
            print(f"FAILED: {self.failed} tests failed")
            return False
        else:
            print("SUCCESS: All tests passed!")
            return True


def test_double_tap_with_key_plus_modifier(results):
    """Test double-tap mode with key+modifier hotkey (e.g., Cmd+A)."""
    print("\n1. Testing double-tap mode with key+modifier hotkey (Cmd+A)")

    # Create processor with use_double_tap_only enabled
    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # Test 1.1: First press should not start recording, just record timestamp
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    output = processor.process(event)

    if output is None and processor.state == State.IDLE and processor.last_tap_at is not None:
        results.add_pass("First press records timestamp but doesn't start recording")
    else:
        results.add_fail("First press records timestamp but doesn't start recording",
                        f"output={output}, state={processor.state}, last_tap_at={processor.last_tap_at}")

    # Test 1.2: Release first press - this is where double-tap is detected!
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.START_RECORDING and processor.state == State.DOUBLE_TAP_LOCK:
        results.add_pass("Release of first press (within threshold) triggers DOUBLE_TAP_LOCK")
    else:
        results.add_fail("Release of first press (within threshold) triggers DOUBLE_TAP_LOCK",
                        f"output={output}, state={processor.state}")

    # Test 1.3: While locked, pressing hotkey should stop recording
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.STOP_RECORDING and processor.state == State.IDLE:
        results.add_pass("Pressing hotkey while locked stops recording")
    else:
        results.add_fail("Pressing hotkey while locked stops recording",
                        f"output={output}, state={processor.state}")


def test_double_tap_with_slow_second_press(results):
    """Test that slow release (beyond 0.3s) doesn't trigger double-tap."""
    print("\n2. Testing slow double-tap (beyond 0.3s threshold)")

    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # First press
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    processor.process(event)

    # Manually set last_tap_at to be old (simulate waiting beyond threshold)
    processor.last_tap_at = datetime.now() - timedelta(seconds=0.4)

    # Release (beyond threshold)
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)

    # Should not start recording (too slow - double-tap window expired)
    if output is None and processor.state == State.IDLE:
        results.add_pass("Slow release (beyond threshold) doesn't trigger double-tap lock")
    else:
        results.add_fail("Slow release (beyond threshold) doesn't trigger double-tap lock",
                        f"output={output}, state={processor.state}")


def test_double_tap_with_modifier_only_hotkey(results):
    """Test that modifier-only hotkeys ignore use_double_tap_only setting."""
    print("\n3. Testing modifier-only hotkey (Option) with use_double_tap_only=True")

    # For modifier-only hotkeys, use_double_tap_only should be ignored
    # They always support both press-and-hold AND double-tap lock
    hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # Test 3.1: Single press should start recording (press-and-hold mode)
    event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.START_RECORDING and processor.state == State.PRESS_AND_HOLD:
        results.add_pass("Modifier-only hotkey starts recording on first press (ignores use_double_tap_only)")
    else:
        results.add_fail("Modifier-only hotkey starts recording on first press (ignores use_double_tap_only)",
                        f"output={output}, state={processor.state}")

    # Test 3.2: Release and quick second press should transition to double-tap lock
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    processor.process(event)  # STOP_RECORDING

    # Quick second press
    event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.START_RECORDING and processor.state == State.PRESS_AND_HOLD:
        # Second press starts PRESS_AND_HOLD
        pass
    else:
        results.add_fail("Second press of modifier-only hotkey",
                        f"output={output}, state={processor.state}")
        return

    # Release - should go to DOUBLE_TAP_LOCK
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)

    if output is None and processor.state == State.DOUBLE_TAP_LOCK:
        results.add_pass("Quick release of second press transitions to DOUBLE_TAP_LOCK")
    else:
        results.add_fail("Quick release of second press transitions to DOUBLE_TAP_LOCK",
                        f"output={output}, state={processor.state}")


def test_ignores_extra_keys_while_locked(results):
    """Test that extra key presses are ignored while in DOUBLE_TAP_LOCK state."""
    print("\n4. Testing that extra keys are ignored while recording is locked")

    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # Get to locked state via double-tap
    # First press
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    processor.process(event)
    # Release - this triggers double-tap lock
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    processor.process(event)  # Now in DOUBLE_TAP_LOCK

    # Press extra keys while locked
    event = KeyEvent(key=Key.B, modifiers=Modifiers.from_list([Modifier.COMMAND, Modifier.SHIFT]), timestamp=datetime.now())
    output = processor.process(event)

    if output is None and processor.state == State.DOUBLE_TAP_LOCK:
        results.add_pass("Extra keys are ignored while recording is locked")
    else:
        results.add_fail("Extra keys are ignored while recording is locked",
                        f"output={output}, state={processor.state}")


def test_esc_cancels_locked_recording(results):
    """Test that ESC key cancels even locked recordings."""
    print("\n5. Testing ESC cancellation of locked recording")

    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # Get to locked state
    # First press
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    processor.process(event)
    # Release - this triggers double-tap lock
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    processor.process(event)  # Now in DOUBLE_TAP_LOCK

    # Press ESC
    event = KeyEvent(key=Key.ESCAPE, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.CANCEL and processor.state == State.IDLE:
        results.add_pass("ESC key cancels locked recording")
    else:
        results.add_fail("ESC key cancels locked recording",
                        f"output={output}, state={processor.state}")


def test_full_release_stops_locked_recording(results):
    """Test that full key release stops locked recording (for use_double_tap_only mode)."""
    print("\n6. Testing full release stops locked recording")

    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    # Get to locked state
    # First press
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    processor.process(event)
    # Release - this triggers double-tap lock
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    processor.process(event)  # Now in DOUBLE_TAP_LOCK

    # Fully release
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)

    if output == Output.STOP_RECORDING and processor.state == State.IDLE:
        results.add_pass("Full release stops locked recording")
    else:
        results.add_fail("Full release stops locked recording",
                        f"output={output}, state={processor.state}")


def print_manual_testing_instructions():
    """Print detailed manual testing instructions."""
    print("\n" + "="*60)
    print("MANUAL TESTING INSTRUCTIONS")
    print("="*60)

    print("""
The automated tests verify the state machine logic, but manual testing
is required to verify the full end-to-end user experience.

### Prerequisites

1. Install and start Ollama server:
   ```bash
   ollama serve
   ollama pull whisper
   ```

2. Install Hex Python application:
   ```bash
   pip install -e .
   ```

3. Grant macOS Accessibility permissions:
   - System Settings → Privacy & Security → Accessibility
   - Add Terminal or your Python interpreter

### Manual Test Procedure

#### Test 1: Enable Double-Tap Mode

1. Launch the application:
   ```bash
   python -m vox
   ```

2. Right-click system tray icon → Settings...

3. Find "Use double-tap only" checkbox

4. Enable it and click OK

5. Verify setting persists by reopening Settings

#### Test 2: Verify Double-Tap Recording with Key+Modifier Hotkey

1. Change hotkey to Cmd+A (or any key+modifier combination):
   - Settings → Hotkey section
   - Click "Record Hotkey"
   - Press Cmd+A
   - Click "Stop Recording"
   - Click OK to save

2. Open a text editor (TextEdit, VSCode, etc.)

3. Double-tap Cmd+A quickly (press twice within 0.5 seconds):
   - Press Cmd+A
   - Release
   - Press Cmd+A again within 0.5 seconds
   - Release

4. Verify:
   - ✓ Recording indicator appears
   - ✓ Sound effect plays
   - ✓ Recording stays active WITHOUT holding the key (locked)
   - ✓ Speak for 3 seconds: "This is a double-tap test"
   - ✓ Press Cmd+A once to stop
   - ✓ Wait 2-5 seconds
   - ✓ Text "this is a double-tap test" appears in text editor

#### Test 3: Verify Slow Double-Tap Doesn't Trigger Lock Mode

1. Press Cmd+A
2. Release
3. Wait 1 second
4. Press Cmd+A again
5. Verify:
   - ✗ Recording does NOT lock
   - ✗ Or normal press-and-hold behavior applies

#### Test 4: Verify ESC Cancels Locked Recording

1. Double-tap Cmd+A to lock recording
2. While recording is locked, press ESC
3. Verify:
   - ✓ Recording stops immediately
   - ✓ Cancel sound effect plays
   - ✓ No transcription occurs
   - ✓ No text is pasted

#### Test 5: Verify Modifier-Only Hotkey Ignores use_double_tap_only

1. Change hotkey back to Option (or Cmd, Shift, Ctrl):
   - Settings → Hotkey
   - Click "Record Hotkey"
   - Press Option (no key component)
   - Click "Stop Recording"
   - Click OK

2. Verify "Use double-tap only" is still enabled in Settings

3. Test press-and-hold:
   - Press and hold Option
   - Speak for 2 seconds
   - Release Option
   - ✓ Recording works normally (press-and-hold)

4. Test double-tap lock:
   - Press and release Option quickly
   - Press and release Option again quickly (within 0.5s)
   - ✓ Recording locks (no need to hold)
   - Press Option once to stop
   - ✓ Recording stops

### Expected Behavior Summary

**Key+Modifier Hotkey (e.g., Cmd+A) with use_double_tap_only=True:**
- Single press: No effect (records timestamp)
- Double-tap (within 0.3s): Recording locks
- While locked: Press hotkey once to stop, OR fully release keys
- ESC: Always cancels

**Modifier-Only Hotkey (e.g., Option) with use_double_tap_only=True:**
- Setting is ignored - both modes work:
  - Press-and-hold: Normal recording
  - Double-tap: Recording locks
- ESC: Always cancels

### Success Criteria

All automated tests pass AND all manual verification steps complete
with expected results (marked with ✓ above).
""")


def main():
    """Run all verification tests."""
    print("="*60)
    print("DOUBLE-TAP RECORDING MODE VERIFICATION")
    print("="*60)
    print("\nThis script tests the double-tap recording feature of Hex.")

    results = TestResults()

    # Run automated tests
    try:
        test_double_tap_with_key_plus_modifier(results)
        test_double_tap_with_slow_second_press(results)
        test_double_tap_with_modifier_only_hotkey(results)
        test_ignores_extra_keys_while_locked(results)
        test_esc_cancels_locked_recording(results)
        test_full_release_stops_locked_recording(results)
    except Exception as e:
        print(f"\n✗ Error during testing: {e}")
        import traceback
        traceback.print_exc()
        return False

    # Print test summary
    success = results.print_summary()

    # Print manual testing instructions
    print_manual_testing_instructions()

    # Print final status
    print("\n" + "="*60)
    if success:
        print("✓ AUTOMATED TESTS PASSED")
        print("\nNext step: Follow manual testing instructions above")
        print("to verify end-to-end functionality.")
    else:
        print("✗ SOME TESTS FAILED")
        print("\nPlease review the failures above and fix issues before")
        print("proceeding to manual testing.")
    print("="*60)

    return success


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
