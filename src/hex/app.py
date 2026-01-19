"""Main application module for Hex voice-to-text.

This module wires together all components of the Hex application:
- Loads user settings
- Initializes all clients (recording, transcription, clipboard, etc.)
- Creates the main TranscriptionFeature state machine
- Starts hotkey monitoring
- Connects GUI signals to business logic
- Manages application lifecycle

The architecture mirrors the Swift AppFeature.swift, adapted for Python's
async/await and threading patterns.
"""

import asyncio
import sys
from pathlib import Path
from typing import Optional

from hex.clients.clipboard import ClipboardClient
from hex.clients.key_event_monitor import KeyEventMonitorClient
from hex.clients.permissions import check_accessibility_permission
from hex.clients.recording import RecordingClient
from hex.clients.sound_effects import SoundEffectsClient
from hex.clients.transcript_persistence import TranscriptPersistenceClient
from hex.clients.transcription import TranscriptionClient
from hex.gui import HexApp, RecordingIndicator, IndicatorStatus, create_app
from hex.models.hotkey import HotKey, Modifier
from hex.models.settings import HexSettings
from hex.settings.manager import SettingsManager
from hex.transcription.actions import Action
from hex.transcription.feature import TranscriptionFeature
from hex.utils.logging import get_logger, LogCategory
from hex.utils.sound import SoundEffect

logger = get_logger(LogCategory.APP)


class HexApplication:
    """Main application class that wires all components together.

    This class is equivalent to AppFeature in the Swift implementation.
    It manages the lifecycle of all components and coordinates their interactions.

    Attributes:
        app: The GUI application (HexApp)
        settings: User settings loaded from disk
        transcription_feature: Main state machine for transcription workflow
        key_event_monitor: Global hotkey monitoring client
        recording_indicator: Visual recording indicator overlay
    """

    def __init__(self):
        """Initialize the Hex application with all components."""
        logger.info("Initializing Hex application")

        # Create event loop for async operations
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)

        # Load settings
        self._settings_manager = SettingsManager()
        self.settings = self._loop.run_until_complete(self._load_settings())

        # Initialize all clients
        self._recording_client = RecordingClient()
        self._transcription_client = TranscriptionClient()
        self._clipboard_client = ClipboardClient()
        self._sound_effects_client = SoundEffectsClient(
            enabled=self.settings.soundEffectsEnabled,
            volume=self.settings.soundEffectsVolume,
        )
        self._transcript_persistence_client = TranscriptPersistenceClient()
        self._key_event_monitor = KeyEventMonitorClient()

        # Create TranscriptionFeature with all dependencies
        self.transcription_feature = TranscriptionFeature(
            settings=self.settings,
            recording_client=self._recording_client,
            clipboard_client=self._clipboard_client,
            sound_effects_client=self._sound_effects_client,
            transcript_persistence_client=self._transcript_persistence_client,
        )

        # Create GUI application
        self.app = create_app()
        self._connect_gui_signals()

        # Create recording indicator
        self.recording_indicator = RecordingIndicator()

        # Start hotkey monitoring
        self._hotkey_monitor_token = None
        self._start_hotkey_monitoring()

        logger.info("Hex application initialized successfully")

    async def _load_settings(self) -> HexSettings:
        """Load settings from disk or create defaults.

        Returns:
            Loaded HexSettings with defaults applied for any missing values
        """
        try:
            settings = await self._settings_manager.load()
            logger.info(f"Loaded settings with hotkey: {settings.hotkey}")
            return settings
        except Exception as e:
            logger.error(f"Failed to load settings, using defaults: {e}", exc_info=True)
            return HexSettings()

    def _connect_gui_signals(self):
        """Connect GUI signals to business logic."""
        # Connect settings_requested signal
        self.app.settings_requested.connect(self._on_settings_requested)

        # Connect history_requested signal
        self.app.history_requested.connect(self._on_history_requested)

        # Connect quit_requested signal for cleanup
        self.app.quit_requested.connect(self._on_quit_requested)

    def _on_settings_requested(self):
        """Handle settings dialog request."""
        logger.info("Opening settings dialog")

        # Import here to avoid circular dependency
        from hex.gui.settings_dialog import SettingsDialog

        # Create settings dialog with current settings
        dialog = SettingsDialog(self.settings)
        if dialog.exec():
            # Settings were saved - reload them
            logger.info("Settings saved, reloading")
            self.settings = self._loop.run_until_complete(self._load_settings())

            # Update TranscriptionFeature settings
            self.transcription_feature.settings = self.settings

            # Update sound effects client
            self._sound_effects_client.enabled = self.settings.soundEffectsEnabled
            self._sound_effects_client.volume = self.settings.soundEffectsVolume

            # Restart hotkey monitoring with new hotkey
            self._restart_hotkey_monitoring()

    def _on_history_requested(self):
        """Handle history dialog request."""
        logger.info("History dialog requested (handled by GUI app)")

    def _on_quit_requested(self):
        """Handle quit request with proper cleanup."""
        logger.info("Quit requested, cleaning up")
        self.shutdown()

    def _start_hotkey_monitoring(self):
        """Start global hotkey monitoring for recording."""
        try:
            # Check accessibility permission on macOS
            if not check_accessibility_permission():
                logger.warning(
                    "Accessibility permission not granted. "
                    "Please grant permission in System Settings > Privacy & Security > Accessibility"
                )
                # TODO: Show dialog to user requesting permission
                return

            # Register hotkey handler with KeyEventMonitor
            self._hotkey_monitor_token = (
                self._key_event_monitor.handle_key_event(
                    self._on_hotkey_event
                )
            )

            # Start monitoring
            self._key_event_monitor.start_monitoring()

            logger.info(f"Hotkey monitoring started for: {self.settings.hotkey}")

        except Exception as e:
            logger.error(f"Failed to start hotkey monitoring: {e}", exc_info=True)

    def _restart_hotkey_monitoring(self):
        """Restart hotkey monitoring with updated settings."""
        logger.info("Restarting hotkey monitoring")

        # Cancel existing monitoring
        if self._hotkey_monitor_token:
            self._hotkey_monitor_token.cancel()
            self._hotkey_monitor_token = None

        # Start with new hotkey
        self._start_hotkey_monitoring()

    def _on_hotkey_event(self, event):
        """Handle hotkey events from KeyEventMonitor.

        Args:
            event: KeyEvent from the monitor

        Returns:
            True to consume the event, False to let it propagate
        """
        from hex.models.key_event import InputEventType

        # Only process key down and key up events
        if event.event_type not in [
            InputEventType.KEY_DOWN,
            InputEventType.KEY_UP,
        ]:
            return False

        # Check if this event matches our hotkey
        if not self._matches_hotkey(event):
            return False

        # Dispatch appropriate action to TranscriptionFeature
        if event.event_type == InputEventType.KEY_DOWN:
            logger.debug("Hotkey pressed - starting recording")
            self.transcription_feature.send(Action.HOTKEY_PRESSED)

            # Show recording indicator
            self.recording_indicator.set_status(IndicatorStatus.RECORDING)
            self.recording_indicator.show()

        elif event.event_type == InputEventType.KEY_UP:
            logger.debug("Hotkey released - stopping recording")
            self.transcription_feature.send(Action.HOTKEY_RELEASED)

            # Hide recording indicator
            self.recording_indicator.hide()

        # Consume the event so it doesn't propagate to other apps
        return True

    def _matches_hotkey(self, event) -> bool:
        """Check if a key event matches the configured hotkey.

        Args:
            event: KeyEvent to check

        Returns:
            True if the event matches the hotkey, False otherwise
        """
        hotkey = self.settings.hotkey

        # Check key match
        if hotkey.key and event.key != hotkey.key:
            return False

        # Check modifiers match
        event_modifiers = event.modifiers or []
        hotkey_modifiers = hotkey.modifiers or []

        # Check if all required modifiers are present
        for modifier in hotkey_modifiers:
            if modifier not in event_modifiers:
                return False

        # Check if no extra modifiers are present (except allowed ones)
        # For now, we'll allow extra modifiers to be more permissive
        # TODO: Implement exact modifier matching like Swift version

        return True

    def run(self) -> int:
        """Start the application event loop.

        Returns:
            Application exit code
        """
        logger.info("Starting Hex application event loop")

        try:
            # Send TASK action to initialize TranscriptionFeature
            self.transcription_feature.send(Action.TASK)

            # Enter Qt event loop
            return self.app.run()

        except KeyboardInterrupt:
            logger.info("Application interrupted by user")
            return 0
        except Exception as e:
            logger.error(f"Application error: {e}", exc_info=True)
            return 1
        finally:
            self.shutdown()

    def shutdown(self):
        """Clean shutdown of all components."""
        logger.info("Shutting down Hex application")

        try:
            # Stop hotkey monitoring
            if self._hotkey_monitor_token:
                self._hotkey_monitor_token.cancel()
                self._hotkey_monitor_token = None

            # Stop key event monitor
            self._key_event_monitor.stop_monitoring()

            # Stop TranscriptionFeature
            if hasattr(self, 'transcription_feature'):
                self.transcription_feature.stop()

            # Hide recording indicator
            self.recording_indicator.hide()

            # Shutdown GUI
            self.app.shutdown()

            # Close event loop
            if self._loop and not self._loop.is_closed():
                pending = asyncio.all_tasks(self._loop)
                for task in pending:
                    task.cancel()
                self._loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
                self._loop.close()

            logger.info("Hex application shutdown complete")

        except Exception as e:
            logger.error(f"Error during shutdown: {e}", exc_info=True)


def main() -> int:
    """
    Main application entry point.

    Initializes and runs the Hex voice-to-text application.

    Returns:
        Application exit code
    """
    logger.info("Starting Hex voice-to-text application")

    try:
        # Create and run application
        app = HexApplication()
        return app.run()

    except Exception as e:
        logger.error(f"Failed to start application: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
