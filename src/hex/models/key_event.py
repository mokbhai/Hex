"""KeyEvent data models for Hex.

This module provides data structures for representing keyboard and mouse input events.
It mirrors the structure from HexCore/Sources/HexCore/Models/KeyEvent.swift.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum, auto
from typing import Optional

from hex.models.hotkey import Key, Modifiers


class InputEventType(Enum):
    """Types of input events.

    These represent the different categories of input events that can occur.
    """

    KEYBOARD = auto()
    MOUSE_CLICK = auto()


@dataclass(frozen=True)
class KeyEvent:
    """A keyboard event with key, modifiers, and timestamp.

    This class represents a single keyboard event, capturing what key was pressed
    (if any), which modifiers were active, and when the event occurred.

    Attributes:
        key: The key that was pressed (None for modifier-only events)
        modifiers: The active modifiers at the time of the event
        timestamp: When the event occurred

    Examples:
        >>> from datetime import datetime
        >>> event = KeyEvent(
        ...     key=Key.A,
        ...     modifiers=Modifiers.empty(),
        ...     timestamp=datetime.now()
        ... )
        >>> modifier_event = KeyEvent(
        ...     key=None,
        ...     modifiers=Modifiers.from_list([Modifier.COMMAND]),
        ...     timestamp=datetime.now()
        ... )
    """

    key: Optional[Key]
    modifiers: Modifiers
    timestamp: datetime
    is_press: bool = True

    def __str__(self) -> str:
        """String representation of the key event."""
        if self.key:
            return f"KeyEvent(key={self.key.name}, modifiers={self.modifiers}, timestamp={self.timestamp.isoformat()})"
        return f"KeyEvent(key=None, modifiers={self.modifiers}, timestamp={self.timestamp.isoformat()})"


@dataclass(frozen=True)
class InputEvent:
    """An input event from the user.

    This class represents either a keyboard event or a mouse click event.
    It uses Python's dataclass to provide a simple union-like structure.

    Attributes:
        event_type: The type of input event (keyboard or mouse click)
        key_event: The KeyEvent data (only set for keyboard events)

    Examples:
        >>> from datetime import datetime
        >>> key_evt = KeyEvent(key=Key.A, modifiers=Modifiers.empty(), timestamp=datetime.now())
        >>> input_evt = InputEvent(event_type=InputEventType.KEYBOARD, key_event=key_evt)
        >>> mouse_evt = InputEvent(event_type=InputEventType.MOUSE_CLICK, key_event=None)
    """

    event_type: InputEventType
    key_event: Optional[KeyEvent] = None

    @classmethod
    def keyboard(cls, key_event: KeyEvent) -> "InputEvent":
        """Create a keyboard input event."""
        return cls(event_type=InputEventType.KEYBOARD, key_event=key_event)

    @classmethod
    def mouse_click(cls) -> "InputEvent":
        """Create a mouse click input event."""
        return cls(event_type=InputEventType.MOUSE_CLICK, key_event=None)

    @property
    def is_keyboard(self) -> bool:
        """Check if this is a keyboard event."""
        return self.event_type == InputEventType.KEYBOARD

    @property
    def is_mouse_click(self) -> bool:
        """Check if this is a mouse click event."""
        return self.event_type == InputEventType.MOUSE_CLICK

    def __str__(self) -> str:
        """String representation of the input event."""
        if self.is_keyboard and self.key_event:
            return f"InputEvent(keyboard={self.key_event})"
        return "InputEvent(mouse_click)"
