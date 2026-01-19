"""Logging infrastructure for Hex.

This module provides a unified logging interface similar to HexLog in the Swift app.
"""

import logging
import sys
from enum import Enum
from typing import Optional


class LogCategory(Enum):
    """Log categories for filtering and consistency."""

    TRANSCRIPTION = "transcription"
    RECORDING = "recording"
    SETTINGS = "settings"
    HOTKEY = "hotkey"
    GUI = "gui"
    CLIPBOARD = "clipboard"
    AUDIO = "audio"
    APP = "app"


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


def get_logger(category: str | LogCategory) -> logging.Logger:
    """
    Get a logger for the specified category.

    Args:
        category: Either a LogCategory enum or a string category name

    Returns:
        A logger instance for the category

    Examples:
        >>> logger = get_logger(LogCategory.TRANSCRIPTION)
        >>> logger.info("Transcription started")
        >>> logger = get_logger("app")
        >>> logger.debug("Application starting")
    """
    if isinstance(category, LogCategory):
        category_name = category.value
    else:
        category_name = category

    return logging.getLogger(f"hex.{category_name}")
