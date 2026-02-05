#!/usr/bin/env python3
"""Verification script for TranscriptPersistenceClient history loading and trimming."""

import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from vox.clients.transcript_persistence import TranscriptPersistenceClient


async def verify_load():
    """Verify that load() method works correctly."""
    print("Testing TranscriptPersistenceClient.load()...")

    # Create client
    tpc = TranscriptPersistenceClient()

    # Load history
    history = await tpc.load()

    print(f"✓ History size: {len(history)}")

    # Verify it returns a list
    assert isinstance(history, list), "load() should return a list"
    print("✓ load() returns a list")

    # Verify all items are Transcript objects (if any)
    for item in history:
        from vox.models.transcription import Transcript
        assert isinstance(item, Transcript), f"History items should be Transcript objects, got {type(item)}"
    print("✓ All history items are Transcript objects")

    return len(history)


async def verify_trim():
    """Verify that trim_history() method works correctly."""
    print("\nTesting TranscriptPersistenceClient.trim_history()...")

    from vox.models.transcription import Transcript
    from datetime import datetime, timedelta
    from uuid import uuid4

    # Create client
    tpc = TranscriptPersistenceClient()

    # Create test history with 10 items
    history = []
    base_time = datetime.now()

    for i in range(10):
        transcript = Transcript(
            text=f"Test transcript {i}",
            audio_path=Path(f"/tmp/test{i}.wav"),
            duration=1.0,
            timestamp=base_time + timedelta(seconds=i),
            id=uuid4(),
        )
        history.append(transcript)

    print(f"✓ Created test history with {len(history)} items")

    # Test trimming to 5 entries
    trimmed = await tpc.trim_history(history, max_entries=5)

    assert len(trimmed) == 5, f"Expected 5 items after trimming, got {len(trimmed)}"
    print(f"✓ Trimmed history to {len(trimmed)} items")

    # Verify oldest items were removed
    # Items should be sorted by timestamp (oldest first after trimming)
    assert trimmed[0].text == "Test transcript 5", "Oldest items should be removed"
    assert trimmed[-1].text == "Test transcript 9", "Newest items should be kept"
    print("✓ Oldest entries were correctly removed")

    # Test with None max_entries (no trimming)
    not_trimmed = await tpc.trim_history(history, max_entries=None)
    assert len(not_trimmed) == 10, "Should not trim when max_entries is None"
    print("✓ No trimming when max_entries is None")

    # Test with zero max_entries (no trimming)
    not_trimmed = await tpc.trim_history(history, max_entries=0)
    assert len(not_trimmed) == 10, "Should not trim when max_entries is 0"
    print("✓ No trimming when max_entries is 0")

    # Test when history is already within limit
    small_history = history[:3]
    not_trimmed = await tpc.trim_history(small_history, max_entries=5)
    assert len(not_trimmed) == 3, "Should not trim when already within limit"
    print("✓ No trimming when history is already within limit")


async def verify_save_load_roundtrip():
    """Verify that save_history() and load() work together."""
    print("\nTesting save_history() and load() roundtrip...")

    from vox.models.transcription import Transcript
    from datetime import datetime
    from uuid import uuid4
    import tempfile
    import shutil

    # Create client with temp directory
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        tpc = TranscriptPersistenceClient(app_support_path=tmp_path)

        # Create test history
        history = []
        for i in range(3):
            transcript = Transcript(
                text=f"Test transcript {i}",
                audio_path=tmp_path / f"test{i}.wav",
                duration=1.0,
                timestamp=datetime.now(),
                id=uuid4(),
            )
            history.append(transcript)

        # Save history
        await tpc.save_history(history)
        print("✓ Saved history to disk")

        # Load history
        loaded_history = await tpc.load()
        assert len(loaded_history) == 3, f"Expected 3 items, got {len(loaded_history)}"
        print(f"✓ Loaded history from disk: {len(loaded_history)} items")

        # Verify content
        for i, loaded in enumerate(loaded_history):
            assert loaded.text == f"Test transcript {i}", f"Expected 'Test transcript {i}', got '{loaded.text}'"
        print("✓ History content preserved correctly")


async def main():
    """Run all verification tests."""
    print("=" * 60)
    print("TranscriptPersistenceClient Verification")
    print("=" * 60)

    try:
        # Test load()
        history_size = await verify_load()

        # Test trim_history()
        await verify_trim()

        # Test save/load roundtrip
        await verify_save_load_roundtrip()

        print("\n" + "=" * 60)
        print("✓ All verification tests passed!")
        print("=" * 60)
        return 0

    except Exception as e:
        print("\n" + "=" * 60)
        print(f"✗ Verification failed: {e}")
        print("=" * 60)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
