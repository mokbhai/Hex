#!/usr/bin/env python3
"""Debug script to understand double-tap behavior."""

import sys
sys.path.insert(0, 'src')

from datetime import datetime, timedelta
from vox.hotkeys.processor import HotKeyProcessor, State, Output
from vox.models.hotkey import HotKey, Modifier, Modifiers, Key
from vox.models.key_event import KeyEvent


def test_simple_double_tap():
    """Test simple double-tap flow with detailed logging."""
    print("\n=== Testing Simple Double-Tap Flow ===\n")

    hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
    processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

    print("Initial state:")
    print(f"  state={processor.state}, last_tap_at={processor.last_tap_at}")

    # First press
    print("\n1. First press (Cmd+A):")
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    output = processor.process(event)
    print(f"  output={output}, state={processor.state}, last_tap_at={processor.last_tap_at}")

    # Release first press
    print("\n2. Release first press (no keys):")
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)
    print(f"  output={output}, state={processor.state}, last_tap_at={processor.last_tap_at}")

    # Second press immediately
    print("\n3. Second press (Cmd+A) immediately:")
    event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
    output = processor.process(event)
    print(f"  output={output}, state={processor.state}, last_tap_at={processor.last_tap_at}")

    # Check if we're in locked state
    if processor.state == State.DOUBLE_TAP_LOCK:
        print("\n✓ Successfully entered DOUBLE_TAP_LOCK mode!")
    else:
        print(f"\n✗ FAILED: Expected DOUBLE_TAP_LOCK, got {processor.state}")


def test_swift_reference_behavior():
    """Test what the Swift implementation would do."""
    print("\n=== Testing Swift Reference Behavior ===\n")
    print("According to HotKeyProcessor.swift:")
    print("- useDoubleTapOnly only applies to key+modifier hotkeys")
    print("- First press: Record timestamp, return nil")
    print("- Second press (within 0.3s): Return startRecording")
    print("- State should be: doubleTapLock")

    print("\nBut in Python implementation:")
    print("- Second press goes through _handle_matching_chord()")
    print("- That method checks state != IDLE")
    print("- But we're still in IDLE state after first release!")
    print("- So second press tries to start PRESS_AND_HOLD, not DOUBLE_TAP_LOCK")


if __name__ == "__main__":
    test_simple_double_tap()
    test_swift_reference_behavior()
