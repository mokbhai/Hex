"""HotKeyProcessor state machine for Hex.

This module implements a state machine that processes keyboard events to detect
hotkey activations. It mirrors the structure from HexCore/Sources/HexCore/Logic/HotKeyProcessor.swift.

The processor implements two complementary recording modes:
1. Press-and-Hold: Start recording when hotkey is pressed, stop when released
2. Double-Tap Lock: Quick double-tap locks recording until hotkey is pressed again
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum, auto
from typing import Optional

from hex.models.hotkey import HotKey, Modifiers, Key
from hex.models.key_event import KeyEvent
from hex.utils.logging import get_logger, LogCategory

# Module logger
hotkey_logger = get_logger(LogCategory.HOTKEY)


# Constants from HexCore/Sources/HexCore/Constants.swift
class HexCoreConstants:
    """Timing thresholds and magic numbers used throughout Hex.

    These values have been carefully tuned based on user testing and OS behavior.
    """

    # Maximum time between two hotkey taps to be considered a double-tap (0.3 seconds)
    doubleTapWindow: float = 0.3

    # Minimum duration for modifier-only hotkeys to avoid conflicts with OS shortcuts (0.3 seconds)
    modifierOnlyMinimumDuration: float = 0.3

    # Time window for canceling press-and-hold on different key press (1.0 second)
    pressAndHoldCancelWindow: float = 1.0

    # Default minimum time a key must be held to register as valid press (0.2 seconds)
    defaultMinimumKeyTime: float = 0.2


class RecordingDecisionEngine:
    """Helper class for recording decision thresholds.

    This class provides constants used by both HotKeyProcessor and the recording
    decision engine to ensure consistent timing thresholds.
    """

    # Minimum duration for modifier-only hotkeys
    modifierOnlyMinimumDuration: float = HexCoreConstants.modifierOnlyMinimumDuration


class State(Enum):
    """Represents the current state of hotkey detection.

    The processor maintains three possible states:
    - IDLE: Waiting for hotkey activation
    - PRESS_AND_HOLD: Recording active, will stop when hotkey released
    - DOUBLE_TAP_LOCK: Recording locked, requires explicit hotkey press to stop
    """

    IDLE = auto()
    PRESS_AND_HOLD = auto()
    DOUBLE_TAP_LOCK = auto()


class Output(Enum):
    """Actions to take in response to keyboard events.

    These outputs control recording behavior and user feedback.
    """

    START_RECORDING = auto()
    STOP_RECORDING = auto()
    CANCEL = auto()
    DISCARD = auto()


@dataclass
class PressAndHoldState:
    """State data for press-and-hold recording mode.

    Attributes:
        start_time: When the hotkey was first pressed (for duration calculation)
    """

    start_time: datetime


@dataclass
class HotKeyProcessor:
    """A state machine that processes keyboard events to detect hotkey activations.

    The processor implements two complementary recording modes:
    1. Press-and-Hold: Start recording when hotkey is pressed, stop when released
    2. Double-Tap Lock: Quick double-tap locks recording until hotkey is pressed again

    Attributes:
        hotkey: The hotkey combination to detect (key + modifiers)
        use_double_tap_only: If true, only double-tap activates recording (press-and-hold disabled)
                             Only applies to key+modifier hotkeys; modifier-only always allows press-and-hold
        minimum_key_time: Minimum duration before very quick taps are considered valid
                         For modifier-only hotkeys, this is overridden to 0.3s minimum
        state: Current state of the processor
        last_tap_at: Timestamp of the most recent hotkey release (for double-tap detection)
        is_dirty: When true, all input is ignored until full keyboard release
                  Prevents accidental re-triggering after cancellation or during complex key combos

    Example:
        >>> from hex.models.hotkey import HotKey, Modifier, Modifiers
        >>> hp = HotKeyProcessor(
        ...     hotkey=HotKey(
        ...         key=None,
        ...         modifiers=Modifiers.from_list([Modifier.OPTION])
        ...     )
        ... )
        >>> print(f"State: {hp.state.name}")
    """

    hotkey: HotKey
    use_double_tap_only: bool = False
    minimum_key_time: float = HexCoreConstants.defaultMinimumKeyTime
    state: State = field(default_factory=lambda: State.IDLE)
    last_tap_at: Optional[datetime] = field(default=None)
    is_dirty: bool = field(default=False)

    # Timing thresholds (class-level constants)
    doubleTapThreshold: float = HexCoreConstants.doubleTapWindow
    pressAndHoldCancelThreshold: float = HexCoreConstants.pressAndHoldCancelWindow

    def __post_init__(self):
        """Initialize press-and-hold state data if needed."""
        # We'll store the actual start time in a separate attribute
        self._press_and_hold_start_time: Optional[datetime] = None

    @property
    def is_matched(self) -> bool:
        """Returns true if recording is currently active (press-and-hold or double-tap locked).

        Returns:
            True if in PRESS_AND_HOLD or DOUBLE_TAP_LOCK state, False otherwise
        """
        return self.state in (State.PRESS_AND_HOLD, State.DOUBLE_TAP_LOCK)

    def process(self, key_event: KeyEvent) -> Optional[Output]:
        """Processes a keyboard event and returns an action to take, if any.

        Event Processing Order:
        1. ESC key → immediate cancellation
        2. Dirty state check → ignore input until full release
        3. Matching chord → handle as hotkey press
        4. Non-matching chord → handle as release or different key

        Args:
            key_event: The keyboard event containing key and modifier state

        Returns:
            An output action (START_RECORDING, STOP_RECORDING, CANCEL, DISCARD)
            or None if no action needed

        Example:
            >>> from datetime import datetime
            >>> from hex.models.hotkey import Modifiers
            >>> event = KeyEvent(key=Key.ESCAPE, modifiers=Modifiers.empty(), timestamp=datetime.now())
            >>> processor = HotKeyProcessor(hotkey=HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION])))
            >>> processor.state = State.PRESS_AND_HOLD
            >>> output = processor.process(event)
            >>> output == Output.CANCEL
            True
        """
        # 1) ESC => immediate cancel
        if key_event.key == Key.ESCAPE and self.state != State.IDLE:
            hotkey_logger.notice(f"ESC pressed while state={self.state.name}")
            self.is_dirty = True
            self._reset_to_idle()
            return Output.CANCEL

        # 2) If dirty, ignore until full release (None, [])
        if self.is_dirty:
            if self._chord_is_fully_released(key_event):
                self.is_dirty = False
            else:
                return None

        # 3) Matching chord => handle as "press"
        if self._chord_matches_hotkey(key_event):
            return self._handle_matching_chord()
        else:
            # Potentially become dirty if chord has extra mods or different key
            if self._chord_is_dirty(key_event):
                self.is_dirty = True
            return self._handle_nonmatching_chord(key_event)

    def process_mouse_click(self) -> Optional[Output]:
        """Processes a mouse click event to prevent accidental recordings.

        For modifier-only hotkeys, mouse clicks can interfere with recording:
        - Option+click = duplicate items in Finder
        - Cmd+click = open in new tab
        - etc.

        This method discards recordings that haven't passed the minimum threshold yet.

        Returns:
            DISCARD if recording canceled, None if click ignored

        Behavior:
            - Modifier-only hotkeys: Discard if within threshold, ignore after threshold
            - Key+modifier hotkeys: Always ignore (no conflict with mouse clicks)
            - Double-tap lock: Always ignore (intentional recording, only ESC cancels)
        """
        # Only cancel if:
        # 1. The hotkey is modifier-only (no key component)
        # 2. We're currently in an active recording state (pressAndHold or doubleTapLock)
        if self.hotkey.key is not None:
            return None

        if self.state == State.IDLE:
            return None

        if self.state == State.PRESS_AND_HOLD:
            # Mouse click during modifier-only recording
            if self._press_and_hold_start_time is None:
                return None

            elapsed = (datetime.now() - self._press_and_hold_start_time).total_seconds()
            # For modifier-only hotkeys, use the same threshold as RecordingDecisionEngine
            # (max of minimumKeyTime and 0.3s) to be consistent
            effective_minimum = max(
                self.minimum_key_time, RecordingDecisionEngine.modifierOnlyMinimumDuration
            )

            # Only discard if within threshold - after threshold, ignore clicks (only ESC cancels)
            if elapsed < effective_minimum:
                self.is_dirty = True
                self._reset_to_idle()
                return Output.DISCARD
            else:
                # After threshold, ignore mouse clicks - let recording continue
                return None

        if self.state == State.DOUBLE_TAP_LOCK:
            # Mouse click during double-tap lock => ignore (only ESC cancels locked recordings)
            return None

        return None

    def _handle_matching_chord(self) -> Optional[Output]:
        """Handles keyboard events that match the configured hotkey.

        State Transitions:
        - IDLE → PRESS_AND_HOLD: Start new recording (unless useDoubleTapOnly mode)
        - PRESS_AND_HOLD → no change: Already recording, ignore
        - DOUBLE_TAP_LOCK → IDLE: User pressed hotkey to stop locked recording

        Double-Tap Only Mode:
            For key+modifier hotkeys with useDoubleTapOnly enabled:
            - First press: Record timestamp but don't start recording
            - Wait for quick release and second press to actually start

        Returns:
            START_RECORDING when entering press-and-hold, STOP_RECORDING when exiting lock
        """
        if self.state == State.IDLE:
            # If doubleTapOnly mode is enabled and the hotkey has a key component,
            # we want to delay starting recording until we see the double-tap
            if self.use_double_tap_only and self.hotkey.key is not None:
                # Record the timestamp but don't start recording
                self.last_tap_at = datetime.now()
                return None
            else:
                # Normal press => PRESS_AND_HOLD => START_RECORDING
                self.state = State.PRESS_AND_HOLD
                self._press_and_hold_start_time = datetime.now()
                return Output.START_RECORDING

        if self.state == State.PRESS_AND_HOLD:
            # Already matched, no new output
            return None

        if self.state == State.DOUBLE_TAP_LOCK:
            # Pressing hotkey again while locked => stop
            self._reset_to_idle()
            return Output.STOP_RECORDING

        return None

    def _handle_nonmatching_chord(self, key_event: KeyEvent) -> Optional[Output]:
        """Handles keyboard events that don't match the configured hotkey.

        This method detects:
        1. Hotkey release: User lifted the hotkey (transition to idle or double-tap lock)
        2. Different key press: User pressed a different key while holding hotkey (potential cancel)
        3. Extra modifiers: User added modifiers beyond hotkey requirements (potential cancel)

        Cancel Behavior:
            Different keys/modifiers are handled based on timing and hotkey type:

            Modifier-only hotkeys:
            - Within threshold (0.3s): Discard silently (accidental trigger, e.g., Option+click)
            - After threshold: Ignore completely, keep recording (only ESC cancels)

            Key+modifier hotkeys:
            - Within 1s: Stop recording (likely accidental)
            - After 1s: Ignore, keep recording (intentional simultaneous input)

        Args:
            key_event: The non-matching keyboard event

        Returns:
            Recording control output or None
        """
        if self.state == State.IDLE:
            # Handle double-tap detection for key+modifier combinations
            if (
                self.use_double_tap_only
                and self.hotkey.key is not None
                and self._chord_is_fully_released(key_event)
                and self.last_tap_at is not None
            ):
                # If we've seen a tap recently, and now we see a full release, and we're in idle state
                # Check if the time between taps is within the threshold
                if (datetime.now() - self.last_tap_at).total_seconds() < self.doubleTapThreshold:
                    # This is the second tap - activate recording in double-tap lock mode
                    self.state = State.DOUBLE_TAP_LOCK
                    return Output.START_RECORDING

                # Reset the tap timer as we've fully released
                self.last_tap_at = None
            return None

        if self.state == State.PRESS_AND_HOLD:
            # If user truly "released" the chord => either normal stop or doubleTapLock
            if self._is_release_for_active_hotkey(key_event):
                # Check if this release is close to the prior release => double-tap lock
                if (
                    self.last_tap_at is not None
                    and (datetime.now() - self.last_tap_at).total_seconds()
                    < self.doubleTapThreshold
                ):
                    # => Switch to DOUBLE_TAP_LOCK, remain matched, no new output
                    self.state = State.DOUBLE_TAP_LOCK
                    return None
                else:
                    # Normal stop => IDLE => record the release time
                    self.state = State.IDLE
                    self.last_tap_at = datetime.now()
                    return Output.STOP_RECORDING
            else:
                # User pressed a different key/modifier while holding hotkey
                if self._press_and_hold_start_time is None:
                    return None

                elapsed = (datetime.now() - self._press_and_hold_start_time).total_seconds()

                # Modifier-only hotkeys: Only discard within threshold, ignore after
                if self.hotkey.key is None:
                    effective_minimum = max(
                        self.minimum_key_time, RecordingDecisionEngine.modifierOnlyMinimumDuration
                    )

                    if elapsed < effective_minimum:
                        # Within threshold => discard silently (accidental trigger)
                        self.is_dirty = True
                        self._reset_to_idle()
                        return Output.DISCARD
                    else:
                        # After threshold => ignore extra modifiers/keys, keep recording (only ESC cancels)
                        return None
                else:
                    # Printable-key hotkeys: Use old behavior with 1s threshold
                    if elapsed < self.pressAndHoldCancelThreshold:
                        # Within 1s threshold => treat as accidental
                        self.is_dirty = True
                        self._reset_to_idle()
                        # If very quick (< minimumKeyTime), discard silently. Otherwise stop with sound.
                        return (
                            Output.DISCARD if elapsed < self.minimum_key_time else Output.STOP_RECORDING
                        )
                    else:
                        # After 1s => remain matched
                        return None

        if self.state == State.DOUBLE_TAP_LOCK:
            # For key+modifier combinations in doubleTapLock mode, require full key release to stop
            if (
                self.use_double_tap_only
                and self.hotkey.key is not None
                and self._chord_is_fully_released(key_event)
            ):
                self._reset_to_idle()
                return Output.STOP_RECORDING
            # Otherwise, if locked, ignore everything except chord == hotkey => stop
            return None

        return None

    def _chord_matches_hotkey(self, key_event: KeyEvent) -> bool:
        """Checks if the given keyboard event exactly matches the configured hotkey.

        Matching Rules:
        - Key+modifier hotkey: Both key and modifiers must match exactly
        - Modifier-only hotkey: Modifiers match exactly and no key is pressed

        Args:
            key_event: The keyboard event to check

        Returns:
            True if event matches hotkey configuration
        """
        if self.hotkey.key is not None:
            return key_event.key == self.hotkey.key and key_event.modifiers.matches_exactly(
                self.hotkey.modifiers
            )
        else:
            return key_event.key is None and key_event.modifiers.matches_exactly(self.hotkey.modifiers)

    def _chord_is_dirty(self, key_event: KeyEvent) -> bool:
        """Checks if keyboard event contains extra keys/modifiers that should trigger dirty state.

        "Dirty" means the user is doing something unrelated to our hotkey, so we should
        ignore all input until they fully release the keyboard.

        Dirty Conditions:
        - Modifier-only hotkey: Any key press OR extra modifiers beyond requirements
        - Key+modifier hotkey: Different key OR modifiers not subset of requirements

        Args:
            key_event: The keyboard event to check

        Returns:
            True if event should trigger dirty state
        """
        if self.hotkey.key is None:
            # Any key press while watching pure-modifier hotkey is "dirty"
            # Also dirty if there are extra modifiers beyond what the hotkey requires
            return key_event.key is not None or not key_event.modifiers.is_subset_of(
                self.hotkey.modifiers
            )

        is_subset = key_event.modifiers.is_subset_of(self.hotkey.modifiers)
        is_wrong_key = key_event.key is not None and key_event.key != self.hotkey.key
        return not is_subset or is_wrong_key

    def _chord_is_fully_released(self, key_event: KeyEvent) -> bool:
        """Checks if all keys and modifiers have been released.

        Used to clear dirty state - once user fully releases keyboard,
        we can start accepting hotkey input again.

        Args:
            key_event: The keyboard event to check

        Returns:
            True if no keys or modifiers are pressed
        """
        return key_event.key is None and key_event.modifiers.is_empty

    def _is_release_for_active_hotkey(self, key_event: KeyEvent) -> bool:
        """Detects if user has released the active hotkey.

        Release detection differs based on hotkey type:

        Key+Modifier Hotkey (e.g., Cmd+A):
        "Release" = key is lifted, modifiers may still be held
        - Allows partial modifier release before key release
        - User can lift Cmd slightly early without affecting detection

        Modifier-Only Hotkey (e.g., Option):
        "Release" = required modifiers no longer pressed
        - Detects when user lifts the specific modifier(s)
        - Key must be None (no key component in hotkey)

        Args:
            key_event: The keyboard event to check

        Returns:
            True if hotkey has been released
        """
        if self.hotkey.key is not None:
            required_modifiers = self.hotkey.modifiers
            key_released = key_event.key is None
            modifiers_are_subset = key_event.modifiers.is_subset_of(required_modifiers)

            if key_released:
                # Treat as release even if some modifiers were lifted first,
                # as long as no new modifiers are introduced.
                return modifiers_are_subset

            return False
        else:
            # For modifier-only hotkeys, we check:
            # 1. Key is None
            # 2. Required hotkey modifiers are no longer pressed
            # This detects when user has released the specific modifiers in the hotkey
            return key_event.key is None and not self.hotkey.modifiers.is_subset_of(key_event.modifiers)

    def _reset_to_idle(self) -> None:
        """Resets processor to idle state, clearing active recording state.

        Preserves is_dirty flag if caller has set it, allowing dirty state
        to persist across state transitions for proper input blocking.

        Clears:
        - state → IDLE
        - last_tap_at → None (double-tap timing reset)
        - _press_and_hold_start_time → None
        """
        self.state = State.IDLE
        self.last_tap_at = None
        self._press_and_hold_start_time = None
