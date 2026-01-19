"""Word processing models for Hex.

This module provides data structures for word remapping and removal,
mirroring the structure from HexCore/Sources/HexCore/Models/WordRemapping.swift
and HexCore/Sources/HexCore/Models/WordRemoval.swift.
"""

import re
from dataclasses import dataclass, field
from typing import List
import uuid


@dataclass(frozen=True)
class WordRemapping:
    """A word remapping rule for text processing.

    This model represents a rule for replacing matched words or phrases
    with replacement text. Supports regex patterns and escape sequences.

    Attributes:
        id: Unique identifier for this remapping rule
        is_enabled: Whether this rule is currently active
        match: The pattern to match (will be converted to word-boundary regex)
        replacement: The text to replace matches with

    Examples:
        >>> remapping = WordRemapping(match='um', replacement='')
        >>> WordRemappingApplier.apply('um hello um world', [remapping])
        'hello world'
    """

    id: uuid.UUID = field(default_factory=uuid.uuid4)
    is_enabled: bool = True
    match: str = ""
    replacement: str = ""

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "id": str(self.id),
            "isEnabled": self.is_enabled,
            "match": self.match,
            "replacement": self.replacement,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "WordRemapping":
        """Create from dictionary for JSON deserialization."""
        return cls(
            id=uuid.UUID(data["id"]) if "id" in data else uuid.uuid4(),
            is_enabled=data.get("isEnabled", True),
            match=data.get("match", ""),
            replacement=data.get("replacement", ""),
        )


class WordRemappingApplier:
    """Applies word remapping rules to text.

    This class provides static methods for processing text through
    a series of word remapping rules.
    """

    @staticmethod
    def apply(text: str, remappings: List[WordRemapping]) -> str:
        """Apply word remapping rules to text.

        Args:
            text: The input text to process
            remappings: List of remapping rules to apply

        Returns:
            The processed text with all enabled remappings applied

        Examples:
            >>> remapping = WordRemapping(match='um', replacement='')
            >>> WordRemappingApplier.apply('um hello', [remapping])
            'hello'
        """
        if not remappings:
            return text

        output = text
        for remapping in remappings:
            if not remapping.is_enabled:
                continue

            trimmed = remapping.match.strip()
            if not trimmed:
                continue

            # Escape special regex characters in the match pattern
            escaped = re.escape(trimmed)
            # Add word boundaries to match whole words only
            pattern = rf"(?<!\w){escaped}(?!\w)"

            # Process escape sequences in the replacement text
            replacement = WordRemappingApplier._process_escape_sequences(
                remapping.replacement
            )

            # Apply the replacement (case-insensitive)
            output = re.sub(
                pattern,
                replacement,
                output,
                flags=re.IGNORECASE,
            )

        return output

    @staticmethod
    def _process_escape_sequences(string: str) -> str:
        """Process escape sequences in a string.

        Converts escape sequences like \\n, \\t, \\r, \\\\ to their
        actual characters.

        Args:
            string: The string containing escape sequences

        Returns:
            The string with escape sequences processed

        Examples:
            >>> WordRemappingApplier._process_escape_sequences('hello\\nworld')
            'hello\\nworld'
            >>> WordRemappingApplier._process_escape_sequences('backslash\\\\')
            'backslash\\\\'
        """
        placeholder = "\x00"
        result = string
        # First replace \\ with placeholder to preserve literal backslashes
        result = result.replace("\\\\", placeholder)
        # Then process escape sequences
        result = result.replace("\\n", "\n")
        result = result.replace("\\t", "\t")
        result = result.replace("\\r", "\r")
        # Finally, replace placeholder with single backslash
        result = result.replace(placeholder, "\\")
        return result


@dataclass(frozen=True)
class WordRemoval:
    """A word removal rule for filtering text.

    This model represents a rule for removing matched words or phrases
    from text. The pattern is treated as a regex with word boundaries.

    Attributes:
        id: Unique identifier for this removal rule
        is_enabled: Whether this rule is currently active
        pattern: The regex pattern to match for removal

    Examples:
        >>> removal = WordRemoval(pattern='um|uh|like')
        >>> WordRemovalApplier.apply('um hello uh world', [removal])
        'hello world'
    """

    id: uuid.UUID = field(default_factory=uuid.uuid4)
    is_enabled: bool = True
    pattern: str = ""

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "id": str(self.id),
            "isEnabled": self.is_enabled,
            "pattern": self.pattern,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "WordRemoval":
        """Create from dictionary for JSON deserialization."""
        return cls(
            id=uuid.UUID(data["id"]) if "id" in data else uuid.uuid4(),
            is_enabled=data.get("isEnabled", True),
            pattern=data.get("pattern", ""),
        )


class WordRemovalApplier:
    """Applies word removal rules to text.

    This class provides static methods for processing text through
    a series of word removal rules, with cleanup of extra whitespace
    and punctuation.
    """

    @staticmethod
    def apply(text: str, removals: List[WordRemoval]) -> str:
        """Apply word removal rules to text.

        Args:
            text: The input text to process
            removals: List of removal rules to apply

        Returns:
            The processed text with all enabled removals applied,
            with cleanup of extra whitespace and punctuation

        Examples:
            >>> removal = WordRemoval(pattern='um|uh')
            >>> WordRemovalApplier.apply('um hello uh world', [removal])
            'hello world'
        """
        if not text or not removals:
            return text

        output = text
        did_change = False

        for removal in removals:
            if not removal.is_enabled:
                continue

            trimmed = removal.pattern.strip()
            if not trimmed:
                continue

            # Add word boundaries to match whole words only
            pattern = rf"(?<!\w)(?:{trimmed})(?!\w)"

            try:
                # Replace matches with empty string
                updated = re.sub(pattern, "", output, flags=re.IGNORECASE)
                if updated != output:
                    did_change = True
                    output = updated
            except re.error:
                # If regex is invalid, skip this removal rule
                continue

        if not did_change:
            return text

        return WordRemovalApplier._cleanup(output)

    @staticmethod
    def _cleanup(text: str) -> str:
        """Clean up text after removal.

        Removes extra whitespace, fixes punctuation, and normalizes spacing.

        Args:
            text: The text to clean up

        Returns:
            The cleaned up text

        Examples:
            >>> WordRemovalApplier._cleanup('hello  ,  world')
            'hello, world'
        """
        output = text

        # Collapse multiple spaces/tabs into single space
        output = re.sub(r"[ \t]{2,}", " ", output)

        # Remove spaces before punctuation
        output = re.sub(r"[ \t]+([,\.!?;:])", r"\1", output)

        # Remove repeated punctuation (e.g., "!!" -> "!")
        output = re.sub(r"([,\.!?;:])[ \t]*\1+", r"\1", output)

        # Remove leading/trailing punctuation on lines
        output = re.sub(r"(?m)^[ \t]*[,\.!?;:]+[ \t]*", "", output)

        # Remove spaces before newlines
        output = re.sub(r"[ \t]+\n", "\n", output)

        # Remove spaces after newlines
        output = re.sub(r"\n[ \t]+", "\n", output)

        return output.strip()
