"""Main application module for Hex voice-to-text."""

import sys
from hex.utils.logging import get_logger
from hex.gui import create_app

logger = get_logger("app")


def main() -> int:
    """
    Main application entry point.

    Initializes and runs the Hex voice-to-text application.

    Returns:
        Application exit code
    """
    logger.info("Starting Hex voice-to-text application")

    try:
        # Create and run GUI application
        app = create_app()

        # TODO: Start hotkey monitoring
        # TODO: Load settings
        # TODO: Connect GUI signals to business logic

        logger.info("Hex application started successfully")

        # Enter event loop
        return app.run()

    except Exception as e:
        logger.error(f"Failed to start application: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
