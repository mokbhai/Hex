"""Main GUI application with system tray icon for Hex voice-to-text."""

from PySide6.QtWidgets import (
    QApplication,
    QSystemTrayIcon,
    QMenu,
)
from PySide6.QtGui import QIcon, QAction
from PySide6.QtCore import QObject, Signal, Slot
import sys
from pathlib import Path
from hex.utils.logging import get_logger

logger = get_logger("gui.app")


class HexApp(QObject):
    """Main application class managing the system tray and GUI."""

    # Signals for UI events
    settings_requested = Signal()
    history_requested = Signal()
    quit_requested = Signal()

    def __init__(self) -> None:
        """Initialize the Hex application with system tray icon."""
        super().__init__()

        # Create Qt Application if it doesn't exist
        self._app = QApplication.instance() or QApplication(sys.argv)
        self._app.setQuitOnLastWindowClosed(False)  # Don't quit when windows close

        # Create system tray icon
        self._tray_icon = QSystemTrayIcon()
        self._tray_icon.setVisible(True)

        # Create tray menu
        self._create_tray_menu()

        # Set icon
        self._set_tray_icon()

        logger.info("System tray icon initialized")

    def _create_tray_menu(self) -> None:
        """Create the context menu for the system tray icon."""
        menu = QMenu()

        # Check for Updates (placeholder for now - will be implemented later)
        # TODO: Implement auto-update check (Sparkle equivalent)
        # check_updates_action = QAction("Check for Updates...", self._app)
        # menu.addAction(check_updates_action)

        # Copy Last Transcript to Clipboard (placeholder for now)
        # TODO: Implement copy last transcript
        # copy_last_action = QAction("Copy Last Transcript", self._app)
        # menu.addAction(copy_last_action)

        # Settings...
        settings_action = QAction("Settings...", self._app)
        settings_action.triggered.connect(self._on_settings_clicked)
        menu.addAction(settings_action)

        # History... (viewer will be implemented in subtask-12-4)
        history_action = QAction("History...", self._app)
        history_action.triggered.connect(self._on_history_clicked)
        menu.addAction(history_action)

        menu.addSeparator()

        # Quit
        quit_action = QAction("Quit", self._app)
        quit_action.triggered.connect(self._on_quit_clicked)
        menu.addAction(quit_action)

        self._tray_icon.setContextMenu(menu)

    def _set_tray_icon(self) -> None:
        """Set the system tray icon."""
        # Try to find the icon file
        icon_path = Path(__file__).parent.parent / "resources" / "icons" / "hex-icon.svg"

        if icon_path.exists():
            icon = QIcon(str(icon_path))
            if not icon.isNull():
                self._tray_icon.setIcon(icon)
                logger.debug(f"Loaded tray icon from {icon_path}")
            else:
                logger.warning(f"Failed to load icon from {icon_path}, using default")
                self._tray_icon.setIcon(self._app.style().standardIcon(
                    self._app.style().SP_ComputerIcon
                ))
        else:
            logger.warning(f"Icon file not found at {icon_path}, using default icon")
            self._tray_icon.setIcon(self._app.style().standardIcon(
                self._app.style().SP_ComputerIcon
            ))

    @Slot()
    def _on_settings_clicked(self) -> None:
        """Handle Settings menu click."""
        logger.info("Settings requested from tray menu")
        self.settings_requested.emit()
        # TODO: Open settings dialog (will be implemented in subtask-12-3)

    @Slot()
    def _on_history_clicked(self) -> None:
        """Handle History menu click."""
        logger.info("History requested from tray menu")
        self.history_requested.emit()

        # Import here to avoid circular dependencies
        from hex.gui.history_dialog import HistoryDialog

        # Show history dialog
        dialog = HistoryDialog()
        dialog.exec()

    @Slot()
    def _on_quit_clicked(self) -> None:
        """Handle Quit menu click."""
        logger.info("Quit requested from tray menu")
        self.quit_requested.emit()
        self._app.quit()

    def show_message(
        self,
        title: str,
        message: str,
        icon: QSystemTrayIcon.MessageIcon = QSystemTrayIcon.Information,
    ) -> None:
        """
        Show a notification message from the system tray.

        Args:
            title: Message title
            message: Message body
            icon: Message icon type (Information, Warning, or Critical)
        """
        self._tray_icon.showMessage(title, message, icon, 3000)  # 3 seconds

    def run(self) -> int:
        """
        Start the application event loop.

        Returns:
            Exit code from the application
        """
        logger.info("Starting application event loop")
        return self._app.exec()

    def shutdown(self) -> None:
        """Clean shutdown of the application."""
        logger.info("Shutting down application")
        self._tray_icon.hide()
        self._app.quit()


def create_app() -> HexApp:
    """
    Factory function to create and initialize the Hex application.

    Returns:
        Initialized HexApp instance
    """
    app = HexApp()
    logger.info("Hex GUI application created")
    return app
