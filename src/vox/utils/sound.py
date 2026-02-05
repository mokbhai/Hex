"""Sound effect player with platform-specific audio playback.

This module provides cross-platform sound effect functionality to mirror the Swift
implementation in Hex/Clients/SoundEffect.swift.

The player handles:
- Playing sound effects for transcription actions (paste, start, stop, cancel)
- Preloading sounds into memory for instant playback
- Volume control with clamping to baseline
- Enable/disable toggle for sound effects
- Thread-safe playback using Qt's sound system

Uses PySide6 QSoundEffect for cross-platform audio playback without additional
dependencies beyond what's already required for the GUI.
"""

import asyncio
from enum import Enum, auto
from pathlib import Path
from threading import Lock

from PySide6.QtCore import QUrl
from PySide6.QtMultimedia import QSoundEffect

from vox.utils.logging import get_logger, LogCategory


# Module logger
sound_logger = get_logger(LogCategory.SOUND)


class SoundEffect(Enum):
    """Sound effect types.

    Matches SoundEffect enum from Swift implementation in Hex/Clients/SoundEffect.swift.

    Available sounds:
    - PASTE_TRANSCRIPT: Played when transcript is pasted to clipboard
    - START_RECORDING: Played when recording starts
    - STOP_RECORDING: Played when recording stops
    - CANCEL: Played when recording is cancelled
    """

    PASTE_TRANSCRIPT = auto()
    START_RECORDING = auto()
    STOP_RECORDING = auto()
    CANCEL = auto()

    @property
    def file_name(self) -> str:
        """Get the file name for this sound effect.

        Returns:
            The file name without extension (e.g., 'pasteTranscript')
        """
        # Map Python enum names to Swift file names
        name_mapping = {
            "PASTE_TRANSCRIPT": "pasteTranscript",
            "START_RECORDING": "startRecording",
            "STOP_RECORDING": "stopRecording",
            "CANCEL": "cancel",
        }
        return name_mapping.get(self.name, self.name.lower())

    @property
    def file_extension(self) -> str:
        """Get the file extension for sound effects.

        Returns:
            The file extension ('mp3')
        """
        return "mp3"


class SoundEffectPlayer:
    """Player for sound effects with Qt-based audio playback.

    This class provides sound effect functionality with:
    - Async play/stop/stopAll methods matching Swift API
    - Volume control with baseline clamping
    - Enable/disable toggle
    - Sound preloading for instant playback
    - Thread-safe operations

    Attributes:
        enabled: Whether sound effects are enabled (default: True)
        volume: Volume level 0.0 to 1.0 (default: 0.5)
        baseline_volume: Maximum volume level (default: 1.0)

    Example:
        >>> player = SoundEffectPlayer()
        >>> await player.preload_sounds()
        >>> await player.play(SoundEffect.START_RECORDING)
    """

    def __init__(
        self,
        enabled: bool = True,
        volume: float = 0.5,
        baseline_volume: float = 1.0,
        sounds_dir: Path | None = None,
    ) -> None:
        """Initialize the SoundEffectPlayer.

        Args:
            enabled: Whether sound effects are enabled
            volume: Volume level (0.0 to 1.0)
            baseline_volume: Maximum volume level for clamping
            sounds_dir: Directory containing sound files (default: Resources/Audio/)
        """
        self.enabled = enabled
        self.volume = volume
        self.baseline_volume = baseline_volume
        self._sounds_dir = sounds_dir or Path(__file__).parent.parent / "resources" / "audio"
        self._effects: dict[SoundEffect, QSoundEffect] = {}
        self._lock = Lock()
        self._is_setup = False

    def _get_sound_path(self, sound_effect: SoundEffect) -> Path:
        """Get the full path to a sound effect file.

        Args:
            sound_effect: The sound effect to get the path for

        Returns:
            Path to the sound file
        """
        return self._sounds_dir / f"{sound_effect.file_name}.{sound_effect.file_extension}"

    def _create_sound_effect(self, sound_effect: SoundEffect) -> QSoundEffect | None:
        """Create a QSoundEffect for the given sound.

        Args:
            sound_effect: The sound effect to create

        Returns:
            QSoundEffect instance or None if file not found
        """
        sound_path = self._get_sound_path(sound_effect)

        if not sound_path.exists():
            sound_logger.error(
                f"Missing sound resource: {sound_effect.file_name}.{sound_effect.file_extension}"
            )
            return None

        try:
            effect = QSoundEffect()
            effect.setSource(QUrl.fromLocalFile(str(sound_path)))
            effect.setVolume(self._get_clamped_volume())

            # Connect loop count changed signal to detect when sound finishes
            # QSoundEffect plays once by default (loopCount = 1)
            return effect
        except Exception as e:
            sound_logger.error(f"Failed to create sound effect {sound_effect.file_name}: {e}")
            return None

    def _get_clamped_volume(self) -> float:
        """Get volume clamped to [0, baseline_volume].

        Returns:
            Clamped volume value
        """
        return max(0.0, min(self.volume, self.baseline_volume))

    async def play(self, sound_effect: SoundEffect) -> None:
        """Play a sound effect.

        This method is thread-safe and can be called from any thread.
        If sounds are disabled or the sound is not loaded, returns silently.

        Args:
            sound_effect: The sound effect to play

        Example:
            >>> await player.play(SoundEffect.START_RECORDING)
        """
        if not self.enabled:
            return

        with self._lock:
            effect = self._effects.get(sound_effect)

            if effect is None:
                sound_logger.error(f"Requested sound {sound_effect.file_name} not preloaded")
                return

            # Stop any currently playing instance and restart
            effect.stop()
            effect.setVolume(self._get_clamped_volume())
            effect.play()

            sound_logger.debug(f"Playing sound effect: {sound_effect.file_name}")

    async def stop(self, sound_effect: SoundEffect) -> None:
        """Stop a specific sound effect.

        Args:
            sound_effect: The sound effect to stop

        Example:
            >>> await player.stop(SoundEffect.START_RECORDING)
        """
        with self._lock:
            effect = self._effects.get(sound_effect)
            if effect is not None:
                effect.stop()

    async def stop_all(self) -> None:
        """Stop all currently playing sound effects.

        Example:
            >>> await player.stop_all()
        """
        with self._lock:
            for effect in self._effects.values():
                effect.stop()

    async def preload_sounds(self) -> None:
        """Preload all sound effects for instant playback.

        This should be called once at application startup to ensure sounds
        are loaded and ready to play. Can be called multiple times safely.

        Loads all sounds defined in the SoundEffect enum.

        Example:
            >>> await player.preload_sounds()
        """
        if self._is_setup:
            return

        sound_logger.debug("Preloading sound effects")

        for sound_effect in SoundEffect:
            effect = self._create_sound_effect(sound_effect)
            if effect is not None:
                self._effects[sound_effect] = effect

        self._is_setup = True
        sound_logger.debug(f"Preloaded {len(self._effects)} sound effects")

    def set_volume(self, volume: float) -> None:
        """Set the volume level.

        Args:
            volume: Volume level (0.0 to 1.0)

        Example:
            >>> player.set_volume(0.7)
        """
        self.volume = max(0.0, min(1.0, volume))

        # Update volume for all preloaded effects
        with self._lock:
            clamped = self._get_clamped_volume()
            for effect in self._effects.values():
                effect.setVolume(clamped)

    def set_enabled(self, enabled: bool) -> None:
        """Enable or disable sound effects.

        Args:
            enabled: Whether sound effects should be enabled

        Example:
            >>> player.set_enabled(False)  # Mute all sounds
        """
        self.enabled = enabled

    def is_loaded(self, sound_effect: SoundEffect) -> bool:
        """Check if a sound effect is loaded.

        Args:
            sound_effect: The sound effect to check

        Returns:
            True if the sound is loaded and ready to play
        """
        return sound_effect in self._effects


# Type alias for compatibility with Swift naming
SoundEffectsClient = SoundEffectPlayer


__all__ = ["SoundEffect", "SoundEffectPlayer", "SoundEffectsClient"]
