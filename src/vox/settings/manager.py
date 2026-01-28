"""Settings persistence manager for Hex.

This module provides the SettingsManager class responsible for loading and saving
user settings to disk with platform-appropriate directory paths.

It mirrors the functionality from HexCore/Sources/HexCore/Settings/VoxSettings.swift
adapted for Python's cross-platform requirements.
"""

import json
import platform
from pathlib import Path
from typing import Optional

from vox.models.settings import VoxSettings
from vox.utils.logging import get_logger, LogCategory

# Module identifier
BUNDLE_ID = "com.mokbhaimj.Vox"

# Logger for this module
logger = get_logger(LogCategory.SETTINGS)


def _get_config_directory() -> Path:
    """Get the platform-appropriate configuration directory.

    Returns the appropriate directory for storing application configuration
    based on the operating system:

    - macOS: ~/Library/Application Support/com.mokbhaimj.Vox/
    - Windows: %APPDATA%/com.mokbhaimj.Vox/
    - Linux: ~/.local/share/com.mokbhaimj.Vox/ (XDG Base Directory Specification)

    Returns:
        Path object pointing to the configuration directory
    """
    system = platform.system()

    if system == "Darwin":  # macOS
        # macOS: ~/Library/Application Support/
        config_dir = Path.home() / "Library" / "Application Support" / BUNDLE_ID
    elif system == "Windows":  # Windows
        # Windows: %APPDATA%/com.mokbhaimj.Vox/
        appdata = Path.home() / "AppData" / "Roaming"
        config_dir = appdata / BUNDLE_ID
    else:  # Linux and others
        # Linux: ~/.local/share/com.mokbhaimj.Vox/ (XDG Base Directory)
        config_dir = Path.home() / ".local" / "share" / BUNDLE_ID

    return config_dir


class SettingsManager:
    """Manager for loading and saving Hex settings.

    This class handles persistence of VoxSettings to disk using JSON format.
    It automatically creates the configuration directory if it doesn't exist
    and provides platform-appropriate file paths.

    Attributes:
        settings_path: Path to the settings JSON file

    Examples:
        >>> manager = SettingsManager()
        >>> print(manager.settings_path)
        ~/Library/Application Support/com.mokbhaimj.Vox/settings.json
        >>> settings = await manager.load()
        >>> settings.soundEffectsEnabled = False
        >>> await manager.save(settings)
    """

    # Settings filename
    SETTINGS_FILENAME = "settings.json"

    def __init__(self, config_dir: Optional[Path] = None) -> None:
        """Initialize the SettingsManager.

        Args:
            config_dir: Optional custom configuration directory. If not provided,
                       uses the platform-appropriate default location.
        """
        if config_dir is None:
            config_dir = _get_config_directory()

        self._config_dir = config_dir
        self._settings_path = config_dir / self.SETTINGS_FILENAME

        logger.debug(f"SettingsManager initialized with path: {self._settings_path}")

    @property
    def settings_path(self) -> Path:
        """Get the path to the settings file.

        Returns:
            Path object pointing to the settings JSON file
        """
        return self._settings_path

    @property
    def config_directory(self) -> Path:
        """Get the configuration directory path.

        Returns:
            Path object pointing to the configuration directory
        """
        return self._config_dir

    def ensure_config_directory(self) -> None:
        """Ensure the configuration directory exists.

        Creates the configuration directory and any necessary parent directories
        if they don't already exist.
        """
        self._config_dir.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Config directory ensured: {self._config_dir}")

    def settings_file_exists(self) -> bool:
        """Check if the settings file exists.

        Returns:
            True if the settings file exists, False otherwise
        """
        return self._settings_path.exists()

    async def load(self) -> VoxSettings:
        """Load settings from disk.

        Reads the settings JSON file and deserializes it into a VoxSettings instance.
        If the file doesn't exist or contains invalid data, returns default settings.

        Returns:
            VoxSettings instance with loaded or default values

        Examples:
            >>> manager = SettingsManager()
            >>> settings = await manager.load()
            >>> print(settings.hotkey)
        """
        # Check if settings file exists
        if not self.settings_file_exists():
            logger.info("Settings file not found, using defaults")
            return VoxSettings()

        try:
            # Read and parse JSON file
            with open(self._settings_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            logger.debug(f"Loaded settings from {self._settings_path}")

            # Deserialize into VoxSettings
            return VoxSettings.from_dict(data)

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in settings file: {e}")
            return VoxSettings()

        except (ValueError, KeyError, TypeError) as e:
            logger.error(f"Error parsing settings: {e}")
            return VoxSettings()

        except Exception as e:
            logger.error(f"Unexpected error loading settings: {e}")
            return VoxSettings()

    async def save(self, settings: Optional[VoxSettings] = None) -> None:
        """Save settings to disk.

        Serializes the provided VoxSettings instance to JSON and writes it to disk.
        Creates the configuration directory if it doesn't exist.

        Args:
            settings: VoxSettings instance to save. If None, saves default settings.

        Raises:
            OSError: If unable to write to the settings file
            TypeError: If settings cannot be serialized to JSON

        Examples:
            >>> manager = SettingsManager()
            >>> settings = VoxSettings(soundEffectsEnabled=False)
            >>> await manager.save(settings)
        """
        # Use provided settings or defaults
        if settings is None:
            settings = VoxSettings()

        try:
            # Ensure config directory exists
            self.ensure_config_directory()

            # Serialize to JSON
            data = settings.to_dict()

            # Write to file with atomic write pattern
            # Write to temp file first, then rename to prevent corruption
            temp_path = self._settings_path.with_suffix(".tmp")

            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            # Atomic rename
            temp_path.replace(self._settings_path)

            logger.debug(f"Saved settings to {self._settings_path}")

        except (TypeError, ValueError) as e:
            logger.error(f"Error serializing settings: {e}")
            raise

        except OSError as e:
            logger.error(f"Error writing settings file: {e}")
            raise

        except Exception as e:
            logger.error(f"Unexpected error saving settings: {e}")
            raise
