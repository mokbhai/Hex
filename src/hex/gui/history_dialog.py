"""History viewer dialog for Hex voice-to-text application.

This module provides the History UI for viewing and managing past transcriptions.
It mirrors the structure from Hex/Features/Settings/HistorySectionView.swift
adapted for PySide6.
"""

from datetime import datetime
from pathlib import Path
from typing import List, Optional

from PySide6.QtWidgets import (
    QDialog,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QLabel,
    QPushButton,
    QListWidget,
    QListWidgetItem,
    QTextEdit,
    QMessageBox,
    QProgressBar,
    QWidget,
    QFrame,
    QSizePolicy,
    QDialogButtonBox,
)
from PySide6.QtCore import Qt, Signal, Slot, QTimer
from PySide6.QtGui import QFont, QTextCursor, QApplication

from hex.models.transcription import Transcript
from hex.clients.transcript_persistence import TranscriptPersistenceClient
from hex.utils.logging import get_logger

logger = get_logger("gui.history_dialog")


class HistoryDialog(QDialog):
    """Dialog for viewing and managing transcription history.

    This dialog displays a list of past transcriptions with options to:
    - View full transcription text
    - Copy text to clipboard
    - Delete individual entries
    - Clear all history

    The dialog loads history asynchronously and shows a loading indicator
    while fetching data from TranscriptPersistenceClient.
    """

    # Signal emitted when history is modified (entries deleted)
    history_modified = Signal()

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        """Initialize the History dialog.

        Args:
            parent: Parent widget (typically the main window)
        """
        super().__init__(parent)

        self._transcripts: List[Transcript] = []
        self._persistence_client = TranscriptPersistenceClient()
        self._selected_transcript: Optional[Transcript] = None

        self._setup_ui()
        self._load_history()

    def _setup_ui(self) -> None:
        """Set up the user interface for the history dialog."""
        self.setWindowTitle("Transcription History")
        self.setMinimumSize(800, 600)
        self.resize(900, 700)

        # Main layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(12)

        # Title label
        title_label = QLabel("Transcription History")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title_label.setFont(title_font)
        layout.addWidget(title_label)

        # Loading indicator (hidden by default)
        self._loading_widget = QWidget()
        loading_layout = QVBoxLayout(self._loading_widget)
        self._loading_label = QLabel("Loading history...")
        self._loading_progress = QProgressBar()
        self._loading_progress.setRange(0, 0)  # Indeterminate progress
        self._loading_progress.setTextVisible(False)
        loading_layout.addWidget(self._loading_label)
        loading_layout.addWidget(self._loading_progress)
        layout.addWidget(self._loading_widget)

        # Content widget (contains the list and details)
        self._content_widget = QWidget()
        content_layout = QHBoxLayout(self._content_widget)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(12)

        # Left side: List of transcriptions
        list_layout = QVBoxLayout()
        list_layout.setContentsMargins(0, 0, 0, 0)

        self._list_widget = QListWidget()
        self._list_widget.setAlternatingRowColors(True)
        self._list_widget.setSelectionMode(QListWidget.SingleSelection)
        self._list_widget.currentItemChanged.connect(self._on_selection_changed)
        list_layout.addWidget(self._list_widget)

        # List control buttons
        list_controls_layout = QHBoxLayout()
        self._refresh_button = QPushButton("Refresh")
        self._refresh_button.clicked.connect(self._load_history)
        list_controls_layout.addWidget(self._refresh_button)

        self._clear_all_button = QPushButton("Clear All")
        self._clear_all_button.clicked.connect(self._clear_all_history)
        list_controls_layout.addWidget(self._clear_all_button)

        list_layout.addLayout(list_controls_layout)
        content_layout.addLayout(list_layout, stretch=1)

        # Right side: Transcript details
        details_layout = QVBoxLayout()
        details_layout.setContentsMargins(0, 0, 0, 0)

        # Details card
        self._details_card = QFrame()
        self._details_card.setFrameShape(QFrame.StyledPanel)
        self._details_card.setFrameShadow(QFrame.Raised)
        details_card_layout = QVBoxLayout(self._details_card)

        # Details header
        self._details_header = QLabel("Select a transcription to view details")
        details_header_font = QFont()
        details_header_font.setPointSize(12)
        details_header_font.setBold(True)
        self._details_header.setFont(details_header_font)
        details_card_layout.addWidget(self._details_header)

        # Details metadata
        self._metadata_label = QLabel()
        self._metadata_label.setWordWrap(True)
        metadata_font = QFont()
        metadata_font.setPointSize(9)
        self._metadata_label.setFont(metadata_font)
        details_card_layout.addWidget(self._metadata_label)

        # Separator
        separator = QFrame()
        separator.setFrameShape(QFrame.HLine)
        separator.setFrameShadow(QFrame.Sunken)
        details_card_layout.addWidget(separator)

        # Transcript text
        self._text_label = QLabel("Text:")
        text_label_font = QFont()
        text_label_font.setBold(True)
        self._text_label.setFont(text_label_font)
        details_card_layout.addWidget(self._text_label)

        self._text_edit = QTextEdit()
        self._text_edit.setReadOnly(True)
        self._text_edit.setPlaceholderText("No transcription selected")
        details_card_layout.addWidget(self._text_edit)

        # Details control buttons
        details_controls_layout = QHBoxLayout()

        self._copy_button = QPushButton("Copy to Clipboard")
        self._copy_button.setEnabled(False)
        self._copy_button.clicked.connect(self._copy_to_clipboard)
        details_controls_layout.addWidget(self._copy_button)

        self._delete_button = QPushButton("Delete")
        self._delete_button.setEnabled(False)
        self._delete_button.clicked.connect(self._delete_selected)
        details_controls_layout.addWidget(self._delete_button)

        details_card_layout.addLayout(details_controls_layout)
        details_layout.addWidget(self._details_card)

        content_layout.addLayout(details_layout, stretch=2)

        layout.addWidget(self._content_widget)

        # Status bar
        self._status_label = QLabel("")
        status_font = QFont()
        status_font.setPointSize(9)
        self._status_label.setFont(status_font)
        layout.addWidget(self._status_label)

        # Initially show loading, hide content
        self._content_widget.setVisible(False)

    def _load_history(self) -> None:
        """Load transcription history from persistence client.

        Shows loading indicator while fetching data asynchronously.
        """
        logger.info("Loading transcription history")

        # Show loading widget, hide content
        self._content_widget.setVisible(False)
        self._loading_widget.setVisible(True)
        self._list_widget.clear()

        # Use QTimer to simulate async loading and not block UI
        QTimer.singleShot(50, self._perform_load)

    def _perform_load(self) -> None:
        """Perform the actual history loading operation.

        This method is called via QTimer to avoid blocking the UI.
        """
        import asyncio

        try:
            # Load history
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            transcripts = loop.run_until_complete(self._persistence_client.load())
            loop.close()

            self._transcripts = transcripts

            # Populate list
            self._populate_list()

            # Update status
            count = len(transcripts)
            if count == 0:
                self._status_label.setText("No transcriptions in history")
                self._details_header.setText("No history available")
                self._metadata_label.setText("")
                self._text_edit.setPlaceholderText(
                    "No transcriptions found. Start recording to build your history."
                )
            else:
                self._status_label.setText(f"Showing {count} transcription(s)")

            # Hide loading, show content
            self._loading_widget.setVisible(False)
            self._content_widget.setVisible(True)

            logger.info(f"Loaded {count} transcription(s)")

        except Exception as e:
            logger.error(f"Error loading history: {e}")
            self._loading_label.setText(f"Error loading history: {e}")
            self._loading_progress.setRange(0, 1)  # Stop indeterminate progress
            self._loading_progress.setValue(0)

    def _populate_list(self) -> None:
        """Populate the list widget with transcripts.

        Sorts transcripts by timestamp (newest first) and creates
        list items with formatted display text.
        """
        self._list_widget.clear()

        # Sort by timestamp (newest first)
        sorted_transcripts = sorted(
            self._transcripts, key=lambda t: t.timestamp, reverse=True
        )

        for transcript in sorted_transcripts:
            # Create list item
            item = QListWidgetItem()
            item.setData(Qt.UserRole, transcript)  # Store transcript object

            # Format display text
            display_text = self._format_list_item(transcript)
            item.setText(display_text)

            # Add tooltip with full text
            item.setToolTip(transcript.text)

            self._list_widget.addItem(item)

    def _format_list_item(self, transcript: Transcript) -> str:
        """Format a transcript for display in the list widget.

        Args:
            transcript: The transcript to format

        Returns:
            Formatted string with date/time and text preview
        """
        # Format timestamp
        timestamp_str = transcript.timestamp.strftime("%Y-%m-%d %H:%M:%S")

        # Truncate text for preview (max 80 characters)
        text_preview = transcript.text
        if len(text_preview) > 80:
            text_preview = text_preview[:77] + "..."

        # Format duration
        duration_minutes = int(transcript.duration // 60)
        duration_seconds = int(transcript.duration % 60)
        if duration_minutes > 0:
            duration_str = f"{duration_minutes}m {duration_seconds}s"
        else:
            duration_str = f"{duration_seconds}s"

        # Add source app if available
        source_str = ""
        if transcript.source_app_name:
            source_str = f" • {transcript.source_app_name}"

        # Combine all parts
        display = f"{timestamp_str}{source_str} • {duration_str}\n{text_preview}"

        return display

    @Slot()
    def _on_selection_changed(
        self, current: QListWidgetItem, previous: QListWidgetItem
    ) -> None:
        """Handle list selection change.

        Args:
            current: The newly selected item
            previous: The previously selected item
        """
        if current is None:
            self._selected_transcript = None
            self._details_header.setText("Select a transcription to view details")
            self._metadata_label.setText("")
            self._text_edit.setPlainText("")
            self._copy_button.setEnabled(False)
            self._delete_button.setEnabled(False)
            return

        # Get transcript from item data
        transcript = current.data(Qt.UserRole)
        if transcript is None:
            return

        self._selected_transcript = transcript
        self._update_details_view(transcript)

    def _update_details_view(self, transcript: Transcript) -> None:
        """Update the details view with transcript information.

        Args:
            transcript: The transcript to display
        """
        # Update header with timestamp
        timestamp_str = transcript.timestamp.strftime("%Y-%m-%d at %I:%M:%S %p")
        self._details_header.setText(timestamp_str)

        # Update metadata
        metadata_parts = []

        # Duration
        duration_minutes = int(transcript.duration // 60)
        duration_seconds = int(transcript.duration % 60)
        if duration_minutes > 0:
            duration_str = f"{duration_minutes}m {duration_seconds}s"
        else:
            duration_str = f"{duration_seconds}s"
        metadata_parts.append(f"<b>Duration:</b> {duration_str}")

        # Source app
        if transcript.source_app_name:
            metadata_parts.append(
                f"<b>Source:</b> {transcript.source_app_name}"
            )

        # Audio file
        if transcript.audio_path.exists():
            metadata_parts.append(f"<b>Audio:</b> Available")
        else:
            metadata_parts.append(f"<b>Audio:</b> Not found")

        # Character count
        char_count = len(transcript.text)
        word_count = len(transcript.text.split())
        metadata_parts.append(
            f"<b>Length:</b> {word_count} words, {char_count} characters"
        )

        self._metadata_label.setText(" | ".join(metadata_parts))

        # Update text
        self._text_edit.setPlainText(transcript.text)

        # Enable buttons
        self._copy_button.setEnabled(True)
        self._delete_button.setEnabled(True)

    @Slot()
    def _copy_to_clipboard(self) -> None:
        """Copy the selected transcript text to clipboard."""
        if self._selected_transcript is None:
            return

        transcript = self._selected_transcript
        text = transcript.text

        try:
            # Copy to clipboard using PySide6
            from PySide6.QtGui import QClipboard

            clipboard = QApplication.clipboard()
            clipboard.setText(text)

            # Show confirmation
            self._status_label.setText("Copied to clipboard!")
            logger.info(f"Copied transcript {transcript.id} to clipboard")

            # Clear status after 3 seconds
            QTimer.singleShot(3000, lambda: self._status_label.setText(""))

        except Exception as e:
            logger.error(f"Error copying to clipboard: {e}")
            QMessageBox.critical(
                self, "Copy Failed", f"Failed to copy to clipboard: {e}"
            )

    @Slot()
    def _delete_selected(self) -> None:
        """Delete the selected transcript."""
        if self._selected_transcript is None:
            return

        transcript = self._selected_transcript

        # Confirm deletion
        reply = QMessageBox.question(
            self,
            "Delete Transcription",
            f"Are you sure you want to delete this transcription?\n\n"
            f'"{transcript.text[:100]}{"..." if len(transcript.text) > 100 else ""}"',
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )

        if reply == QMessageBox.No:
            return

        try:
            # Delete audio file
            import asyncio

            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            try:
                loop.run_until_complete(
                    self._persistence_client.delete_audio(transcript)
                )
            except FileNotFoundError:
                logger.warning(
                    f"Audio file not found for transcript {transcript.id}, skipping deletion"
                )

            loop.close()

            # Remove from local list
            self._transcripts.remove(transcript)

            # Save updated history
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            loop.run_until_complete(
                self._persistence_client.save_history(self._transcripts)
            )
            loop.close()

            # Refresh UI
            self._load_history()

            # Emit signal
            self.history_modified.emit()

            logger.info(f"Deleted transcript {transcript.id}")

        except Exception as e:
            logger.error(f"Error deleting transcript: {e}")
            QMessageBox.critical(
                self, "Delete Failed", f"Failed to delete transcription: {e}"
            )

    @Slot()
    def _clear_all_history(self) -> None:
        """Clear all transcription history after confirmation."""
        if not self._transcripts:
            QMessageBox.information(
                self, "Clear History", "No history to clear."
            )
            return

        # Confirm deletion
        reply = QMessageBox.question(
            self,
            "Clear All History",
            f"Are you sure you want to delete all {len(self._transcripts)} transcriptions?\n\n"
            "This action cannot be undone.",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )

        if reply == QMessageBox.No:
            return

        try:
            import asyncio

            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            # Delete all audio files
            for transcript in self._transcripts:
                try:
                    loop.run_until_complete(
                        self._persistence_client.delete_audio(transcript)
                    )
                except FileNotFoundError:
                    logger.warning(
                        f"Audio file not found for transcript {transcript.id}, skipping"
                    )

            loop.close()

            # Clear list and save empty history
            self._transcripts = []
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            loop.run_until_complete(
                self._persistence_client.save_history(self._transcripts)
            )
            loop.close()

            # Refresh UI
            self._load_history()

            # Emit signal
            self.history_modified.emit()

            logger.info("Cleared all transcription history")

        except Exception as e:
            logger.error(f"Error clearing history: {e}")
            QMessageBox.critical(
                self, "Clear Failed", f"Failed to clear history: {e}"
            )
