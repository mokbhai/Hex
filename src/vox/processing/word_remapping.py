"""Word remapping processing for Hex.

This module provides the WordRemappingApplier class for applying
word remapping rules to text. It mirrors the functionality from
HexCore/Sources/HexCore/Models/WordRemapping.swift.
"""

import re
from typing import List

from vox.models.word_processing import WordRemapping


class WordRemappingApplier:
    """Applies word remapping rules to text.

    This class provides static methods for processing text through
    a series of word remapping rules. The implementation mirrors
    the Swift WordRemappingApplier from HexCore.
    """

    @staticmethod
    def apply(text: str, remappings: List[WordRemapping]) -> str:
        """Apply word remapping rules to text.

        This method processes text through a list of remapping rules,
        applying each enabled rule in sequence. Each remapping uses
        word boundaries to match whole words only, and supports
        escape sequences in the replacement text.

        Args:
            text: The input text to process
            remappings: List of remapping rules to apply

        Returns:
            The processed text with all enabled remappings applied

        Examples:
            >>> remapping = WordRemapping(match='um', replacement='')
            >>> WordRemappingApplier.apply('test um here', [remapping])
            'test  here'
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

            # Escape backslashes for regex replacement
            # (backslash is special in replacement strings)
            escaped_replacement = replacement.replace("\\", "\\\\")

            # Apply the replacement (case-insensitive)
            output = re.sub(
                pattern,
                escaped_replacement,
                output,
                flags=re.IGNORECASE,
            )

        return output

    @staticmethod
    def _process_escape_sequences(string: str) -> str:
        """Process escape sequences in a string.

        Converts escape sequences like \\n, \\t, \\r, \\\\ to their
        actual characters. This mirrors the Swift implementation's
        processEscapeSequences method.

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
        placeholder = "\u0000"
        result = string
        # First replace \\ with placeholder to preserve literal backslashes
        result = result.replace("\\\\", placeholder)
        # Then process other escape sequences
        result = result.replace("\\n", "\n")
        result = result.replace("\\t", "\t")
        result = result.replace("\\r", "\r")
        # Finally, replace placeholder with single backslash
        result = result.replace(placeholder, "\\")
        return result
