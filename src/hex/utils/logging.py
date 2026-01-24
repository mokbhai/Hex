"""Logging infrastructure for Hex.

This module provides a unified logging interface similar to HexLog in the Swift app.
It mirrors the structure from HexCore/Sources/HexCore/Logging.swift.
"""

import logging
import sys
from enum import Enum
from typing import Optional, Union


# Subsystem identifier matching Swift implementation
SUBSYSTEM = "com.kitlangton.Hex"


class LogCategory(Enum):
    """Log categories matching HexLog.Category in the Swift app.

    These categories align with the Swift implementation for consistency
    across the Python and Swift versions of Hex.
    """

    APP = "App"
    CACHES = "Caches"
    TRANSCRIPTION = "Transcription"
    MODELS = "Models"
    RECORDING = "Recording"
    MEDIA = "Media"
    PASTEBOARD = "Pasteboard"
    SOUND = "SoundEffect"
    HOTKEY = "HotKey"
    KEY_EVENT = "KeyEvent"
    PARAKEET = "Parakeet"
    HISTORY = "History"
    SETTINGS = "Settings"
    PERMISSIONS = "Permissions"


# Configure root logger
def _setup_logging() -> None:
    """Configure the root logger with appropriate formatting."""
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)

    root_logger = logging.getLogger("hex")
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(handler)


_setup_logging()


def get_logger(category: Union[str, LogCategory]) -> logging.Logger:
    """
    Get a logger for the specified category.

    This function matches the behavior of HexLog.logger(_ category:) in Swift.

    Args:
        category: Either a LogCategory enum or a string category name

    Returns:
        A logger instance for the category

    Examples:
        >>> logger = get_logger(LogCategory.TRANSCRIPTION)
        >>> logger.info("Transcription started")
        >>> logger = get_logger("App")
        >>> logger.debug("Application starting")
    """
    if isinstance(category, LogCategory):
        category_name = category.value
    else:
        category_name = category

    return logging.getLogger(f"hex.{category_name}")


# Convenience loggers matching Swift static properties
# These provide direct access to commonly used loggers
app = get_logger(LogCategory.APP)
caches = get_logger(LogCategory.CACHES)
transcription = get_logger(LogCategory.TRANSCRIPTION)
models = get_logger(LogCategory.MODELS)
recording = get_logger(LogCategory.RECORDING)
media = get_logger(LogCategory.MEDIA)
pasteboard = get_logger(LogCategory.PASTEBOARD)
sound = get_logger(LogCategory.SOUND)
hotkey = get_logger(LogCategory.HOTKEY)
key_event = get_logger(LogCategory.KEY_EVENT)
parakeet = get_logger(LogCategory.PARAKEET)
history = get_logger(LogCategory.HISTORY)
settings = get_logger(LogCategory.SETTINGS)
permissions = get_logger(LogCategory.PERMISSIONS)
