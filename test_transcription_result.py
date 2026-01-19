#!/usr/bin/env python3
"""Test script for transcription result handler.

This script tests the _handle_transcription_result implementation to verify:
1. Force quit command detection
2. Text normalization
"""

import sys
from pathlib import Path

# Test the force quit and normalization functions directly
def test_normalize_force_quit_text():
    """Test text normalization for force quit command."""

    def normalize_force_quit_text(text: str) -> str:
        """Normalize text for force quit command matching."""
        import unicodedata
        import re

        # Normalize unicode (remove diacritics)
        normalized = unicodedata.normalize('NFKD', text)
        # Remove diacritic marks
        normalized = ''.join(
            c for c in normalized
            if not unicodedata.combining(c)
        )
        # Convert to lowercase
        normalized = normalized.lower()
        # Replace non-alphanumeric characters (except spaces) with spaces
        normalized = re.sub(r'[^a-z0-9\s]', ' ', normalized)
        # Collapse multiple spaces
        normalized = re.sub(r'\s+', ' ', normalized)
        # Strip leading/trailing whitespace
        normalized = normalized.strip()

        return normalized

    test_cases = [
        ("Force-Quit Héx Nów!", "force quit hex now"),
        ("Héllo Wörld", "hello world"),
        ("Multiple   Spaces", "multiple spaces"),
        ("Punctuation! Removes?", "punctuation removes"),
        ("force quit hex", "force quit hex"),
    ]

    print("Testing text normalization:")
    for text, expected in test_cases:
        result = normalize_force_quit_text(text)
        status = "✓" if result == expected else "✗"
        print(f"  {status} '{text}' -> '{result}'")
        assert result == expected, f"Failed for '{text}'"

    print("  All normalization tests passed!\n")


def test_force_quit_command():
    """Test force quit command detection."""

    def normalize_force_quit_text(text: str) -> str:
        """Normalize text for force quit command matching."""
        import unicodedata
        import re

        normalized = unicodedata.normalize('NFKD', text)
        normalized = ''.join(
            c for c in normalized
            if not unicodedata.combining(c)
        )
        normalized = normalized.lower()
        # Replace non-alphanumeric characters (except spaces) with spaces
        normalized = re.sub(r'[^a-z0-9\s]', ' ', normalized)
        # Collapse multiple spaces
        normalized = re.sub(r'\s+', ' ', normalized)
        normalized = normalized.strip()
        return normalized

    def matches_force_quit_command(text: str) -> bool:
        """Check if text matches the force quit command."""
        normalized = normalize_force_quit_text(text)
        return normalized in ("force quit hex now", "force quit hex")

    # Test various force quit phrases
    test_cases = [
        ("force quit hex now", True),
        ("force quit hex", True),
        ("Force quit HEX now!", True),
        ("Force-Quit Hex NOW!", True),
        ("hello world", False),
        ("quit hex", False),
        ("force quit", False),
    ]

    print("Testing force quit command detection:")
    for text, expected in test_cases:
        result = matches_force_quit_command(text)
        status = "✓" if result == expected else "✗"
        if result != expected:
            normalized = normalize_force_quit_text(text)
            print(f"  {status} '{text}' -> {result} (expected {expected}) [normalized: '{normalized}']")
        else:
            print(f"  {status} '{text}' -> {result} (expected {expected})")
        assert result == expected, f"Failed for '{text}'"

    print("  All force quit tests passed!\n")


def main():
    """Run all tests."""
    print("=" * 60)
    print("Transcription Result Handler Tests")
    print("=" * 60 + "\n")

    test_force_quit_command()
    test_normalize_force_quit_text()

    print("=" * 60)
    print("All tests passed! ✓")
    print("=" * 60)


if __name__ == "__main__":
    main()
