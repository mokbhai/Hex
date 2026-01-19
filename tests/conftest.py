"""Pytest configuration and fixtures."""

import pytest
import sys
from pathlib import Path


# Add src directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


@pytest.fixture
def temp_dir(tmp_path):
    """Provide a temporary directory for test files."""
    return tmp_path


@pytest.fixture
def sample_audio_file(tmp_path):
    """Provide a sample audio file for testing."""
    # This will be implemented when we add audio recording tests
    audio_path = tmp_path / "test_audio.wav"
    return audio_path
