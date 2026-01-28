"""Entry point for running vox as a module."""

from vox.app import main


def entry_point() -> None:
    """Main entry point for the application."""
    main()


if __name__ == "__main__":
    entry_point()
