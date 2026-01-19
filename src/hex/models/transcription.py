"""
Data models for transcription history.

These models mirror the Swift implementation in HexCore.
"""
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional
from uuid import UUID, uuid4


@dataclass
class Transcript:
    """Represents a single transcription with its metadata.

    Attributes:
        id: Unique identifier for the transcript
        timestamp: When the transcription was created
        text: The transcribed text
        audio_path: Path to the audio file
        duration: Duration of the audio in seconds
        source_app_bundle_id: Bundle ID of the app where text was pasted
        source_app_name: Name of the app where text was pasted

    Examples:
        >>> from datetime import datetime
        >>> t = Transcript(
        ...     text="Hello world",
        ...     duration=2.5,
        ...     audio_path=Path("/tmp/audio.wav"),
        ...     timestamp=datetime.now()
        ... )
    """

    text: str
    audio_path: Path
    duration: float
    timestamp: datetime
    id: UUID = field(default_factory=uuid4)
    source_app_bundle_id: Optional[str] = None
    source_app_name: Optional[str] = None


@dataclass
class TranscriptionHistory:
    """Container for transcription history.

    Attributes:
        history: List of transcripts

    Examples:
        >>> history = TranscriptionHistory()
        >>> history.history.append(Transcript(
        ...     text="Test",
        ...     duration=1.0,
        ...     audio_path=Path("/tmp/test.wav"),
        ...     timestamp=datetime.now()
        ... ))
    """

    history: list[Transcript] = field(default_factory=list)
