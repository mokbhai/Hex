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
import re
import threading
from dataclasses import replace
from datetime import datetime
from pathlib import Path
from queue import Empty, Queue
from typing import Awaitable, Callable, Optional

from vox.clients.clipboard import ClipboardClient
from vox.clients.recording import RecordingClient
from vox.clients.sound_effects import SoundEffect, SoundEffectsClient
from vox.clients.transcript_persistence import TranscriptPersistenceClient
from vox.models.settings import VoxSettings
from vox.models.transcription import Transcript
from vox.models.word_processing import WordRemapping, WordRemoval, WordRemappingApplier, WordRemovalApplier
from vox.transcription.actions import Action
from vox.transcription.state import Meter, TranscriptionState
from vox.utils.logging import get_logger, LogCategory


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
        settings: Optional[VoxSettings] = None,
        recording_client: Optional[RecordingClient] = None,
        clipboard_client: Optional[ClipboardClient] = None,
        sound_effects_client: Optional[SoundEffectsClient] = None,
        transcript_persistence_client: Optional[TranscriptPersistenceClient] = None,
    ):
        """Initialize the TranscriptionFeature.

        Args:
            settings: User settings. If None, default settings are used.
            recording_client: Recording client for audio capture. If None, a new
                client is created with default settings.
            clipboard_client: Clipboard client for paste operations. If None, a new
                client is created with default settings.
            sound_effects_client: Sound effects client for audio feedback. If None,
                a new client is created with default settings.
            transcript_persistence_client: Persistence client for saving transcripts.
                If None, a new client is created with default settings.

        The initialization creates a background thread that processes actions
        from the queue. The thread is marked as daemon so it will be killed
        when the main thread exits.
        """
        self._logger = get_logger(LogCategory.TRANSCRIPTION)

        # Initialize state
        self.state = TranscriptionState()
        self.settings = settings or VoxSettings()

        # Initialize clients
        self._recording_client = recording_client or RecordingClient()
        self._clipboard_client = clipboard_client or ClipboardClient()
        self._sound_effects_client = sound_effects_client or SoundEffectsClient(
            enabled=self.settings.soundEffectsEnabled,
            volume=self.settings.soundEffectsVolume,
        )
        self._transcript_persistence_client = transcript_persistence_client or TranscriptPersistenceClient()

        # Transcription history (thread-safe list)
        self._transcription_history: list[Transcript] = []

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

        If currently recording, stop recording. Otherwise, do nothing.

        This mirrors handleHotKeyReleased from TranscriptionFeature.swift.
        """
        self._logger.debug("Hotkey released")

        # Only stop if we're currently recording
        if self.state.is_recording:
            await self._handle_stop_recording(kwargs)

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

        Stops audio recording and updates state. Logs the stop time and duration.

        This mirrors handleStopRecording from TranscriptionFeature.swift.
        The full implementation will include RecordingDecisionEngine logic,
        but for now we just stop the recording and update state.
        """
        if not self.state.is_recording:
            self._logger.warning("stop_recording called while not recording")
            return

        # Update state
        self.state = replace(self.state, is_recording=False)

        # Calculate duration
        stop_time = datetime.now()
        start_time = self.state.recording_start_time
        duration = (stop_time - start_time).total_seconds() if start_time else 0.0

        start_stamp = start_time.isoformat() if start_time else "nil"
        stop_stamp = stop_time.isoformat()

        self._logger.notice(
            f"Recording stopped duration={duration:.3f}s "
            f"start={start_stamp} stop={stop_stamp}"
        )

        # Stop the recording client
        try:
            audio_url = await self._recording_client.stop_recording()
            self._logger.info(f"Recording stopped successfully: {audio_url}")
        except Exception as e:
            self._logger.error(f"Failed to stop recording: {e}")
            self.state = replace(self.state, error=str(e))

    # MARK: - Cancel/Discard Handlers

    async def _handle_cancel(self, kwargs: dict) -> None:
        """Handle CANCEL action - Explicit cancellation with sound.

        This action cancels the current recording or transcription with a sound
        effect to provide feedback to the user. It's used when:
        - User presses Escape while idle
        - User cancels via HotKeyProcessor (modifier key held too long, then cancelled)
        - Any explicit cancellation of recording/transcription

        Only cancels if we're in the middle of recording, transcribing, or prewarming.
        Updates state, cancels any pending transcription, stops recording,
        deletes audio file, and plays cancel sound effect.

        This mirrors handleCancel from TranscriptionFeature.swift.
        """
        # Only cancel if we're in the middle of recording, transcribing, or prewarming
        if not (self.state.is_recording or self.state.is_transcribing):
            self._logger.debug("Cancel action ignored: not recording or transcribing")
            return

        self._logger.info("Canceling recording/transcription")

        # Update state
        self.state = replace(
            self.state,
            is_transcribing=False,
            is_recording=False,
            is_prewarming=False,
        )

        # Cancel any pending transcription and stop recording
        # TODO: Cancel pending transcription (CancelID.transcription)
        # TODO: Allow system sleep (sleepManagement.allowSleep)

        # Stop recording to release microphone access
        try:
            audio_url = await self._recording_client.stop_recording()
            self._logger.info(f"Recording stopped due to cancel: {audio_url}")

            # Delete the audio file
            try:
                if audio_url and audio_url.exists():
                    audio_url.unlink()
                    self._logger.debug(f"Deleted audio file: {audio_url}")
            except Exception as e:
                self._logger.warning(f"Failed to delete audio file: {e}")

        except Exception as e:
            self._logger.error(f"Failed to stop recording during cancel: {e}")

        # Play cancel sound effect
        try:
            await self._sound_effects_client.play(SoundEffect.CANCEL)
            self._logger.debug("Played cancel sound effect")
        except Exception as e:
            self._logger.warning(f"Failed to play cancel sound effect: {e}")

    async def _handle_discard(self, kwargs: dict) -> None:
        """Handle DISCARD action - Silent discard for quick/accidental recordings.

        This action silently discards a recording without playing a sound effect.
        It's used when:
        - Recording was too short (below minimumKeyTime threshold)
        - Accidental recording detected (e.g., modifier-only hotkey pressed briefly)
        - Mouse click or extra modifier detected during threshold period

        Only discards if we're currently recording. Updates state, stops recording,
        deletes audio file, and allows system sleep - all without sound feedback.

        This mirrors handleDiscard from TranscriptionFeature.swift.
        """
        # Only discard if we're currently recording
        if not self.state.is_recording:
            self._logger.debug("Discard action ignored: not recording")
            return

        self._logger.info("Silently discarding recording")

        # Update state
        self.state = replace(
            self.state,
            is_recording=False,
            is_prewarming=False,
        )

        # TODO: Allow system sleep (sleepManagement.allowSleep)

        # Stop recording and delete audio file silently
        try:
            audio_url = await self._recording_client.stop_recording()
            self._logger.info(f"Recording stopped due to discard: {audio_url}")

            # Delete the audio file
            try:
                if audio_url and audio_url.exists():
                    audio_url.unlink()
                    self._logger.debug(f"Deleted audio file: {audio_url}")
            except Exception as e:
                self._logger.warning(f"Failed to delete audio file: {e}")

        except Exception as e:
            self._logger.error(f"Failed to stop recording during discard: {e}")

    # MARK: - Transcription Handlers

    async def _handle_transcription_result(self, kwargs: dict) -> None:
        """Handle TRANSCRIPTION_RESULT action.

        Processes the transcription result by:
        1. Updating state to mark transcription as complete
        2. Checking for force quit command
        3. Applying word removals and remappings
        4. Saving to history if enabled
        5. Pasting to clipboard
        6. Playing sound effect

        This mirrors handleTranscriptionResult from TranscriptionFeature.swift.
        """
        result: str = kwargs.get('result', '')
        audio_url: Path = kwargs.get('audio_url', Path())

        # Update state
        self.state = replace(self.state, is_transcribing=False, is_prewarming=False)

        # Check for force quit command (emergency escape hatch)
        if self._matches_force_quit_command(result):
            self._logger.fault("Force quit voice command recognized; terminating Hex")
            # Delete audio file
            try:
                if audio_url.exists():
                    audio_url.unlink()
            except Exception as e:
                self._logger.error(f"Failed to delete audio file: {e}")
            # TODO: Terminate application (need to implement app shutdown)
            return

        # If empty text, nothing else to do
        if not result:
            self._logger.debug("Empty transcription result, skipping")
            return

        # Calculate duration
        duration = 0.0
        if self.state.recording_start_time:
            duration = (datetime.now() - self.state.recording_start_time).total_seconds()

        self._logger.info(f"Raw transcription: '{result}'")

        # Apply word removals and remappings
        remappings = self.settings.wordRemappings
        removals_enabled = self.settings.wordRemovalsEnabled
        removals = self.settings.wordRemovals

        # Check if scratchpad is focused (skip modifications if so)
        # TODO: Implement is_remapping_scratchpad_focused check
        is_scratchpad_focused = False

        if is_scratchpad_focused:
            modified_result = result
            self._logger.info("Scratchpad focused; skipping word modifications")
        else:
            output = result
            if removals_enabled and removals:
                removed_result = WordRemovalApplier.apply(output, removals)
                if removed_result != output:
                    enabled_removal_count = sum(1 for r in removals if r.is_enabled)
                    self._logger.info(f"Applied {enabled_removal_count} word removal(s)")
                output = removed_result

            if remappings:
                remapped_result = WordRemappingApplier.apply(output, remappings)
                if remapped_result != output:
                    self._logger.info(f"Applied {len(remappings)} word remapping(s)")
                output = remapped_result

            modified_result = output

        # If modified result is empty, nothing else to do
        if not modified_result:
            self._logger.debug("Modified transcription result is empty, skipping")
            return

        # Finalize and save
        try:
            await self._finalize_recording_and_store_transcript(
                result=modified_result,
                duration=duration,
                source_app_bundle_id=self.state.source_app_bundle_id,
                source_app_name=self.state.source_app_name,
                audio_url=audio_url,
            )
        except Exception as e:
            self._logger.error(f"Failed to finalize transcription: {e}")
            # Send error action
            await self._handle_transcription_error({'error': e, 'audio_url': audio_url})

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

    # MARK: - Helper Methods

    def _matches_force_quit_command(self, text: str) -> bool:
        """Check if text matches the force quit command.

        This is an emergency escape hatch that allows users to quit Hex
        via voice command if the app becomes unresponsive.

        Args:
            text: The transcribed text to check

        Returns:
            True if the text matches "force quit vox" or "force quit vox now"
        """
        normalized = self._normalize_force_quit_text(text)
        return normalized in ("force quit vox now", "force quit vox")

    def _normalize_force_quit_text(self, text: str) -> str:
        """Normalize text for force quit command matching.

        Removes diacritics, converts to lowercase, and removes non-alphanumeric
        characters except spaces.

        Args:
            text: The text to normalize

        Returns:
            Normalized text
        """
        import unicodedata

        # Normalize unicode (remove diacritics)
        normalized = unicodedata.normalize('NFKD', text)
        # Remove diacritic marks
        normalized = ''.join(
            c for c in normalized
            if not unicodedata.combining(c)
        )
        # Convert to lowercase
        normalized = normalized.lower()
        # Replace non-alphanumeric characters (except spaces) with spaces
        normalized = re.sub(r'[^a-z0-9\s]', ' ', normalized)
        # Collapse multiple spaces
        normalized = re.sub(r'\s+', ' ', normalized)
        # Strip leading/trailing whitespace
        normalized = normalized.strip()

        return normalized

    async def _finalize_recording_and_store_transcript(
        self,
        result: str,
        duration: float,
        source_app_bundle_id: Optional[str],
        source_app_name: Optional[str],
        audio_url: Path,
    ) -> None:
        """Finalize recording and store transcript.

        This method:
        1. Saves the transcript to history if enabled
        2. Manages history size (trim if exceeds max entries)
        3. Deletes audio file if history saving is disabled
        4. Pastes the result to the clipboard
        5. Plays the paste transcript sound effect

        Args:
            result: The transcribed text
            duration: Duration of the recording in seconds
            source_app_bundle_id: Bundle ID of the source app
            source_app_name: Name of the source app
            audio_url: Path to the audio file

        This mirrors finalizeRecordingAndStoreTranscript from TranscriptionFeature.swift.
        """
        if self.settings.saveTranscriptionHistory:
            # Save transcript to history
            try:
                transcript = await self._transcript_persistence_client.save(
                    result=result,
                    audio_url=audio_url,
                    duration=duration,
                    source_app_bundle_id=source_app_bundle_id,
                    source_app_name=source_app_name,
                )

                # Insert at beginning of history
                self._transcription_history.insert(0, transcript)

                # Trim history if exceeds max entries
                max_entries = self.settings.maxHistoryEntries
                if max_entries and max_entries > 0:
                    while len(self._transcription_history) > max_entries:
                        removed_transcript = self._transcription_history.pop()
                        # Delete audio file for removed transcript
                        try:
                            await self._transcript_persistence_client.delete_audio(removed_transcript)
                        except Exception as e:
                            self._logger.warning(f"Failed to delete audio for trimmed transcript: {e}")

                self._logger.info(f"Saved transcript {transcript.id} with {len(result)} characters")

            except Exception as e:
                self._logger.error(f"Failed to save transcript: {e}")
                raise
        else:
            # Delete audio file if not saving to history
            try:
                if audio_url.exists():
                    audio_url.unlink()
                    self._logger.debug(f"Deleted audio file: {audio_url}")
            except Exception as e:
                self._logger.warning(f"Failed to delete audio file: {e}")

        # Paste to clipboard
        try:
            await self._clipboard_client.paste(result)
            self._logger.info(f"Pasted {len(result)} characters to clipboard")
        except Exception as e:
            self._logger.error(f"Failed to paste to clipboard: {e}")

        # Play sound effect
        try:
            await self._sound_effects_client.play(SoundEffect.PASTE_TRANSCRIPT)
        except Exception as e:
            self._logger.warning(f"Failed to play sound effect: {e}")

    def __repr__(self) -> str:
        """Return string representation of the feature."""
        return (
            f"TranscriptionFeature("
            f"is_recording={self.state.is_recording}, "
            f"is_transcribing={self.state.is_transcribing})"
        )
