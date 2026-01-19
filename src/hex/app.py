"""Main application module for Hex voice-to-text."""

import sys
from hex.utils.logging import get_logger

logger = get_logger("app")


def main() -> None:
    """
    Main application entry point.

    Initializes and runs the Hex voice-to-text application.
    """
    logger.info("Starting Hex voice-to-text application")

    # TODO: Initialize GUI
    # TODO: Start hotkey monitoring
    # TODO: Load settings

    logger.info("Hex application started successfully")


if __name__ == "__main__":
    main()
