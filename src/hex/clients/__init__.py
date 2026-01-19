"""Client implementations for Hex.

This package contains client implementations that handle various system interactions:
- RecordingClient: Audio recording using sounddevice
- TranscriptionClient: Speech-to-text transcription
- ClipboardClient: System clipboard operations
"""

from hex.clients.recording import (
    AudioInputDevice,
    Meter,
    RecordingClient,
)

__all__ = [
    "RecordingClient",
    "AudioInputDevice",
    "Meter",
]
