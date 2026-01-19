#!/usr/bin/env python3
"""Manual test for ClipboardClient."""

import sys
import asyncio

sys.path.insert(0, "src")

from hex.clients.clipboard import ClipboardClient, PasteboardSnapshot


async def main():
    print("Testing ClipboardClient...")

    # Test 1: Copy to clipboard
    print("\n1. Testing copy to clipboard...")
    client = ClipboardClient()
    test_text = "Hello, Clipboard!"
    await client.copy(test_text)
    print(f"   ✓ Copied: '{test_text}'")
    print(f"   Please verify clipboard contains: '{test_text}'")

    # Test 2: Pasteboard snapshot
    print("\n2. Testing PasteboardSnapshot...")
    original_text = "Original content"
    await client.copy(original_text)
    snapshot = PasteboardSnapshot.capture()
    print(f"   ✓ Captured snapshot: '{snapshot.text}'")

    # Change clipboard
    new_text = "New content"
    await client.copy(new_text)
    print(f"   ✓ Changed clipboard to: '{new_text}'")

    # Restore
    snapshot.restore()
    print(f"   ✓ Restored snapshot")
    print(f"   Please verify clipboard contains: '{original_text}'")

    # Test 3: Special characters
    print("\n3. Testing special characters...")
    special_text = 'Test with "quotes" and \'apostrophes\' and\nnewlines'
    await client.copy(special_text)
    print(f"   ✓ Copied special text")
    print(f"   Please verify clipboard contains special characters")

    print("\n✅ All clipboard tests completed!")
    print("Please manually verify the clipboard content in your favorite app.")


if __name__ == "__main__":
    asyncio.run(main())
