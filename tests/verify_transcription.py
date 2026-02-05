#!/usr/bin/env python3
"""Simple verification script for TranscriptionClient.

This script verifies that the TranscriptionClient is properly structured
without requiring an actual Ollama server to be running.
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


def verify_imports():
    """Verify that all imports work correctly."""
    print("✓ Testing imports...")
    try:
        from vox.clients.transcription import (
            TranscriptionClient,
            TranscriptionError,
            OllamaConnectionError,
            ModelNotFoundError,
            DecodingOptions,
            TranscriptionProgress,
        )
        print("  ✓ All imports successful")
        return True
    except ImportError as e:
        print(f"  ✗ Import failed: {e}")
        return False


def verify_client_structure():
    """Verify that TranscriptionClient has all required methods."""
    print("\n✓ Testing client structure...")
    from vox.clients.transcription import TranscriptionClient

    required_methods = [
        "transcribe",
        "is_model_downloaded",
        "_check_ollama_server",
        "_get_available_models",
        "_preprocess_audio",
        "_transcribe_with_ollama",
        "cleanup",
    ]

    for method in required_methods:
        if not hasattr(TranscriptionClient, method):
            print(f"  ✗ Missing method: {method}")
            return False
        print(f"  ✓ Has method: {method}")

    return True


def verify_client_initialization():
    """Verify that TranscriptionClient can be instantiated."""
    print("\n✓ Testing client initialization...")
    from vox.clients.transcription import TranscriptionClient

    try:
        client = TranscriptionClient(
            ollama_host="http://localhost:11434",
            default_model="whisper",
            timeout=30,
        )
        assert client.ollama_host == "http://localhost:11434"
        assert client.default_model == "whisper"
        assert client.timeout == 30
        assert client._http_client is None
        print("  ✓ Client initialized correctly")
        return True
    except Exception as e:
        print(f"  ✗ Initialization failed: {e}")
        return False


def verify_progress_dataclass():
    """Verify that TranscriptionProgress works correctly."""
    print("\n✓ Testing TranscriptionProgress...")
    from vox.clients.transcription import TranscriptionProgress

    try:
        progress = TranscriptionProgress(current=50, total=100, message="Half done")
        assert progress.current == 50
        assert progress.total == 100
        assert progress.message == "Half done"
        assert progress.fraction_completed == 0.5

        # Test zero total edge case
        progress_zero = TranscriptionProgress(current=50, total=0)
        assert progress_zero.fraction_completed == 0.0

        print("  ✓ TranscriptionProgress works correctly")
        return True
    except Exception as e:
        print(f"  ✗ TranscriptionProgress test failed: {e}")
        return False


def verify_decoding_options():
    """Verify that DecodingOptions enum exists."""
    print("\n✓ Testing DecodingOptions...")
    from vox.clients.transcription import DecodingOptions

    try:
        assert hasattr(DecodingOptions, "DEFAULT")
        print("  ✓ DecodingOptions.DEFAULT exists")
        return True
    except Exception as e:
        print(f"  ✗ DecodingOptions test failed: {e}")
        return False


def verify_exceptions():
    """Verify that custom exceptions exist."""
    print("\n✓ Testing custom exceptions...")
    from vox.clients.transcription import (
        TranscriptionError,
        OllamaConnectionError,
        ModelNotFoundError,
    )

    try:
        # Test that exceptions can be raised and caught
        try:
            raise TranscriptionError("Test error")
        except TranscriptionError as e:
            assert str(e) == "Test error"

        try:
            raise OllamaConnectionError("Connection failed")
        except OllamaConnectionError as e:
            assert str(e) == "Connection failed"

        try:
            raise ModelNotFoundError("Model not found")
        except ModelNotFoundError as e:
            assert str(e) == "Model not found"

        print("  ✓ All custom exceptions work correctly")
        return True
    except Exception as e:
        print(f"  ✗ Exception test failed: {e}")
        return False


def verify_api_endpoint():
    """Verify that the correct API endpoint is used."""
    print("\n✓ Testing API endpoint...")
    import inspect
    from vox.clients.transcription import TranscriptionClient

    try:
        # Get the source code of _transcribe_with_ollama
        source = inspect.getsource(TranscriptionClient._transcribe_with_ollama)

        # Check for correct endpoint
        if "/api/transcribe" in source:
            print('  ✓ Uses correct endpoint: /api/transcribe')
        else:
            print('  ✗ Missing or wrong endpoint')
            return False

        # Check for correct response parsing
        if '"text"' in source or "'text'" in source:
            print('  ✓ Parses "text" field from response')
        else:
            print('  ✗ Missing text field parsing')
            return False

        return True
    except Exception as e:
        print(f"  ✗ API endpoint verification failed: {e}")
        return False


def main():
    """Run all verification tests."""
    print("=" * 60)
    print("TranscriptionClient Verification")
    print("=" * 60)

    tests = [
        verify_imports,
        verify_client_structure,
        verify_client_initialization,
        verify_progress_dataclass,
        verify_decoding_options,
        verify_exceptions,
        verify_api_endpoint,
    ]

    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"\n✗ Test failed with exception: {e}")
            results.append(False)

    print("\n" + "=" * 60)
    print(f"Results: {sum(results)}/{len(results)} tests passed")
    print("=" * 60)

    if all(results):
        print("\n✓ All verification tests passed!")
        return 0
    else:
        print("\n✗ Some tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
