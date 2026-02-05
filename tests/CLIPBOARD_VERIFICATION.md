# ClipboardClient Verification

## Manual Verification Steps

To verify the ClipboardClient works correctly, run the manual test:

```bash
python3 tests/test_clipboard_manual.py
```

Or test interactively:

```python
import asyncio
import sys
sys.path.insert(0, "src")

from hex.clients.clipboard import ClipboardClient, PasteboardSnapshot

async def test():
    client = ClipboardClient()

    # Test 1: Copy to clipboard
    await client.copy("Hello from Hex!")
    # Verify in any text app: Press Cmd+V

    # Test 2: Snapshot and restore
    await client.copy("Original text")
    snapshot = PasteboardSnapshot.capture()
    await client.copy("New text")
    snapshot.restore()
    # Verify clipboard is back to "Original text"

asyncio.run(test())
```

## Expected Behavior

1. **Copy**: Text should appear in system clipboard
2. **Paste with Clipboard**: Should paste via Cmd+V and restore original clipboard
3. **Snapshot**: Should preserve and restore clipboard state
4. **Special Characters**: Should handle quotes, newlines, etc.

## Implementation Checklist

- ✅ Uses pyperclip for clipboard operations
- ✅ Implements PasteboardSnapshot for clipboard preservation
- ✅ Supports multiple paste strategies (Cmd+V, Menu Item, Typing)
- ✅ Follows Swift PasteboardClient pattern
- ✅ Uses HexLog for logging (LogCategory.PASTEBOARD)
- ✅ Proper error handling
- ✅ Async/await pattern
- ✅ Type hints
- ✅ Docstrings
