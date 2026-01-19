"""Settings persistence manager for Hex.

This module provides the SettingsManager class responsible for loading and saving
user settings to disk with platform-appropriate directory paths.

It mirrors the functionality from HexCore/Sources/HexCore/Settings/HexSettings.swift
adapted for Python's cross-platform requirements.
"""

import json
import platform
from pathlib import Path
from typing import Optional

from hex.models.settings import HexSettings
from hex.utils.logging import get_logger, LogCategory

# Module identifier
BUNDLE_ID = "com.kitlangton.Hex"

# Logger for this module
logger = get_logger(LogCategory.SETTINGS)


def _get_config_directory() -> Path:
    """Get the platform-appropriate configuration directory.

    Returns the appropriate directory for storing application configuration
    based on the operating system:

    - macOS: ~/Library/Application Support/com.kitlangton.Hex/
    - Windows: %APPDATA%/com.kitlangton.Hex/
    - Linux: ~/.local/share/com.kitlangton.Hex/ (XDG Base Directory Specification)

    Returns:
        Path object pointing to the configuration directory
    """
    system = platform.system()

    if system == "Darwin":  # macOS
        # macOS: ~/Library/Application Support/
        config_dir = Path.home() / "Library" / "Application Support" / BUNDLE_ID
    elif system == "Windows":  # Windows
        # Windows: %APPDATA%/com.kitlangton.Hex/
        appdata = Path.home() / "AppData" / "Roaming"
        config_dir = appdata / BUNDLE_ID
    else:  # Linux and others
        # Linux: ~/.local/share/com.kitlangton.Hex/ (XDG Base Directory)
        config_dir = Path.home() / ".local" / "share" / BUNDLE_ID

    return config_dir


class SettingsManager:
    """Manager for loading and saving Hex settings.

    This class handles persistence of HexSettings to disk using JSON format.
    It automatically creates the configuration directory if it doesn't exist
    and provides platform-appropriate file paths.

    Attributes:
        settings_path: Path to the settings JSON file

    Examples:
        >>> manager = SettingsManager()
        >>> print(manager.settings_path)
        ~/Library/Application Support/com.kitlangton.Hex/settings.json
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
