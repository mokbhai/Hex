"""Settings dialog for Hex voice-to-text application.

This module provides the Settings UI with controls for hotkey, model selection,
language, and other user preferences. It mirrors the structure from
Hex/Features/Settings/SettingsView.swift adapted for PySide6.
"""

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Dict, Any
import json
from pathlib import Path

from PySide6.QtWidgets import (
    QDialog,
    QVBoxLayout,
    QHBoxLayout,
    QFormLayout,
    QGroupBox,
    QLabel,
    QPushButton,
    QComboBox,
    QCheckBox,
    QSlider,
    QSpinBox,
    QDoubleSpinBox,
    QScrollArea,
    QWidget,
    QDialogButtonBox,
    QMessageBox,
)
from PySide6.QtCore import Qt, Signal, Slot
from PySide6.QtGui import QKeyEvent, QKeySequence

from hex.models.settings import HexSettings, RecordingAudioBehavior
from hex.models.hotkey import HotKey, Modifier, Modifiers, Key
from hex.utils.logging import get_logger

logger = get_logger("gui.settings_dialog")


# Language data model
@dataclass
class Language:
    """Represents a language option for transcription.

    Attributes:
        code: ISO language code (e.g., "en", "es")
        name: Display name of the language
    """

    code: Optional[str] = None
    name: str = ""

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Language":
        """Create Language from dictionary."""
        return cls(code=data.get("code"), name=data.get("name", ""))


# Model data model
@dataclass
class ModelInfo:
    """Information about a transcription model.

    Attributes:
        display_name: Human-readable model name
        internal_name: Internal model identifier
        size: Model size category (e.g., "Multilingual", "English")
        accuracy_stars: Accuracy rating (1-5 stars)
        speed_stars: Speed rating (1-5 stars)
        storage_size: Disk space required
    """

    display_name: str
    internal_name: str
    size: str
    accuracy_stars: int
    speed_stars: int
    storage_size: str

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ModelInfo":
        """Create ModelInfo from dictionary."""
        return cls(
            display_name=data.get("displayName", ""),
            internal_name=data.get("internalName", ""),
            size=data.get("size", ""),
            accuracy_stars=data.get("accuracyStars", 0),
            speed_stars=data.get("speedStars", 0),
            storage_size=data.get("storageSize", ""),
        )


class HotKeyDisplayWidget(QWidget):
    """Widget for displaying and editing a hotkey combination.

    Shows the current hotkey with visual feedback. Can be clicked to
    start recording a new hotkey.
    """

    hotkey_changed = Signal(HotKey)

    def __init__(self, hotkey: HotKey, parent: Optional[QWidget] = None) -> None:
        """Initialize hotkey display widget.

        Args:
            hotkey: Initial hotkey to display
            parent: Parent widget
        """
        super().__init__(parent)
        self._hotkey = hotkey
        self._is_recording = False

        self._setup_ui()

    def _setup_ui(self) -> None:
        """Set up the UI components."""
        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)

        self._label = QLabel(self._get_hotkey_text())
        self._label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._label.setStyleSheet(
            """
            QLabel {
                border: 2px solid #d0d0d0;
                border-radius: 6px;
                padding: 8px 16px;
                background-color: #f5f5f5;
                font-size: 14px;
                font-weight: bold;
                min-width: 150px;
            }
            QLabel:hover {
                background-color: #e8e8e8;
                border-color: #b0b0b0;
            }
        """
        )

        layout.addWidget(self._label)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

    def _get_hotkey_text(self) -> str:
        """Get display text for current hotkey."""
        if self._is_recording:
            return "Press keys..."

        modifiers = sorted(self._hotkey.modifiers.modifiers, key=lambda m: m.kind.order)
        modifier_symbols = "".join(m.kind.symbol for m in modifiers)
        key_text = self._hotkey.key.to_string() if self._hotkey.key else ""
        return modifier_symbols + key_text or "Click to set"

    def set_hotkey(self, hotkey: HotKey) -> None:
        """Update the displayed hotkey.

        Args:
            hotkey: New hotkey to display
        """
        self._hotkey = hotkey
        self._label.setText(self._get_hotkey_text())

    def set_recording(self, recording: bool) -> None:
        """Set recording state for visual feedback.

        Args:
            recording: True if recording new hotkey
        """
        self._is_recording = recording
        self._label.setText(self._get_hotkey_text())

        if recording:
            self._label.setStyleSheet(
                """
                QLabel {
                    border: 2px solid #007AFF;
                    border-radius: 6px;
                    padding: 8px 16px;
                    background-color: #E5F1FF;
                    color: #007AFF;
                    font-size: 14px;
                    font-weight: bold;
                    min-width: 150px;
                }
            """
            )
        else:
            self._label.setStyleSheet(
                """
                QLabel {
                    border: 2px solid #d0d0d0;
                    border-radius: 6px;
                    padding: 8px 16px;
                    background-color: #f5f5f5;
                    font-size: 14px;
                    font-weight: bold;
                    min-width: 150px;
                }
                QLabel:hover {
                    background-color: #e8e8e8;
                    border-color: #b0b0b0;
                }
            """
            )


class SettingsDialog(QDialog):
    """Main settings dialog for Hex application.

    Provides a tabbed or grouped interface for configuring:
    - Hotkey settings
    - Transcription model selection
    - Language selection
    - General preferences
    - Sound effects
    """

    settings_changed = Signal(HexSettings)

    def __init__(self, settings: HexSettings, parent: Optional[QWidget] = None) -> None:
        """Initialize the settings dialog.

        Args:
            settings: Current application settings
            parent: Parent widget
        """
        super().__init__(parent)
        self._settings = settings
        self._edited_settings: Optional[HexSettings] = None

        # Load data files
        self._languages = self._load_languages()
        self._models = self._load_models()

        # Recording state for hotkey
        self._is_recording_hotkey = False
        self._current_modifiers: List[Modifier] = []

        self._setup_ui()
        self._load_settings_to_ui()

        logger.info("Settings dialog initialized")

    def _load_languages(self) -> List[Language]:
        """Load languages from JSON file.

        Returns:
            List of available languages
        """
        languages_path = Path(__file__).parent.parent / "resources" / "data" / "languages.json"

        if languages_path.exists():
            try:
                with open(languages_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return [Language.from_dict(item) for item in data]
            except Exception as e:
                logger.error(f"Failed to load languages: {e}")
                return [Language(code=None, name="Auto")]
        else:
            logger.warning(f"Languages file not found at {languages_path}")
            return [Language(code=None, name="Auto")]

    def _load_models(self) -> List[ModelInfo]:
        """Load model information from JSON file.

        Returns:
            List of available models
        """
        models_path = Path(__file__).parent.parent / "resources" / "data" / "models.json"

        if models_path.exists():
            try:
                with open(models_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return [ModelInfo.from_dict(item) for item in data]
            except Exception as e:
                logger.error(f"Failed to load models: {e}")
                return []
        else:
            logger.warning(f"Models file not found at {models_path}")
            return []

    def _setup_ui(self) -> None:
        """Set up the UI components."""
        self.setWindowTitle("Hex Settings")
        self.setMinimumSize(600, 500)

        layout = QVBoxLayout(self)

        # Create scroll area for settings
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        # Container widget for all settings
        container = QWidget()
        container_layout = QVBoxLayout(container)
        container_layout.setSpacing(16)
        container_layout.setContentsMargins(16, 16, 16, 16)

        # Add settings sections
        self._create_hotkey_section(container_layout)
        self._create_model_section(container_layout)
        self._create_language_section(container_layout)
        self._create_general_section(container_layout)
        self._create_sound_section(container_layout)

        container_layout.addStretch()

        scroll.setWidget(container)
        layout.addWidget(scroll)

        # Dialog buttons
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel | QDialogButtonBox.StandardButton.Apply
        )
        buttons.accepted.connect(self._on_ok_clicked)
        buttons.rejected.connect(self._on_cancel_clicked)
        buttons.button(QDialogButtonBox.StandardButton.Apply).clicked.connect(self._on_apply_clicked)

        layout.addWidget(buttons)

    def _create_hotkey_section(self, parent_layout: QVBoxLayout) -> None:
        """Create the hotkey settings section.

        Args:
            parent_layout: Layout to add section to
        """
        group = QGroupBox("Hot Key")
        group_layout = QVBoxLayout()

        # Hotkey display
        hotkey_layout = QHBoxLayout()
        hotkey_layout.addWidget(QLabel("Recording Hotkey:"))
        hotkey_layout.addStretch()

        self._hotkey_display = HotKeyDisplayWidget(self._settings.hotkey)
        self._hotkey_display.setMouseTracking(True)
        self._hotkey_display.mousePressEvent = self._on_hotkey_display_clicked  # type: ignore
        hotkey_layout.addWidget(self._hotkey_display)

        group_layout.addLayout(hotkey_layout)

        # Double-tap toggle (for key+modifier combinations)
        self._double_tap_checkbox = QCheckBox("Use double-tap only")
        self._double_tap_checkbox.setToolTip(
            "When enabled, quickly press the hotkey twice to start/stop recording. "
            "When disabled, hold the hotkey to record."
        )
        group_layout.addWidget(self._double_tap_checkbox)

        # Minimum key time slider (for modifier-only shortcuts)
        self._min_key_time_widget = QWidget()
        min_key_time_layout = QVBoxLayout(self._min_key_time_widget)
        min_key_time_layout.setContentsMargins(0, 0, 0, 0)

        min_key_time_label_layout = QHBoxLayout()
        min_key_time_label_layout.addWidget(QLabel("Ignore below:"))
        self._min_key_time_label = QLabel(f"{self._settings.minimumKeyTime:.1f}s")
        self._min_key_time_label.setStyleSheet("color: #666; font-weight: bold;")
        min_key_time_label_layout.addWidget(self._min_key_time_label)
        min_key_time_label_layout.addStretch()

        min_key_time_layout.addLayout(min_key_time_label_layout)

        self._min_key_time_slider = QSlider(Qt.Orientation.Horizontal)
        self._min_key_time_slider.setRange(0, 20)  # 0.0 to 2.0 seconds
        self._min_key_time_slider.setValue(int(self._settings.minimumKeyTime * 10))
        self._min_key_time_slider.valueChanged.connect(self._on_min_key_time_changed)
        min_key_time_layout.addWidget(self._min_key_time_slider)

        group_layout.addWidget(self._min_key_time_widget)

        # Description label
        help_label = QLabel("Click the hotkey display above, then press your desired key combination.")
        help_label.setWordWrap(True)
        help_label.setStyleSheet("color: #666; font-size: 11px;")
        group_layout.addWidget(help_label)

        group.setLayout(group_layout)
        parent_layout.addWidget(group)

        # Initially hide/show based on hotkey type
        self._update_hotkey_controls()

    def _create_model_section(self, parent_layout: QVBoxLayout) -> None:
        """Create the model selection section.

        Args:
            parent_layout: Layout to add section to
        """
        group = QGroupBox("Transcription Model")
        group_layout = QFormLayout()

        self._model_combo = QComboBox()
        for model in self._models:
            display_text = f"{model.display_name} ({model.storage_size})"
            self._model_combo.addItem(display_text, model.internal_name)

        group_layout.addRow("Model:", self._model_combo)

        # Model info label
        self._model_info_label = QLabel()
        self._model_info_label.setWordWrap(True)
        self._model_info_label.setStyleSheet("color: #666; font-size: 11px;")
        group_layout.addRow("", self._model_info_label)

        group.setLayout(group_layout)
        parent_layout.addWidget(group)

        # Connect signal to update language visibility
        self._model_combo.currentIndexChanged.connect(self._on_model_changed)

    def _create_language_section(self, parent_layout: QVBoxLayout) -> None:
        """Create the language selection section.

        Only shown for Whisper models (not Parakeet).

        Args:
            parent_layout: Layout to add section to
        """
        self._language_group = QGroupBox("Output Language")
        group_layout = QVBoxLayout()

        self._language_combo = QComboBox()
        for language in self._languages:
            display_text = language.name
            if language.code:
                display_text += f" ({language.code})"
            self._language_combo.addItem(display_text, language.code)

        group_layout.addWidget(self._language_combo)

        help_label = QLabel("Select the language for transcription. Choose 'Auto' for automatic detection.")
        help_label.setWordWrap(True)
        help_label.setStyleSheet("color: #666; font-size: 11px;")
        group_layout.addWidget(help_label)

        self._language_group.setLayout(group_layout)
        parent_layout.addWidget(self._language_group)

        # Initially hide/show based on model
        self._update_language_visibility()

    def _create_general_section(self, parent_layout: QVBoxLayout) -> None:
        """Create the general settings section.

        Args:
            parent_layout: Layout to add section to
        """
        group = QGroupBox("General")
        group_layout = QVBoxLayout()

        # Open on login
        self._open_on_login_checkbox = QCheckBox("Open on Login")
        group_layout.addWidget(self._open_on_login_checkbox)

        # Show dock icon (macOS)
        self._show_dock_icon_checkbox = QCheckBox("Show Dock Icon")
        group_layout.addWidget(self._show_dock_icon_checkbox)

        # Use clipboard to insert
        self._use_clipboard_paste_checkbox = QCheckBox("Use clipboard to insert")
        self._use_clipboard_paste_checkbox.setToolTip(
            "Use clipboard to insert text. Fast but may not restore all clipboard content.\n"
            "Turn off to use simulated keypresses. Slower, but doesn't need to restore clipboard."
        )
        group_layout.addWidget(self._use_clipboard_paste_checkbox)

        # Copy to clipboard
        self._copy_to_clipboard_checkbox = QCheckBox("Copy to clipboard")
        self._copy_to_clipboard_checkbox.setToolTip("Copy transcription text to clipboard in addition to pasting it")
        group_layout.addWidget(self._copy_to_clipboard_checkbox)

        # Prevent system sleep
        self._prevent_sleep_checkbox = QCheckBox("Prevent System Sleep while Recording")
        group_layout.addWidget(self._prevent_sleep_checkbox)

        # Recording audio behavior
        audio_behavior_layout = QHBoxLayout()
        audio_behavior_layout.addWidget(QLabel("Audio Behavior while Recording:"))
        self._audio_behavior_combo = QComboBox()
        self._audio_behavior_combo.addItem("Pause Media", RecordingAudioBehavior.PAUSE_MEDIA)
        self._audio_behavior_combo.addItem("Mute Volume", RecordingAudioBehavior.MUTE)
        self._audio_behavior_combo.addItem("Do Nothing", RecordingAudioBehavior.DO_NOTHING)
        audio_behavior_layout.addWidget(self._audio_behavior_combo)
        audio_behavior_layout.addStretch()

        group_layout.addLayout(audio_behavior_layout)

        group.setLayout(group_layout)
        parent_layout.addWidget(group)

    def _create_sound_section(self, parent_layout: QVBoxLayout) -> None:
        """Create the sound effects section.

        Args:
            parent_layout: Layout to add section to
        """
        group = QGroupBox("Sound")
        group_layout = QVBoxLayout()

        # Sound effects toggle
        self._sound_effects_checkbox = QCheckBox("Sound Effects")
        group_layout.addWidget(self._sound_effects_checkbox)

        # Volume slider
        volume_layout = QVBoxLayout()
        volume_label_layout = QHBoxLayout()
        volume_label_layout.addWidget(QLabel("Volume:"))
        self._volume_label = QLabel("20%")
        self._volume_label.setStyleSheet("color: #666; font-weight: bold;")
        volume_label_layout.addWidget(self._volume_label)
        volume_label_layout.addStretch()

        volume_layout.addLayout(volume_label_layout)

        self._volume_slider = QSlider(Qt.Orientation.Horizontal)
        self._volume_slider.setRange(0, 100)
        self._volume_slider.setValue(20)  # Default 20%
        self._volume_slider.valueChanged.connect(self._on_volume_changed)
        volume_layout.addWidget(self._volume_slider)

        group_layout.addLayout(volume_layout)

        group.setLayout(group_layout)
        parent_layout.addWidget(group)

    def _load_settings_to_ui(self) -> None:
        """Load settings values into UI controls."""
        # Hotkey
        self._hotkey_display.set_hotkey(self._settings.hotkey)
        self._double_tap_checkbox.setChecked(self._settings.useDoubleTapOnly)

        # Minimum key time
        self._min_key_time_slider.setValue(int(self._settings.minimumKeyTime * 10))
        self._min_key_time_label.setText(f"{self._settings.minimumKeyTime:.1f}s")

        # Model
        model_index = self._model_combo.findData(self._settings.selectedModel)
        if model_index >= 0:
            self._model_combo.setCurrentIndex(model_index)

        # Language
        if self._settings.outputLanguage:
            lang_index = self._language_combo.findData(self._settings.outputLanguage)
            if lang_index >= 0:
                self._language_combo.setCurrentIndex(lang_index)

        # General
        self._open_on_login_checkbox.setChecked(self._settings.openOnLogin)
        self._show_dock_icon_checkbox.setChecked(self._settings.showDockIcon)
        self._use_clipboard_paste_checkbox.setChecked(self._settings.useClipboardPaste)
        self._copy_to_clipboard_checkbox.setChecked(self._settings.copyToClipboard)
        self._prevent_sleep_checkbox.setChecked(self._settings.preventSystemSleep)

        behavior_index = self._audio_behavior_combo.findData(self._settings.recordingAudioBehavior)
        if behavior_index >= 0:
            self._audio_behavior_combo.setCurrentIndex(behavior_index)

        # Sound
        self._sound_effects_checkbox.setChecked(self._settings.soundEffectsEnabled)
        # Convert actual volume to percentage
        volume_percent = int((self._settings.soundEffectsVolume / 0.2) * 100)
        volume_percent = max(0, min(100, volume_percent))
        self._volume_slider.setValue(volume_percent)
        self._volume_label.setText(f"{volume_percent}%")

        # Update visibility
        self._update_hotkey_controls()
        self._update_language_visibility()
        self._update_model_info()

    def _update_hotkey_controls(self) -> None:
        """Update visibility of hotkey-related controls based on hotkey type."""
        is_modifier_only = self._settings.hotkey.key is None

        # Show double-tap checkbox only for key+modifier combos
        self._double_tap_checkbox.setVisible(not is_modifier_only)

        # Show minimum key time slider only for modifier-only hotkeys
        self._min_key_time_widget.setVisible(is_modifier_only)

    def _update_language_visibility(self) -> None:
        """Update language section visibility based on selected model."""
        current_model = self._model_combo.currentData()
        is_parakeet = current_model and current_model.startswith("parakeet-")

        # Hide language section for Parakeet models
        self._language_group.setVisible(not is_parakeet)

    def _update_model_info(self) -> None:
        """Update model information label."""
        current_model = self._model_combo.currentData()
        model_info = next((m for m in self._models if m.internal_name == current_model), None)

        if model_info:
            accuracy_stars = "⭐" * model_info.accuracy_stars
            speed_stars = "⚡" * model_info.speed_stars
            info_text = f"Size: {model_info.size} | Storage: {model_info.storage_size} | Accuracy: {accuracy_stars} | Speed: {speed_stars}"
            self._model_info_label.setText(info_text)

    def _on_hotkey_display_clicked(self, event) -> None:  # type: ignore
        """Handle hotkey display click to start recording.

        Args:
            event: Mouse event
        """
        if not self._is_recording_hotkey:
            self._start_recording_hotkey()

    def _start_recording_hotkey(self) -> None:
        """Start recording a new hotkey combination."""
        self._is_recording_hotkey = True
        self._current_modifiers = []
        self._hotkey_display.set_recording(True)
        self._hotkey_display.setFocus()

        # Install event filter to capture key presses
        self.grabKeyboard()

        logger.info("Started recording hotkey")

    def _stop_recording_hotkey(self) -> None:
        """Stop recording and save the hotkey."""
        self._is_recording_hotkey = False
        self._hotkey_display.set_recording(False)
        self.releaseKeyboard()

        logger.info("Stopped recording hotkey")

    def keyPressEvent(self, event: QKeyEvent) -> None:
        """Handle key press events during hotkey recording.

        Args:
            event: Key event
        """
        if not self._is_recording_hotkey:
            super().keyPressEvent(event)
            return

        # Map Qt keys to our Modifier enum
        modifier_map = {
            Qt.Key.Key_Control: Modifier.CONTROL,
            Qt.Key.Key_Alt: Modifier.OPTION,
            Qt.Key.Key_Shift: Modifier.SHIFT,
            Qt.Key.Key_Meta: Modifier.COMMAND,  # Command on macOS
        }

        key = event.key()
        modifiers = event.modifiers()

        # Check for modifier keys
        if key in modifier_map:
            modifier = modifier_map[key]
            if modifier not in self._current_modifiers:
                self._current_modifiers.append(modifier)
                logger.debug(f"Added modifier: {modifier}")
        elif key != Qt.Key.Key_unknown:
            # Non-modifier key pressed - complete the hotkey
            self._stop_recording_hotkey()

            # Create the hotkey
            modifiers_list = self._current_modifiers if self._current_modifiers else []
            new_hotkey = HotKey(key=Key.from_qt_key(key), modifiers=Modifiers.from_list(modifiers_list))

            # Update display
            self._hotkey_display.set_hotkey(new_hotkey)

            # Update visibility of controls
            self._update_hotkey_controls()

            logger.info(f"Recorded hotkey: {new_hotkey}")

    def keyReleaseEvent(self, event: QKeyEvent) -> None:
        """Handle key release events during hotkey recording.

        Args:
            event: Key event
        """
        if not self._is_recording_hotkey:
            super().keyReleaseEvent(event)
            return

        # Map Qt keys to our Modifier enum
        modifier_map = {
            Qt.Key.Key_Control: Modifier.CONTROL,
            Qt.Key.Key_Alt: Modifier.OPTION,
            Qt.Key.Key_Shift: Modifier.SHIFT,
            Qt.Key.Key_Meta: Modifier.COMMAND,
        }

        key = event.key()

        # Remove modifier from list when released
        if key in modifier_map:
            modifier = modifier_map[key]
            if modifier in self._current_modifiers:
                self._current_modifiers.remove(modifier)
                logger.debug(f"Removed modifier: {modifier}")

        # If all modifiers released and no key pressed, cancel recording
        if not self._current_modifiers:
            self._stop_recording_hotkey()

    def _on_min_key_time_changed(self, value: int) -> None:
        """Handle minimum key time slider change.

        Args:
            value: Slider value (0-20, representing 0.0-2.0 seconds)
        """
        time_seconds = value / 10.0
        self._min_key_time_label.setText(f"{time_seconds:.1f}s")

    def _on_model_changed(self, index: int) -> None:
        """Handle model selection change.

        Args:
            index: New model index
        """
        self._update_language_visibility()
        self._update_model_info()

    def _on_volume_changed(self, value: int) -> None:
        """Handle volume slider change.

        Args:
            value: Volume percentage (0-100)
        """
        self._volume_label.setText(f"{value}%")

    def _on_ok_clicked(self) -> None:
        """Handle OK button click - apply and close."""
        self._apply_settings()
        self.accept()

    def _on_cancel_clicked(self) -> None:
        """Handle Cancel button click - discard and close."""
        self.reject()

    def _on_apply_clicked(self) -> None:
        """Handle Apply button click - apply without closing."""
        self._apply_settings()

    def _apply_settings(self) -> None:
        """Apply current UI values to settings and emit signal."""
        # Get hotkey from display
        hotkey = self._hotkey_display._hotkey

        # Get model
        model = self._model_combo.currentData() or self._settings.selectedModel

        # Get language
        language = self._language_combo.currentData()

        # Get audio behavior
        audio_behavior = self._audio_behavior_combo.currentData() or RecordingAudioBehavior.DO_NOTHING

        # Get volume (convert percentage to actual value)
        volume_percent = self._volume_slider.value() / 100.0
        actual_volume = volume_percent * 0.2  # Base volume is 0.2

        # Create new settings object with updated values
        # Note: We use dataclasses.replace to create an immutable copy
        from dataclasses import replace

        self._edited_settings = replace(
            self._settings,
            hotkey=hotkey,
            useDoubleTapOnly=self._double_tap_checkbox.isChecked(),
            minimumKeyTime=self._min_key_time_slider.value() / 10.0,
            selectedModel=model,
            outputLanguage=language,
            openOnLogin=self._open_on_login_checkbox.isChecked(),
            showDockIcon=self._show_dock_icon_checkbox.isChecked(),
            useClipboardPaste=self._use_clipboard_paste_checkbox.isChecked(),
            copyToClipboard=self._copy_to_clipboard_checkbox.isChecked(),
            preventSystemSleep=self._prevent_sleep_checkbox.isChecked(),
            recordingAudioBehavior=audio_behavior,
            soundEffectsEnabled=self._sound_effects_checkbox.isChecked(),
            soundEffectsVolume=actual_volume,
        )

        # Emit signal
        self.settings_changed.emit(self._edited_settings)

        logger.info("Settings applied")
