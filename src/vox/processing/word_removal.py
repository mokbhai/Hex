"""Word removal processing for Hex.

This module provides the WordRemovalApplier class for applying
word removal rules to text. It mirrors the functionality from
HexCore/Sources/HexCore/Models/WordRemoval.swift.
"""

import re
from typing import List

from vox.models.word_processing import WordRemoval


class WordRemovalApplier:
    """Applies word removal rules to text.

    This class provides static methods for processing text through
    a series of word removal rules. The implementation mirrors
    the Swift WordRemovalApplier from HexCore.
    """

    @staticmethod
    def apply(text: str, removals: List[WordRemoval]) -> str:
        """Apply word removal rules to text.

        This method processes text through a list of removal rules,
        applying each enabled rule in sequence. Each removal uses
        word boundaries to match whole words only, with case-insensitive
        matching. After removals are applied, cleanup is performed to
        fix spacing and punctuation issues.

        Args:
            text: The input text to process
            removals: List of removal rules to apply

        Returns:
            The processed text with all enabled removals applied and
            spacing/punctuation cleaned up. If no changes were made,
            returns the original text.

        Examples:
            >>> removal = WordRemoval(pattern='um')
            >>> WordRemovalApplier.apply('um uh er test', [removal])
            'uh er test'
            >>> removals = [WordRemoval(pattern='um'), WordRemoval(pattern='uh')]
            >>> WordRemovalApplier.apply('um uh er test', removals)
            'er test'
        """
        # Guard clause for empty text or no removals
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

            # Create word-boundary regex pattern
            # (?<!\w) - negative lookbehind to ensure not preceded by word char
            # (?:...) - non-capturing group for the pattern
            # (?!\w) - negative lookahead to ensure not followed by word char
            pattern = rf"(?<!\w)(?:{trimmed})(?!\w)"

            try:
                # Attempt to compile and apply the regex
                regex = re.compile(pattern, re.IGNORECASE)
                updated = regex.sub("", output)

                if updated != output:
                    did_change = True
                    output = updated
            except re.error:
                # If regex pattern is invalid, skip this removal rule
                continue

        # If no changes were made, return original text
        if not did_change:
            return text

        # Clean up spacing and punctuation issues
        return WordRemovalApplier._cleanup(output)

    @staticmethod
    def _cleanup(text: str) -> str:
        """Clean up text after removal.

        This method performs several cleanup operations to fix spacing
        and punctuation issues that may occur after removing words:
        - Collapses multiple spaces/tabs into single space
        - Removes spaces before punctuation
        - Removes repeated punctuation
        - Removes leading/trailing punctuation on lines
        - Removes spaces before/after newlines

        This mirrors the Swift implementation's cleanup method.

        Args:
            text: The text to clean up

        Returns:
            The cleaned up text with normalized spacing and punctuation

        Examples:
            >>> WordRemovalApplier._cleanup('hello  world')
            'hello world'
            >>> WordRemovalApplier._cleanup('hello  ,  world')
            'hello, world'
            >>> WordRemovalApplier._cleanup('hello!!')
            'hello!'
        """
        output = text

        # Collapse multiple spaces/tabs into single space
        # [ \t]{2,} matches 2 or more spaces/tabs
        output = re.sub(r"[ \t]{2,}", " ", output)

        # Remove spaces before punctuation marks
        # [ \t]+([,\.!?;:]) captures the punctuation, \1 uses it
        output = re.sub(r"[ \t]+([,\.!?;:])", r"\1", output)

        # Remove repeated punctuation (e.g., "!!" -> "!")
        # ([,\.!?;:]) captures first punctuation, \1+ matches repeats
        output = re.sub(r"([,\.!?;:])[ \t]*\1+", r"\1", output)

        # Remove leading/trailing punctuation on lines
        # (?m) enables multiline mode, ^ matches start of line
        output = re.sub(r"(?m)^[ \t]*[,\.!?;:]+[ \t]*", "", output)

        # Remove spaces before newlines
        output = re.sub(r"[ \t]+\n", "\n", output)

        # Remove spaces after newlines
        output = re.sub(r"\n[ \t]+", "\n", output)

        # Strip leading/trailing whitespace from final result
        return output.strip()
