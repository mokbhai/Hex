"""Settings data models for Hex.

This module provides data structures for user-configurable settings saved to disk.
It mirrors the structure from HexCore/Sources/HexCore/Settings/HexSettings.swift.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List, Any, Dict

from hex.models.hotkey import HotKey, Key, Modifier, Modifiers
from hex.models.word_processing import WordRemoval, WordRemapping


# Module-level constants
BASE_SOUND_EFFECTS_VOLUME = 0.2
DEFAULT_MINIMUM_KEY_TIME = 0.2
DEFAULT_SELECTED_MODEL = "parakeet-tdt-0.6b-v3-coreml"


def _default_hotkey() -> HotKey:
    """Create default hotkey (Option-only)."""
    return HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))


def _default_paste_hotkey() -> HotKey:
    """Create default paste last transcript hotkey (Option+Shift+V)."""
    return HotKey(key=Key.V, modifiers=Modifiers.from_list([Modifier.OPTION, Modifier.SHIFT]))


def _default_word_removals() -> List[WordRemoval]:
    """Create default word removal patterns."""
    return [
        WordRemoval(pattern="uh+"),
        WordRemoval(pattern="um+"),
        WordRemoval(pattern="er+"),
        WordRemoval(pattern="hm+"),
    ]


class RecordingAudioBehavior(Enum):
    """Behavior for audio during recording.

    Determines what happens to system audio when recording starts.
    """

    PAUSE_MEDIA = "pauseMedia"
    MUTE = "mute"
    DO_NOTHING = "doNothing"


@dataclass(frozen=True)
class HexSettings:
    """User-configurable settings saved to disk.

    This class contains all user preferences and configuration options for Hex.
    It supports serialization to/from JSON for persistence.

    Attributes:
        soundEffectsEnabled: Whether sound effects are played
        soundEffectsVolume: Volume multiplier for sound effects (0.0-1.0)
        hotkey: The primary hotkey for triggering recording
        openOnLogin: Whether to launch Hex at system login
        showDockIcon: Whether to show Hex in the dock
        selectedModel: Identifier of the selected transcription model
        useClipboardPaste: Whether to use clipboard for pasting text
        preventSystemSleep: Whether to prevent system sleep during recording
        recordingAudioBehavior: What to do with audio during recording
        minimumKeyTime: Minimum key hold time to register (seconds)
        copyToClipboard: Whether to copy transcriptions to clipboard
        useDoubleTapOnly: Whether to use double-tap mode only
        outputLanguage: Optional language code for output
        selectedMicrophoneID: Optional ID of selected microphone
        saveTranscriptionHistory: Whether to save transcription history
        maxHistoryEntries: Maximum number of history entries to keep
        pasteLastTranscriptHotkey: Hotkey for pasting last transcript
        hasCompletedModelBootstrap: Whether initial model setup is complete
        hasCompletedStorageMigration: Whether storage migration is complete
        wordRemovalsEnabled: Whether word removal is enabled
        wordRemovals: List of word removal patterns
        wordRemappings: List of word remapping rules

    Examples:
        >>> settings = HexSettings()
        >>> settings.hotkey
        HotKey(key=None, modifiers=Modifiers(modifiers=frozenset({...})))
    """

    # Settings fields
    soundEffectsEnabled: bool = True
    soundEffectsVolume: float = BASE_SOUND_EFFECTS_VOLUME
    hotkey: HotKey = field(default_factory=_default_hotkey)
    openOnLogin: bool = False
    showDockIcon: bool = True
    selectedModel: str = DEFAULT_SELECTED_MODEL
    useClipboardPaste: bool = True
    preventSystemSleep: bool = True
    recordingAudioBehavior: RecordingAudioBehavior = RecordingAudioBehavior.DO_NOTHING
    minimumKeyTime: float = DEFAULT_MINIMUM_KEY_TIME
    copyToClipboard: bool = False
    useDoubleTapOnly: bool = False
    outputLanguage: Optional[str] = None
    selectedMicrophoneID: Optional[str] = None
    saveTranscriptionHistory: bool = True
    maxHistoryEntries: Optional[int] = None
    pasteLastTranscriptHotkey: Optional[HotKey] = field(default_factory=_default_paste_hotkey)
    hasCompletedModelBootstrap: bool = False
    hasCompletedStorageMigration: bool = False
    wordRemovalsEnabled: bool = False
    wordRemovals: List[WordRemoval] = field(default_factory=_default_word_removals)
    wordRemappings: List[WordRemapping] = field(default_factory=list)

    @property
    def defaultPasteLastTranscriptHotkeyDescription(self) -> str:
        """Get a description of the default paste last transcript hotkey."""
        hotkey = _default_paste_hotkey()
        modifiers = sorted(hotkey.modifiers.modifiers, key=lambda m: m.kind.order)
        modifier_str = "".join(m.kind.symbol for m in modifiers)
        key_str = hotkey.key.to_string() if hotkey.key else ""
        return modifier_str + key_str

    def to_dict(self) -> Dict[str, Any]:
        """Convert settings to dictionary for JSON serialization.

        Handles optional fields and converts enums to strings.

        Returns:
            Dictionary representation of settings
        """
        return {
            "soundEffectsEnabled": self.soundEffectsEnabled,
            "soundEffectsVolume": self.soundEffectsVolume,
            "hotkey": self.hotkey.to_dict(),
            "openOnLogin": self.openOnLogin,
            "showDockIcon": self.showDockIcon,
            "selectedModel": self.selectedModel,
            "useClipboardPaste": self.useClipboardPaste,
            "preventSystemSleep": self.preventSystemSleep,
            "recordingAudioBehavior": self.recordingAudioBehavior.value,
            "minimumKeyTime": self.minimumKeyTime,
            "copyToClipboard": self.copyToClipboard,
            "useDoubleTapOnly": self.useDoubleTapOnly,
            "outputLanguage": self.outputLanguage,
            "selectedMicrophoneID": self.selectedMicrophoneID,
            "saveTranscriptionHistory": self.saveTranscriptionHistory,
            "maxHistoryEntries": self.maxHistoryEntries,
            "pasteLastTranscriptHotkey": (
                self.pasteLastTranscriptHotkey.to_dict() if self.pasteLastTranscriptHotkey else None
            ),
            "hasCompletedModelBootstrap": self.hasCompletedModelBootstrap,
            "hasCompletedStorageMigration": self.hasCompletedStorageMigration,
            "wordRemovalsEnabled": self.wordRemovalsEnabled,
            "wordRemovals": [wr.to_dict() for wr in self.wordRemovals],
            "wordRemappings": [wr.to_dict() for wr in self.wordRemappings],
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "HexSettings":
        """Create settings from dictionary for JSON deserialization.

        Handles optional fields and converts strings to enums.
        Supports legacy field names for backward compatibility.

        Args:
            data: Dictionary containing settings data

        Returns:
            HexSettings instance

        Raises:
            ValueError: If required fields are missing or invalid
        """
        # Handle hotkey
        hotkey_data = data.get("hotkey", {})
        if not hotkey_data:
            hotkey = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
        else:
            hotkey = HotKey.from_dict(hotkey_data)

        # Handle recording audio behavior with legacy support
        behavior_value = data.get("recordingAudioBehavior", "doNothing")
        # Check for legacy pauseMediaOnRecord field
        if "pauseMediaOnRecord" in data and "recordingAudioBehavior" not in data:
            if data["pauseMediaOnRecord"]:
                behavior_value = "pauseMedia"
            else:
                behavior_value = "doNothing"
        recording_audio_behavior = RecordingAudioBehavior(behavior_value)

        # Handle paste last transcript hotkey
        paste_hotkey = None
        if "pasteLastTranscriptHotkey" in data and data["pasteLastTranscriptHotkey"]:
            paste_hotkey = HotKey.from_dict(data["pasteLastTranscriptHotkey"])

        # Handle word removals
        word_removals_data = data.get("wordRemovals", [])
        if not word_removals_data:
            word_removals = _default_word_removals()
        else:
            word_removals = [WordRemoval.from_dict(wr) for wr in word_removals_data]

        # Handle word remappings
        word_remappings_data = data.get("wordRemappings", [])
        word_remappings = [WordRemapping.from_dict(wr) for wr in word_remappings_data]

        return cls(
            soundEffectsEnabled=data.get("soundEffectsEnabled", True),
            soundEffectsVolume=data.get("soundEffectsVolume", BASE_SOUND_EFFECTS_VOLUME),
            hotkey=hotkey,
            openOnLogin=data.get("openOnLogin", False),
            showDockIcon=data.get("showDockIcon", True),
            selectedModel=data.get("selectedModel", DEFAULT_SELECTED_MODEL),
            useClipboardPaste=data.get("useClipboardPaste", True),
            preventSystemSleep=data.get("preventSystemSleep", True),
            recordingAudioBehavior=recording_audio_behavior,
            minimumKeyTime=data.get("minimumKeyTime", DEFAULT_MINIMUM_KEY_TIME),
            copyToClipboard=data.get("copyToClipboard", False),
            useDoubleTapOnly=data.get("useDoubleTapOnly", False),
            outputLanguage=data.get("outputLanguage"),
            selectedMicrophoneID=data.get("selectedMicrophoneID"),
            saveTranscriptionHistory=data.get("saveTranscriptionHistory", True),
            maxHistoryEntries=data.get("maxHistoryEntries"),
            pasteLastTranscriptHotkey=paste_hotkey,
            hasCompletedModelBootstrap=data.get("hasCompletedModelBootstrap", False),
            hasCompletedStorageMigration=data.get("hasCompletedStorageMigration", False),
            wordRemovalsEnabled=data.get("wordRemovalsEnabled", False),
            wordRemovals=word_removals,
            wordRemappings=word_remappings,
        )
