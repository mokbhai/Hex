"""Tests for ClipboardClient."""

import asyncio
import pytest

from hex.clients.clipboard import ClipboardClient, PasteboardSnapshot


@pytest.mark.asyncio
async def test_copy_to_clipboard():
    """Test copying text to clipboard."""
    client = ClipboardClient()
    test_text = "Hello, Clipboard!"

    await client.copy(test_text)

    # Verify text is on clipboard
    import pyperclip

    clipboard_content = pyperclip.paste()
    assert clipboard_content == test_text


@pytest.mark.asyncio
async def test_pasteboard_snapshot():
    """Test clipboard snapshot capture and restore."""
    import pyperclip

    # Set initial clipboard content
    original_text = "Original content"
    pyperclip.copy(original_text)

    # Capture snapshot
    snapshot = PasteboardSnapshot.capture()
    assert snapshot.text == original_text

    # Change clipboard
    new_text = "New content"
    pyperclip.copy(new_text)
    assert pyperclip.paste() == new_text

    # Restore snapshot
    snapshot.restore()
    assert pyperclip.paste() == original_text


@pytest.mark.asyncio
async def test_copy_with_empty_string():
    """Test copying empty string to clipboard."""
    client = ClipboardClient()

    await client.copy("")

    import pyperclip

    clipboard_content = pyperclip.paste()
    assert clipboard_content == ""


@pytest.mark.asyncio
async def test_copy_with_special_characters():
    """Test copying text with special characters."""
    client = ClipboardClient()
    test_text = "Test with \"quotes\" and 'apostrophes' and\n newlines"

    await client.copy(test_text)

    import pyperclip

    clipboard_content = pyperclip.paste()
    assert clipboard_content == test_text


@pytest.mark.asyncio
async def test_pasteboard_snapshot_with_empty_clipboard():
    """Test snapshot when clipboard is empty."""
    import pyperclip

    # Clear clipboard
    pyperclip.copy("")

    # Capture snapshot
    snapshot = PasteboardSnapshot.capture()
    assert snapshot.text == ""

    # Restore should work even with empty content
    snapshot.restore()
    assert pyperclip.paste() == ""
