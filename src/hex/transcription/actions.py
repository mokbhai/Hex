"""Action definitions for the transcription feature.

This module defines all actions that can be dispatched to the transcription
state machine. It mirrors the Action enum from the Swift implementation in
Hex/Features/Transcription/TranscriptionFeature.swift.

Actions represent events that can occur in the system, such as user input
(hotkey presses), system events (audio level updates), and async operation
results (transcription completion).
"""

from enum import Enum


class Action(Enum):
    """Actions for the transcription feature state machine.

    Each action represents an event that can be processed by the transcription
    reducer. Actions are dispatched by various parts of the system (hotkey
    monitor, audio recorder, transcription client, etc.) and are processed
    sequentially to update state and trigger side effects.

    The actions are organized into logical groups:
    - Lifecycle: Actions for initialization and setup
    - Metering: Actions for audio level updates
    - Hotkey: Actions for hotkey press/release events
    - Recording: Actions for recording control
    - Cancel/Discard: Actions for canceling or discarding recordings
    - Transcription: Actions for transcription results and errors
    - Model: Actions for model availability

    Attributes:
        TASK: Initialize the transcription feature, start metering and hotkey monitoring
        AUDIO_LEVEL_UPDATED: Audio meter level changed (associated value: Meter)
        HOTKEY_PRESSED: User pressed the hotkey (may start recording)
        HOTKEY_RELEASED: User released the hotkey (may stop recording)
        START_RECORDING: Begin audio recording immediately
        STOP_RECORDING: Stop audio recording and start transcription
        CANCEL: Explicitly cancel the current recording (with sound)
        DISCARD: Silently discard the current recording (too short/accidental)
        TRANSCRIPTION_RESULT: Transcription completed successfully (associated values: result: str, audio_url: URL)
        TRANSCRIPTION_ERROR: Transcription failed (associated values: error: Exception, audio_url: URL | None)
        MODEL_MISSING: The transcription model is not available

    Examples:
        >>> Action.HOTKEY_PRESSED
        <Action.HOTKEY_PRESSED: 'hotkey_pressed'>

        >>> Action.TASK.value
        'task'
    """

    # Lifecycle / Setup
    TASK = "task"

    # Metering
    AUDIO_LEVEL_UPDATED = "audio_level_updated"

    # Hotkey actions
    HOTKEY_PRESSED = "hotkey_pressed"
    HOTKEY_RELEASED = "hotkey_released"

    # Recording flow
    START_RECORDING = "start_recording"
    STOP_RECORDING = "stop_recording"

    # Cancel/discard flow
    CANCEL = "cancel"  # Explicit cancellation with sound
    DISCARD = "discard"  # Silent discard (too short/accidental)

    # Transcription result flow
    TRANSCRIPTION_RESULT = "transcription_result"
    TRANSCRIPTION_ERROR = "transcription_error"

    # Model availability
    MODEL_MISSING = "model_missing"
