"""Tests for HotKeyProcessor state machine."""

import sys
sys.path.insert(0, 'src')

try:
    import pytest
except ImportError:
    pytest = None

from datetime import datetime, timedelta

from hex.hotkeys.processor import (
    HotKeyProcessor,
    State,
    Output,
    HexCoreConstants,
    RecordingDecisionEngine,
)
from hex.models.hotkey import HotKey, Modifier, Modifiers, Key
from hex.models.key_event import KeyEvent


class TestHotKeyProcessor:
    """Test HotKeyProcessor state machine behavior."""

    def test_initial_state(self):
        """Test that processor starts in IDLE state."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)
        assert processor.state == State.IDLE
        assert not processor.is_matched

    def test_simple_press_and_hold(self):
        """Test basic press-and-hold recording flow."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Press hotkey
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.START_RECORDING
        assert processor.state == State.PRESS_AND_HOLD
        assert processor.is_matched

        # Release hotkey
        event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.STOP_RECORDING
        assert processor.state == State.IDLE
        assert not processor.is_matched

    def test_escape_cancels_recording(self):
        """Test that ESC key cancels active recording."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Start recording
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)
        assert processor.state == State.PRESS_AND_HOLD

        # Press ESC
        event = KeyEvent(key=Key.ESCAPE, modifiers=Modifiers.empty(), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.CANCEL
        assert processor.state == State.IDLE
        assert processor.is_dirty  # Should be dirty after cancellation

    def test_escape_does_nothing_when_idle(self):
        """Test that ESC key does nothing when not recording."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Press ESC while idle
        event = KeyEvent(key=Key.ESCAPE, modifiers=Modifiers.empty(), timestamp=datetime.now())
        output = processor.process(event)

        assert output is None
        assert processor.state == State.IDLE
        assert not processor.is_dirty

    def test_double_tap_lock(self):
        """Test double-tap lock mode."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # First press and release
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)  # START_RECORDING
        event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
        processor.process(event)  # STOP_RECORDING

        # Second press and release (quickly)
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        output = processor.process(event)  # START_RECORDING

        # Now in PRESS_AND_HOLD again
        assert output == Output.START_RECORDING
        assert processor.state == State.PRESS_AND_HOLD

        # Release - should go to DOUBLE_TAP_LOCK
        event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
        output = processor.process(event)

        assert output is None  # No output on transition to lock
        assert processor.state == State.DOUBLE_TAP_LOCK
        assert processor.is_matched

        # Third press stops recording
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.STOP_RECORDING
        assert processor.state == State.IDLE

    def test_key_plus_modifier_hotkey(self):
        """Test hotkey with both key and modifier (e.g., Cmd+A)."""
        hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Press Cmd+A
        event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.START_RECORDING
        assert processor.state == State.PRESS_AND_HOLD

        # Release A key (but still holding Cmd)
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
        output = processor.process(event)

        assert output == Output.STOP_RECORDING
        assert processor.state == State.IDLE

    def test_dirty_state_ignored_until_full_release(self):
        """Test that dirty state ignores input until full release."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Start recording
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)

        # Press a different key (becomes dirty)
        event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)
        assert processor.is_dirty

        # Try to press hotkey again while dirty - should be ignored
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        output = processor.process(event)
        assert output is None  # Ignored because dirty

        # Fully release
        event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
        processor.process(event)
        assert not processor.is_dirty

        # Now hotkey should work again
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        output = processor.process(event)
        assert output == Output.START_RECORDING

    def test_timing_constants(self):
        """Test that timing constants are correctly defined."""
        assert HexCoreConstants.doubleTapWindow == 0.3
        assert HexCoreConstants.modifierOnlyMinimumDuration == 0.3
        assert HexCoreConstants.pressAndHoldCancelWindow == 1.0
        assert HexCoreConstants.defaultMinimumKeyTime == 0.2

        assert RecordingDecisionEngine.modifierOnlyMinimumDuration == 0.3

    def test_use_double_tap_only_mode(self):
        """Test useDoubleTapOnly mode for key+modifier hotkeys."""
        hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
        processor = HotKeyProcessor(hotkey=hotkey, use_double_tap_only=True)

        # First press - should not start recording
        event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
        output = processor.process(event)
        assert output is None  # No output, just timestamp recorded
        assert processor.state == State.IDLE
        assert processor.last_tap_at is not None

        # Release
        event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
        processor.process(event)

        # Second press quickly - should start recording in lock mode
        event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
        output = processor.process(event)
        assert output == Output.START_RECORDING
        assert processor.state == State.DOUBLE_TAP_LOCK

    def test_mouse_click_discard_for_modifier_only(self):
        """Test that mouse click discards recording if within threshold."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Start recording
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)
        assert processor.state == State.PRESS_AND_HOLD

        # Simulate mouse click immediately (within threshold)
        output = processor.process_mouse_click()
        assert output == Output.DISCARD
        assert processor.state == State.IDLE
        assert processor.is_dirty

    def test_mouse_click_ignored_after_threshold(self):
        """Test that mouse click is ignored after threshold."""
        hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Start recording
        event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
        processor.process(event)
        assert processor.state == State.PRESS_AND_HOLD

        # Simulate time passing beyond threshold
        processor._press_and_hold_start_time = datetime.now() - timedelta(seconds=1.0)

        # Mouse click should be ignored
        output = processor.process_mouse_click()
        assert output is None
        assert processor.state == State.PRESS_AND_HOLD  # Still recording

    def test_mouse_click_ignored_for_key_plus_modifier(self):
        """Test that mouse click is always ignored for key+modifier hotkeys."""
        hotkey = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
        processor = HotKeyProcessor(hotkey=hotkey)

        # Start recording
        event = KeyEvent(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]), timestamp=datetime.now())
        processor.process(event)

        # Mouse click should be ignored
        output = processor.process_mouse_click()
        assert output is None
        assert processor.state == State.PRESS_AND_HOLD


if __name__ == "__main__":
    import sys
    sys.path.insert(0, 'src')

    # Run a basic test
    from hex.hotkeys.processor import HotKeyProcessor, State, Output
    from hex.models.hotkey import HotKey, Modifier, Modifiers, Key
    from hex.models.key_event import KeyEvent
    from datetime import datetime

    print("test_initial_state...", end="")
    hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
    processor = HotKeyProcessor(hotkey=hotkey)
    assert processor.state == State.IDLE
    assert not processor.is_matched
    print(" PASS")

    print("test_simple_press_and_hold...", end="")
    processor = HotKeyProcessor(hotkey=hotkey)
    event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
    output = processor.process(event)
    assert output == Output.START_RECORDING
    assert processor.state == State.PRESS_AND_HOLD
    assert processor.is_matched
    event = KeyEvent(key=None, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)
    assert output == Output.STOP_RECORDING
    assert processor.state == State.IDLE
    assert not processor.is_matched
    print(" PASS")

    print("test_escape_cancels_recording...", end="")
    processor = HotKeyProcessor(hotkey=hotkey)
    event = KeyEvent(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]), timestamp=datetime.now())
    processor.process(event)
    event = KeyEvent(key=Key.ESCAPE, modifiers=Modifiers.empty(), timestamp=datetime.now())
    output = processor.process(event)
    assert output == Output.CANCEL
    assert processor.state == State.IDLE
    assert processor.is_dirty
    print(" PASS")

    print("\nAll basic tests passed!")
    print("\nTo run full test suite, install pytest:")
    print("  pip install pytest")
    print("  pytest tests/test_hotkey_processor.py -v")
