"""Sound effects client for playing audio feedback.

This module provides sound effect functionality to mirror the Swift implementation
in Hex/Clients/SoundEffect.swift.

The client handles:
- Playing sound effects for transcription actions
- Preloading sound effects for instant playback
- Volume control and enable/disable

Note: This is a simplified stub implementation. The full implementation would use
pygame or similar for audio playback on macOS.
"""

import asyncio
from enum import Enum, auto
from pathlib import Path

from hex.utils.logging import get_logger, LogCategory


# Module logger
sound_logger = get_logger(LogCategory.SOUND)


class SoundEffect(Enum):
    """Sound effect types.

    Matches SoundEffect enum from Swift implementation.
    """

    PASTE_TRANSCRIPT = auto()
    START_RECORDING = auto()
    STOP_RECORDING = auto()
    CANCEL = auto()

    @property
    def file_name(self) -> str:
        """Get the file name for this sound effect."""
        return self.name.lower()

    @property
    def file_extension(self) -> str:
        """Get the file extension for sound effects."""
        return "mp3"


class SoundEffectsClient:
    """Client for playing sound effects.

    This class provides async sound effect functionality with volume control
    and enable/disable capabilities.

    Attributes:
        enabled: Whether sound effects are enabled
        volume: Volume level (0.0 to 1.0)

    Example:
        >>> client = SoundEffectsClient()
        >>> await client.play(SoundEffect.PASTE_TRANSCRIPT)
    """

    def __init__(self, enabled: bool = True, volume: float = 0.5) -> None:
        """Initialize the SoundEffectsClient.

        Args:
            enabled: Whether sound effects are enabled
            volume: Volume level (0.0 to 1.0)
        """
        self.enabled = enabled
        self.volume = max(0.0, min(1.0, volume))
        self._sounds_dir: Path | None = None

    async def play(self, sound_effect: SoundEffect) -> None:
        """Play a sound effect.

        This is a stub implementation that logs the sound effect.
        The full implementation would play the actual audio file.

        Args:
            sound_effect: The sound effect to play

        Example:
            >>> await client.play(SoundEffect.PASTE_TRANSCRIPT)
        """
        if not self.enabled:
            return

        # Log the sound effect (stub implementation)
        sound_logger.debug(f"Playing sound effect: {sound_effect.file_name}")

        # TODO: Implement actual audio playback
        # The full implementation would:
        # 1. Load the audio file from Resources/Audio/{sound_effect.file_name}.mp3
        # 2. Play it using pygame or similar
        # 3. Apply volume control

        # For now, just await to simulate async operation
        await asyncio.sleep(0)

    def set_sounds_directory(self, directory: Path) -> None:
        """Set the directory containing sound effect files.

        Args:
            directory: Path to the directory containing sound files
        """
        self._sounds_dir = directory

    async def preload_sounds(self) -> None:
        """Preload all sound effects for instant playback.

        This is a stub implementation. The full implementation would
        load all audio files into memory.
        """
        sound_logger.debug("Preloading sound effects")
        # TODO: Implement actual preloading
        await asyncio.sleep(0)


__all__ = ["SoundEffect", "SoundEffectsClient"]
