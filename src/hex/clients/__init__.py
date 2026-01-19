"""Client implementations for Hex.

This package contains client implementations that handle various system interactions:
- RecordingClient: Audio recording using sounddevice
- KeyEventMonitorClient: Global keyboard and mouse event monitoring
- TranscriptionClient: Speech-to-text transcription
- TranscriptPersistenceClient: Saving and managing transcriptions
- ClipboardClient: System clipboard operations
"""

from hex.clients.key_event_monitor import (
    KeyEventMonitorClient,
    KeyEventMonitorToken,
    create_key_event_monitor,
)
from hex.clients.recording import (
    AudioInputDevice,
    Meter,
    RecordingClient,
)
from hex.clients.transcript_persistence import (
    TranscriptPersistenceClient,
)

__all__ = [
    "RecordingClient",
    "AudioInputDevice",
    "Meter",
    "KeyEventMonitorClient",
    "KeyEventMonitorToken",
    "create_key_event_monitor",
    "TranscriptPersistenceClient",
]
