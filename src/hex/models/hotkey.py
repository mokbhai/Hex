"""HotKey data models for Hex.

This module provides data structures for representing keyboard hotkeys with modifiers.
It mirrors the structure from HexCore/Sources/HexCore/Models/HotKey.swift.
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional, Set, List, ClassVar, Any
import json


class Key(Enum):
    """Keyboard keys supported by Hex.

    This enum represents common keyboard keys. For a production implementation,
    you may want to expand this to cover all possible keys or use a library
    like pynput for comprehensive key support.
    """

    # Letters
    A = "a"
    B = "b"
    C = "c"
    D = "d"
    E = "e"
    F = "f"
    G = "g"
    H = "h"
    I = "i"
    J = "j"
    K = "k"
    L = "l"
    M = "m"
    N = "n"
    O = "o"
    P = "p"
    Q = "q"
    R = "r"
    S = "s"
    T = "t"
    U = "u"
    V = "v"
    W = "w"
    X = "x"
    Y = "y"
    Z = "z"

    # Numbers
    ZERO = "0"
    ONE = "1"
    TWO = "2"
    THREE = "3"
    FOUR = "4"
    FIVE = "5"
    SIX = "6"
    SEVEN = "7"
    EIGHT = "8"
    NINE = "9"

    # Special keys
    SPACE = "space"
    ENTER = "return"
    TAB = "tab"
    ESCAPE = "escape"
    BACKSPACE = "delete"

    # Punctuation
    PERIOD = "."
    COMMA = ","
    SLASH = "/"
    QUOTE = "'"
    BACKSLASH = "\\"
    SEMICOLON = ";"
    GRAVE = "`"

    # Arrow keys
    LEFT_ARROW = "left"
    RIGHT_ARROW = "right"
    UP_ARROW = "up"
    DOWN_ARROW = "down"

    # Function keys
    F1 = "f1"
    F2 = "f2"
    F3 = "f3"
    F4 = "f4"
    F5 = "f5"
    F6 = "f6"
    F7 = "f7"
    F8 = "f8"
    F9 = "f9"
    F10 = "f10"
    F11 = "f11"
    F12 = "f12"

    def to_string(self) -> str:
        """Get display string for the key.

        Returns:
            A human-readable string representation of the key

        Examples:
            >>> Key.A.to_string()
            'A'
            >>> Key.SPACE.to_string()
            '␣'
            >>> Key.ESCAPE.to_string()
            '⎋'
        """
        display_map = {
            Key.ESCAPE: "⎋",
            Key.SPACE: "␣",
            Key.ZERO: "0",
            Key.ONE: "1",
            Key.TWO: "2",
            Key.THREE: "3",
            Key.FOUR: "4",
            Key.FIVE: "5",
            Key.SIX: "6",
            Key.SEVEN: "7",
            Key.EIGHT: "8",
            Key.NINE: "9",
            Key.PERIOD: ".",
            Key.COMMA: ",",
            Key.SLASH: "/",
            Key.QUOTE: "\"",
            Key.BACKSLASH: "\\",
            Key.LEFT_ARROW: "←",
            Key.RIGHT_ARROW: "→",
            Key.UP_ARROW: "↑",
            Key.DOWN_ARROW: "↓",
        }

        if self in display_map:
            return display_map[self]

        # Default: uppercase the value
        return self.value.upper()


class ModifierKind(Enum):
    """Modifier key kinds.

    These represent the different types of modifier keys on a keyboard.
    The order property is used for sorting modifiers in a consistent way.
    """

    COMMAND = auto()
    OPTION = auto()
    SHIFT = auto()
    CONTROL = auto()
    FN = auto()

    @property
    def order(self) -> int:
        """Get the sort order for this modifier kind."""
        order_map = {
            ModifierKind.COMMAND: 0,
            ModifierKind.OPTION: 1,
            ModifierKind.SHIFT: 2,
            ModifierKind.CONTROL: 3,
            ModifierKind.FN: 4,
        }
        return order_map[self]

    @property
    def display_name(self) -> str:
        """Get the human-readable display name."""
        name_map = {
            ModifierKind.COMMAND: "Command",
            ModifierKind.OPTION: "Option",
            ModifierKind.SHIFT: "Shift",
            ModifierKind.CONTROL: "Control",
            ModifierKind.FN: "fn",
        }
        return name_map[self]

    @property
    def symbol(self) -> str:
        """Get the symbol used to represent this modifier."""
        symbol_map = {
            ModifierKind.OPTION: "⌥",
            ModifierKind.SHIFT: "⇧",
            ModifierKind.COMMAND: "⌘",
            ModifierKind.CONTROL: "⌃",
            ModifierKind.FN: "fn",
        }
        return symbol_map[self]

    @property
    def supports_side_selection(self) -> bool:
        """Check if this modifier supports left/right side selection."""
        return self != ModifierKind.FN

    def __lt__(self, other: "ModifierKind") -> bool:
        """Compare modifier kinds for sorting."""
        return self.order < other.order


class ModifierSide(Enum):
    """Side specification for modifier keys.

    Some keyboards distinguish between left and right modifier keys.
    This enum allows specifying which side to use, or "either" for both.
    """

    EITHER = auto()
    LEFT = auto()
    RIGHT = auto()

    @property
    def order(self) -> int:
        """Get the sort order for this side."""
        order_map = {
            ModifierSide.LEFT: 0,
            ModifierSide.EITHER: 1,
            ModifierSide.RIGHT: 2,
        }
        return order_map[self]

    @property
    def display_name(self) -> str:
        """Get the human-readable display name."""
        name_map = {
            ModifierSide.EITHER: "Either",
            ModifierSide.LEFT: "Left",
            ModifierSide.RIGHT: "Right",
        }
        return name_map[self]

    def __lt__(self, other: "ModifierSide") -> bool:
        """Compare sides for sorting."""
        return self.order < other.order


@dataclass(frozen=True)
class Modifier:
    """A modifier key with optional side specification.

    Attributes:
        kind: The type of modifier key (command, option, etc.)
        side: Which side of the keyboard (left, right, or either)

    Examples:
        >>> cmd = Modifier(kind=ModifierKind.COMMAND)
        >>> left_shift = Modifier(kind=ModifierKind.SHIFT, side=ModifierSide.LEFT)
    """

    kind: ModifierKind
    side: ModifierSide = ModifierSide.EITHER

    # Convenience class methods for common modifiers
    COMMAND: ClassVar["Modifier"] = None  # Set below
    OPTION: ClassVar["Modifier"] = None
    SHIFT: ClassVar["Modifier"] = None
    CONTROL: ClassVar["Modifier"] = None
    FN: ClassVar["Modifier"] = None

    @property
    def id(self) -> str:
        """Unique identifier for this modifier."""
        return f"{self.kind.name}-{self.side.name}"

    def with_side(self, side: ModifierSide) -> "Modifier":
        """Create a new modifier with a different side."""
        return Modifier(kind=self.kind, side=side)

    def __lt__(self, other: "Modifier") -> bool:
        """Compare modifiers for sorting."""
        if self.kind == other.kind:
            return self.side.order < other.side.order
        return self.kind.order < other.kind.order

    @property
    def string_value(self) -> str:
        """Get the string representation (symbol)."""
        return self.kind.symbol

    def matches(self, other: "Modifier") -> bool:
        """Check if this modifier matches another, considering side specificity.

        Args:
            other: The modifier to compare against

        Returns:
            True if the modifiers match, False otherwise

        Examples:
            >>> Modifier.COMMAND.matches(Modifier(kind=ModifierKind.COMMAND, side=ModifierSide.LEFT))
            True
            >>> Modifier(kind=ModifierKind.SHIFT, side=ModifierSide.LEFT).matches(
            ...     Modifier(kind=ModifierKind.SHIFT, side=ModifierSide.RIGHT)
            ... )
            False
        """
        if self.kind != other.kind:
            return False
        if self.side == ModifierSide.EITHER or other.side == ModifierSide.EITHER:
            return True
        return self.side == other.side

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {"kind": self.kind.name, "side": self.side.name}

    @classmethod
    def from_dict(cls, data: dict) -> "Modifier":
        """Create from dictionary for JSON deserialization.

        This method supports both the new format {kind: X, side: Y} and
        the legacy format where kind is a string.
        """
        if isinstance(data, str):
            # Legacy format: just the kind as a string
            return cls(kind=ModifierKind[data], side=ModifierSide.EITHER)

        if "kind" not in data:
            raise ValueError("Modifier dict must contain 'kind' key")

        kind = ModifierKind[data["kind"]]
        side = ModifierSide[data.get("side", "EITHER")]
        return cls(kind=kind, side=side)


# Set up class-level convenience instances
Modifier.COMMAND = Modifier(kind=ModifierKind.COMMAND)
Modifier.OPTION = Modifier(kind=ModifierKind.OPTION)
Modifier.SHIFT = Modifier(kind=ModifierKind.SHIFT)
Modifier.CONTROL = Modifier(kind=ModifierKind.CONTROL)
Modifier.FN = Modifier(kind=ModifierKind.FN)


@dataclass(frozen=True)
class Modifiers:
    """A collection of modifier keys.

    This class represents a set of modifiers pressed together (e.g., Cmd+Option).
    It provides set-like operations for working with modifiers.

    Attributes:
        modifiers: Set of Modifier instances

    Examples:
        >>> cmd_option = Modifiers.from_list([Modifier.COMMAND, Modifier.OPTION])
        >>> cmd_option.contains(Modifier.COMMAND)
        True
    """

    modifiers: frozenset[Modifier] = frozenset()

    @classmethod
    def from_list(cls, modifiers: List[Modifier]) -> "Modifiers":
        """Create a Modifiers instance from a list."""
        return cls(modifiers=frozenset(modifiers))

    @classmethod
    def empty(cls) -> "Modifiers":
        """Create an empty Modifiers instance."""
        return cls(modifiers=frozenset())

    @property
    def sorted(self) -> List[Modifier]:
        """Get sorted list of modifiers.

        Returns an empty list if this is a hyperkey combination (all four modifiers),
        as we'll display a special symbol for that case.
        """
        if self.is_hyperkey:
            return []
        return sorted(self.modifiers)

    @property
    def is_hyperkey(self) -> bool:
        """Check if this is a hyperkey combination (Cmd+Opt+Shift+Ctrl)."""
        return (
            self.contains_kind(ModifierKind.COMMAND)
            and self.contains_kind(ModifierKind.OPTION)
            and self.contains_kind(ModifierKind.SHIFT)
            and self.contains_kind(ModifierKind.CONTROL)
        )

    @property
    def is_empty(self) -> bool:
        """Check if no modifiers are present."""
        return len(self.modifiers) == 0

    def contains(self, modifier: Modifier) -> bool:
        """Check if this collection contains the given modifier."""
        return any(m.matches(modifier) for m in self.modifiers)

    def contains_kind(self, kind: ModifierKind) -> bool:
        """Check if this collection contains any modifier of the given kind."""
        return any(m.kind == kind for m in self.modifiers)

    @property
    def kinds(self) -> List[ModifierKind]:
        """Get list of unique modifier kinds, sorted."""
        return sorted({m.kind for m in self.modifiers})

    def is_subset_of(self, other: "Modifiers") -> bool:
        """Check if all modifiers in this collection are in the other."""
        return all(other.contains(m) for m in self.modifiers)

    def is_disjoint_with(self, other: "Modifiers") -> bool:
        """Check if this collection has no overlapping modifiers with the other."""
        return all(not other.contains(m) for m in self.modifiers)

    def union(self, other: "Modifiers") -> "Modifiers":
        """Create a new Modifiers with modifiers from both collections."""
        return Modifiers(modifiers=self.modifiers | other.modifiers)

    def intersection(self, other: "Modifiers") -> "Modifiers":
        """Create a new Modifiers with only common modifiers."""
        return Modifiers(modifiers=self.modifiers & other.modifiers)

    def matches_exactly(self, expected: "Modifiers") -> bool:
        """Check if this matches the expected modifiers exactly.

        This is a strict match that requires:
        1. All expected modifiers are present
        2. No extra modifiers are present
        3. Sides match appropriately
        """
        # Check that all expected modifiers are present
        if not all(self.contains(m) for m in expected.modifiers):
            return False

        # Check that we only have expected kinds
        allowed_kinds = {m.kind for m in expected.modifiers}
        if not all(m.kind in allowed_kinds for m in self.modifiers):
            return False

        # Check side matching
        for candidate in self.modifiers:
            requirement = next(
                (m for m in expected.modifiers if m.kind == candidate.kind), None
            )
            if requirement is None:
                return False
            if not candidate.matches(requirement):
                return False

        return True

    def side_for(self, kind: ModifierKind) -> Optional[ModifierSide]:
        """Get the side for a given modifier kind."""
        for m in self.modifiers:
            if m.kind == kind:
                return m.side
        return None

    def setting(self, kind: ModifierKind, side: ModifierSide) -> "Modifiers":
        """Create a new Modifiers with the given kind set to the specified side."""
        new_modifiers = {m for m in self.modifiers if m.kind != kind}
        new_modifiers.add(Modifier(kind=kind, side=side))
        return Modifiers(modifiers=frozenset(new_modifiers))

    def erasing_sides(self) -> "Modifiers":
        """Create a new Modifiers with all sides set to EITHER."""
        return Modifiers(
            modifiers=frozenset(
                Modifier(kind=m.kind, side=ModifierSide.EITHER) for m in self.modifiers
            )
        )

    def removing(self, kind: ModifierKind) -> "Modifiers":
        """Create a new Modifiers with the given kind removed."""
        return Modifiers(modifiers=frozenset(m for m in self.modifiers if m.kind != kind))

    def to_dict(self) -> List[dict]:
        """Convert to list of dicts for JSON serialization."""
        return [m.to_dict() for m in self.sorted]

    @classmethod
    def from_dict(cls, data: List[dict]) -> "Modifiers":
        """Create from list of dicts for JSON deserialization."""
        return cls(modifiers=frozenset(Modifier.from_dict(d) for d in data))

    def __str__(self) -> str:
        """String representation using modifier symbols."""
        if self.is_hyperkey:
            return "⌘⌥⇧⌃"
        return "".join(m.string_value for m in self.sorted)


@dataclass(frozen=True)
class HotKey:
    """A hotkey combination with optional key and modifiers.

    Attributes:
        key: The main key (optional, for modifier-only hotkeys)
        modifiers: The modifiers to be pressed

    Examples:
        >>> cmd_a = HotKey(key=Key.A, modifiers=Modifiers.from_list([Modifier.COMMAND]))
        >>> fn_only = HotKey(key=None, modifiers=Modifiers.from_list([Modifier.FN]))
    """

    key: Optional[Key]
    modifiers: Modifiers

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "key": self.key.value if self.key else None,
            "modifiers": self.modifiers.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "HotKey":
        """Create from dictionary for JSON deserialization."""
        key = None
        if data.get("key"):
            # Look up Key by value (not name)
            key_value = data["key"]
            for key_member in Key:
                if key_member.value == key_value:
                    key = key_member
                    break
            if key is None:
                raise ValueError(f"Unknown key value: {key_value}")
        modifiers = Modifiers.from_dict(data.get("modifiers", []))
        return cls(key=key, modifiers=modifiers)

    def __str__(self) -> str:
        """String representation."""
        if self.key:
            return f"{self.modifiers}{self.key.to_string()}"
        return str(self.modifiers)
