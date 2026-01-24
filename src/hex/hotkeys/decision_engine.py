"""RecordingDecisionEngine for determining whether to keep or discard recordings.

This module provides logic to decide whether a recording should be kept based on
its duration and hotkey type. It mirrors the structure from
HexCore/Sources/HexCore/Logic/RecordingDecision.swift.

The engine enforces minimum recording durations to prevent accidental activations
and conflicts with system shortcuts.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum, auto
from typing import Optional

from hex.models.hotkey import HotKey


# Constants from HexCore/Sources/HexCore/Constants.swift
class HexCoreConstants:
    """Timing thresholds and magic numbers used throughout Hex.

    These values have been carefully tuned based on user testing and OS behavior.
    """

    # Minimum duration for modifier-only hotkeys to avoid conflicts with OS shortcuts (0.3 seconds)
    modifierOnlyMinimumDuration: float = 0.3


class Decision(Enum):
    """The decision outcome for a recording.

    Attributes:
        DISCARD_SHORT_RECORDING: Recording was too short or accidental - discard silently
        PROCEED_TO_TRANSCRIPTION: Recording meets minimum requirements - proceed with transcription
    """

    DISCARD_SHORT_RECORDING = auto()
    PROCEED_TO_TRANSCRIPTION = auto()


@dataclass(frozen=True)
class Context:
    """Context information needed to make a recording decision.

    Attributes:
        hotkey: The hotkey configuration that triggered this recording
        minimum_key_time: User's configured minimum key time preference
        recording_start_time: When recording started (None if no recording)
        current_time: Current timestamp

    Example:
        >>> from datetime import datetime
        >>> from hex.models.hotkey import HotKey, Modifier, Modifiers
        >>> context = Context(
        ...     hotkey=HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION])),
        ...     minimum_key_time=0.2,
        ...     recording_start_time=datetime.now(),
        ...     current_time=datetime.now()
        ... )
    """

    hotkey: HotKey
    minimum_key_time: float
    recording_start_time: Optional[datetime]
    current_time: datetime


class RecordingDecisionEngine:
    """Determines whether a recording should be kept or discarded based on duration and hotkey type.

    This engine enforces minimum recording durations to prevent accidental activations
    and conflicts with system shortcuts.

    Decision Logic:
        Modifier-only hotkeys (e.g., Option):
            Must meet max(minimumKeyTime, modifierOnlyMinimumDuration)
            Always enforces 0.3s minimum to prevent OS shortcut conflicts

        Key+modifier hotkeys (e.g., Cmd+A):
            Always proceeds to transcription (duration checked elsewhere)
            User's minimumKeyTime preference applies

    Example:
        >>> from datetime import datetime, timedelta
        >>> from hex.models.hotkey import HotKey, Modifier, Modifiers
        >>> engine = RecordingDecisionEngine()
        >>> start = datetime.now()
        >>> current = start + timedelta(seconds=0.5)
        >>> context = Context(
        ...     hotkey=HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION])),
        ...     minimum_key_time=0.2,
        ...     recording_start_time=start,
        ...     current_time=current
        ... )
        >>> decision = engine.decide(context)
        >>> decision == Decision.PROCEED_TO_TRANSCRIPTION
        True
    """

    # Minimum duration for modifier-only hotkeys to avoid OS shortcut conflicts.
    # This is applied regardless of user's minimumKeyTime setting.
    # See HexCoreConstants.modifierOnlyMinimumDuration for rationale.
    modifierOnlyMinimumDuration: float = HexCoreConstants.modifierOnlyMinimumDuration

    def decide(self, context: Context) -> Decision:
        """Determines whether to keep or discard a recording based on duration and hotkey type.

        For modifier-only hotkeys, this uses the higher of minimumKeyTime or
        modifierOnlyMinimumDuration (0.3s) to prevent conflicts with system shortcuts.

        For key+modifier hotkeys, this always proceeds to transcription since the
        duration check is handled elsewhere.

        Args:
            context: Recording context with timing and configuration

        Returns:
            Decision to discard or proceed with transcription

        Example:
            >>> from datetime import datetime, timedelta
            >>> from hex.models.hotkey import HotKey, Key, Modifier, Modifiers
            >>> engine = RecordingDecisionEngine()
            >>> # Test with modifier-only hotkey and short duration
            >>> start = datetime.now()
            >>> current = start + timedelta(seconds=0.1)
            >>> context = Context(
            ...     hotkey=HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION])),
            ...     minimum_key_time=0.2,
            ...     recording_start_time=start,
            ...     current_time=current
            ... )
            >>> decision = engine.decide(context)
            >>> decision == Decision.DISCARD_SHORT_RECORDING
            True
        """
        # Calculate elapsed time since recording started
        elapsed = 0.0
        if context.recording_start_time is not None:
            elapsed = (context.current_time - context.recording_start_time).total_seconds()

        # Check if hotkey includes a printable key (not modifier-only)
        includes_printable_key = context.hotkey.key is not None

        # For modifier-only hotkeys, use the higher of minimumKeyTime or modifierOnlyMinimumDuration
        # to prevent conflicts with system shortcuts
        effective_minimum = (
            context.minimum_key_time
            if includes_printable_key
            else max(context.minimum_key_time, self.modifierOnlyMinimumDuration)
        )

        duration_is_long_enough = elapsed >= effective_minimum

        # Key+modifier hotkeys always proceed, modifier-only must meet duration threshold
        return (
            Decision.PROCEED_TO_TRANSCRIPTION
            if (duration_is_long_enough or includes_printable_key)
            else Decision.DISCARD_SHORT_RECORDING
        )
