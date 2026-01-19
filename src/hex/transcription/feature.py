"""Transcription feature state machine.

This module implements the main transcription state machine using a queue-based
processing loop. It mirrors TranscriptionFeature from the Swift implementation,
adapted for Python's threading and async patterns.

The TranscriptionFeature orchestrates the entire recording and transcription flow:
- Hotkey detection and recording control
- Audio recording with metering
- Speech transcription via Ollama
- Text processing (word remapping/removal)
- Clipboard operations
- History persistence

Architecture:
- State is stored in a TranscriptionState dataclass
- Actions are dispatched via send() method onto a queue
- A background thread processes actions sequentially
- Handlers update state and trigger side effects
"""

import asyncio
import threading
from dataclasses import replace
from datetime import datetime
from pathlib import Path
from queue import Empty, Queue
from typing import Awaitable, Callable, Optional

from hex.clients.recording import RecordingClient
from hex.models.settings import HexSettings
from hex.models.transcription import Transcript
from hex.models.word_processing import WordRemapping, WordRemoval
from hex.transcription.actions import Action
from hex.transcription.state import Meter, TranscriptionState
from hex.utils.logging import get_logger, LogCategory


# Type aliases for action handlers
ActionHandler = Callable[[TranscriptionState, dict], Awaitable[None]]


class TranscriptionFeature:
    """Main transcription feature state machine.

    This class manages the entire transcription workflow using a queue-based
    processing pattern. Actions are dispatched from various parts of the system
    (hotkey monitor, audio recorder, transcription client) and processed
    sequentially to ensure thread-safe state updates.

    The processing loop runs in a background daemon thread, allowing the main
    thread to remain responsive for UI operations.

    Attributes:
        state: Current state of the transcription system
        settings: User settings and preferences

    Examples:
        >>> feature = TranscriptionFeature()
        >>> feature.send(Action.TASK)
        >>> feature.send(Action.HOTKEY_PRESSED)
        >>> print(feature.state.is_recording)
        True
    """

    def __init__(
        self,
        settings: Optional[HexSettings] = None,
        recording_client: Optional[RecordingClient] = None,
    ):
        """Initialize the TranscriptionFeature.

        Args:
            settings: User settings. If None, default settings are used.
            recording_client: Recording client for audio capture. If None, a new
                client is created with default settings.

        The initialization creates a background thread that processes actions
        from the queue. The thread is marked as daemon so it will be killed
        when the main thread exits.
        """
        self._logger = get_logger(LogCategory.TRANSCRIPTION)

        # Initialize state
        self.state = TranscriptionState()
        self.settings = settings or HexSettings()

        # Initialize clients
        self._recording_client = recording_client or RecordingClient()

        # Action processing
        self._action_queue: Queue[tuple[Action, dict]] = Queue()
        self._processing_thread = threading.Thread(
            target=self._process_loop,
            daemon=True,
            name="TranscriptionFeature-ProcessingLoop"
        )
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None

        # Start processing thread
        self._processing_thread.start()
        self._running = True

        self._logger.info("TranscriptionFeature initialized")

    def send(self, action: Action, **kwargs) -> None:
        """Dispatch an action to the state machine.

        This method is thread-safe and can be called from any thread.
        The action will be processed asynchronously by the background thread.

        Args:
            action: The action to dispatch
            **kwargs: Associated data for the action (e.g., result text for
                TRANSCRIPTION_RESULT, error for TRANSCRIPTION_ERROR)

        Examples:
            >>> feature.send(Action.TASK)
            >>> feature.send(Action.HOTKEY_PRESSED)
            >>> feature.send(Action.TRANSCRIPTION_RESULT, result="Hello", audio_url=Path("audio.wav"))
        """
        if not self._running:
            self._logger.warning(f"Cannot send action {action.value}: feature not running")
            return

        self._action_queue.put((action, kwargs))
        self._logger.debug(f"Action dispatched: {action.value}")

    def stop(self) -> None:
        """Stop the processing loop and clean up resources.

        This method waits for the processing thread to finish (up to 1 second).
        Call this before shutting down the application to ensure clean exit.
        """
        self._running = False
        # Send a sentinel to wake up the queue
        self._action_queue.put((Action.TASK, {}))  # Any action works

        # Wait for thread to finish
        self._processing_thread.join(timeout=1.0)

        self._logger.info("TranscriptionFeature stopped")

    def _process_loop(self) -> None:
        """Main processing loop for actions.

        This method runs in a background thread and continuously processes
        actions from the queue. Each action is handled by the appropriate
        handler method, which may update state and trigger side effects.

        The loop creates a new asyncio event loop for this thread, allowing
        async operations (recording, transcription, etc.) to be performed.
        """
        # Create event loop for this thread
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)

        try:
            while self._running:
                try:
                    # Get action from queue with timeout
                    action, kwargs = self._action_queue.get(timeout=0.1)

                    # Process the action
                    self._loop.run_until_complete(
                        self._process_action(action, kwargs)
                    )

                    # Mark action as done
                    self._action_queue.task_done()

                except Empty:
                    # No action available, continue loop
                    continue
                except Exception as e:
                    self._logger.error(
                        f"Error processing action {action.value}: {e}",
                        exc_info=True
                    )
        finally:
            # Clean up event loop
            self._loop.close()
            self._logger.debug("Processing loop terminated")

    async def _process_action(self, action: Action, kwargs: dict) -> None:
        """Process a single action.

        This method dispatches the action to the appropriate handler based on
        the action type. Handlers are responsible for updating state and
        triggering side effects.

        Args:
            action: The action to process
            kwargs: Associated data for the action

        Raises:
            Exception: If the action handler fails
        """
        self._logger.debug(f"Processing action: {action.value}")

        # Dispatch to appropriate handler
        if action == Action.TASK:
            await self._handle_task(kwargs)

        elif action == Action.AUDIO_LEVEL_UPDATED:
            await self._handle_audio_level_updated(kwargs)

        elif action == Action.HOTKEY_PRESSED:
            await self._handle_hotkey_pressed(kwargs)

        elif action == Action.HOTKEY_RELEASED:
            await self._handle_hotkey_released(kwargs)

        elif action == Action.START_RECORDING:
            await self._handle_start_recording(kwargs)

        elif action == Action.STOP_RECORDING:
            await self._handle_stop_recording(kwargs)

        elif action == Action.CANCEL:
            await self._handle_cancel(kwargs)

        elif action == Action.DISCARD:
            await self._handle_discard(kwargs)

        elif action == Action.TRANSCRIPTION_RESULT:
            await self._handle_transcription_result(kwargs)

        elif action == Action.TRANSCRIPTION_ERROR:
            await self._handle_transcription_error(kwargs)

        elif action == Action.MODEL_MISSING:
            await self._handle_model_missing(kwargs)

        else:
            self._logger.warning(f"Unknown action: {action.value}")

    # MARK: - Lifecycle Handlers

    async def _handle_task(self, kwargs: dict) -> None:
        """Handle TASK action - initialize the feature.

        This starts the metering stream, hotkey monitoring, and warms up
        the recorder for instant startup.
        """
        self._logger.info("Initializing TranscriptionFeature")
        # TODO: Start metering, hotkey monitoring, warm up recorder
        # These will be implemented in later subtasks

    # MARK: - Metering Handlers

    async def _handle_audio_level_updated(self, kwargs: dict) -> None:
        """Handle AUDIO_LEVEL_UPDATED action - update meter state."""
        meter: Meter = kwargs.get('meter', Meter())
        self.state = replace(self.state, meter=meter)
        self._logger.debug(f"Audio level updated: {meter.averagePower} dB")

    # MARK: - Hotkey Handlers

    async def _handle_hotkey_pressed(self, kwargs: dict) -> None:
        """Handle HOTKEY_PRESSED action.

        If already transcribing, cancel first. Otherwise start recording immediately.
        We'll decide later (on release) whether to keep or discard the recording.

        This mirrors handleHotKeyPressed from TranscriptionFeature.swift.
        """
        self._logger.debug("Hotkey pressed")

        # If already transcribing, send cancel first
        if self.state.is_transcribing:
            self._logger.info("Canceling active transcription before starting new recording")
            await self._handle_cancel(kwargs)

        # Always start recording immediately
        await self._handle_start_recording(kwargs)

    async def _handle_hotkey_released(self, kwargs: dict) -> None:
        """Handle HOTKEY_RELEASED action.

        This will be implemented in subtask-11-5.
        """
        self._logger.debug("Hotkey released")
        # TODO: Implement in subtask-11-5

    # MARK: - Recording Handlers

    async def _handle_start_recording(self, kwargs: dict) -> None:
        """Handle START_RECORDING action.

        Starts audio recording if model is ready. Updates state, logs the start time,
        and initiates audio capture.

        This mirrors handleStartRecording from TranscriptionFeature.swift.
        """
        # TODO: Check model readiness (modelBootstrapState.isModelReady)
        # For now, we'll assume the model is ready

        # Update state
        self.state = replace(self.state, is_recording=True)
        start_time = datetime.now()
        self.state = replace(self.state, recording_start_time=start_time)

        # TODO: Capture source application info (macOS-specific)
        # if let activeApp = NSWorkspace.shared.frontmostApplication {
        #     state.sourceAppBundleID = activeApp.bundleIdentifier
        #     state.sourceAppName = activeApp.localizedName
        # }

        # Log recording start with timestamp
        self._logger.notice(f"Recording started at {start_time.isoformat()}")

        # Start audio recording
        # TODO: Play sound effect (soundEffect.play(.startRecording))
        # TODO: Prevent system sleep if setting enabled

        try:
            await self._recording_client.start_recording()
            self._logger.info("Recording started successfully")
        except Exception as e:
            self._logger.error(f"Failed to start recording: {e}")
            self.state = replace(self.state, is_recording=False, error=str(e))

    async def _handle_stop_recording(self, kwargs: dict) -> None:
        """Handle STOP_RECORDING action.

        This will be implemented in subtask-11-5.
        """
        self._logger.info("Stopping recording")
        # TODO: Implement in subtask-11-5

    # MARK: - Cancel/Discard Handlers (stubs for now)

    async def _handle_cancel(self, kwargs: dict) -> None:
        """Handle CANCEL action.

        This will be implemented in subtask-11-7.
        """
        self._logger.info("Canceling recording")
        # TODO: Implement in subtask-11-7

    async def _handle_discard(self, kwargs: dict) -> None:
        """Handle DISCARD action.

        This will be implemented in subtask-11-7.
        """
        self._logger.info("Discarding recording")
        # TODO: Implement in subtask-11-7

    # MARK: - Transcription Handlers (stubs for now)

    async def _handle_transcription_result(self, kwargs: dict) -> None:
        """Handle TRANSCRIPTION_RESULT action.

        This will be implemented in subtask-11-6.
        """
        result: str = kwargs.get('result', '')
        audio_url: Path = kwargs.get('audio_url', Path())
        self._logger.info(f"Transcription result: {len(result)} characters")
        # TODO: Implement in subtask-11-6

    async def _handle_transcription_error(self, kwargs: dict) -> None:
        """Handle TRANSCRIPTION_ERROR action.

        This will be implemented in subtask-11-6.
        """
        error: Exception = kwargs.get('error', Exception("Unknown error"))
        audio_url: Optional[Path] = kwargs.get('audio_url')
        self.state = replace(self.state, error=str(error))
        self._logger.error(f"Transcription error: {error}")
        # TODO: Implement in subtask-11-6

    # MARK: - Model Handlers

    async def _handle_model_missing(self, kwargs: dict) -> None:
        """Handle MODEL_MISSING action."""
        self._logger.warning("Transcription model is not available")
        # TODO: Show user notification, trigger model download

    def __repr__(self) -> str:
        """Return string representation of the feature."""
        return (
            f"TranscriptionFeature("
            f"is_recording={self.state.is_recording}, "
            f"is_transcribing={self.state.is_transcribing})"
        )
