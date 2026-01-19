"""Hotkey processing logic for Hex.

This package contains the state machine and logic for detecting and processing
hotkey activations, including press-and-hold and double-tap lock modes.
"""

from hex.hotkeys.processor import HotKeyProcessor, State, Output

__all__ = ["HotKeyProcessor", "State", "Output"]
