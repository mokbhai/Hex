"""TranscriptPersistenceClient for saving and managing transcriptions.

This module provides persistence functionality for transcription history.
It mirrors the structure from HexCore/Sources/HexCore/TranscriptPersistenceClient
in the Swift app.

The client handles:
- Saving audio files to persistent storage
- Creating transcript records with metadata
- Deleting audio files when transcripts are removed
"""

import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional

from hex.models.transcription import Transcript
from hex.utils.logging import get_logger, LogCategory


# Module logger
persistence_logger = get_logger(LogCategory.HISTORY)


class TranscriptPersistenceClient:
    """Client for persisting transcription data.

    This class provides functionality to save audio recordings and their
    associated metadata to persistent storage, and to delete audio files
    when transcripts are removed.

    The client saves audio files to the Application Support directory in
    a "Recordings" subfolder, matching the Swift implementation's behavior.

    Attributes:
        app_support_path: Path to Application Support directory (optional)

    Example:
        >>> client = TranscriptPersistenceClient()
        >>> transcript = await client.save(
        ...     result="Hello world",
        ...     audio_url=Path("/tmp/recording.wav"),
        ...     duration=2.5,
        ...     source_app_bundle_id="com.apple.TextEdit",
        ...     source_app_name="TextEdit"
        ... )
        >>> print(f"Saved transcript: {transcript.id}")
    """

    def __init__(self, app_support_path: Optional[Path] = None) -> None:
        """Initialize the TranscriptPersistenceClient.

        Args:
            app_support_path: Custom Application Support path (optional).
                If not provided, uses the default location:
                ~/Library/Application Support/com.kitlangton.Hex/
        """
        self.app_support_path = app_support_path

    async def save(
        self,
        result: str,
        audio_url: Path,
        duration: float,
        source_app_bundle_id: Optional[str] = None,
        source_app_name: Optional[str] = None,
    ) -> Transcript:
        """Save a transcription recording and create a transcript record.

        This method moves the audio file from its current location to the
        persistent storage directory and creates a Transcript object with
        the provided metadata.

        Args:
            result: The transcribed text
            audio_url: Path to the audio file (will be moved)
            duration: Duration of the audio in seconds
            source_app_bundle_id: Bundle ID of the source app (optional)
            source_app_name: Name of the source app (optional)

        Returns:
            A Transcript object with the saved information

        Raises:
            FileNotFoundError: If the source audio file doesn't exist
            OSError: If the file move operation fails

        Example:
            >>> transcript = await client.save(
            ...     result="This is a test",
            ...     audio_url=Path("/tmp/recording.wav"),
            ...     duration=3.2,
            ...     source_app_bundle_id="com.apple.TextEdit",
            ...     source_app_name="TextEdit"
            ... )
        """
        # Get the recordings directory
        recordings_folder = self._get_recordings_folder()

        # Ensure recordings directory exists
        recordings_folder.mkdir(parents=True, exist_ok=True)

        # Generate filename using timestamp (matching Swift implementation)
        timestamp = datetime.now().timestamp()
        filename = f"{timestamp}.wav"
        final_path = recordings_folder / filename

        try:
            # Move the audio file to persistent storage
            # We use shutil.move instead of Path.rename to handle cross-device moves
            shutil.move(str(audio_url), str(final_path))
            persistence_logger.info(f"Moved audio file from {audio_url} to {final_path}")
        except FileNotFoundError:
            persistence_logger.error(f"Source audio file not found: {audio_url}")
            raise
        except OSError as e:
            persistence_logger.error(f"Failed to move audio file: {e}")
            raise

        # Create and return the transcript
        transcript = Transcript(
            text=result,
            audio_path=final_path,
            duration=duration,
            timestamp=datetime.now(),
            source_app_bundle_id=source_app_bundle_id,
            source_app_name=source_app_name,
        )

        persistence_logger.info(f"Created transcript {transcript.id} with {len(result)} characters")
        return transcript

    async def delete_audio(self, transcript: Transcript) -> None:
        """Delete the audio file associated with a transcript.

        Args:
            transcript: The transcript whose audio should be deleted

        Raises:
            FileNotFoundError: If the audio file doesn't exist
            OSError: If the deletion fails

        Example:
            >>> await client.delete_audio(transcript)
        """
        try:
            # Delete the audio file
            transcript.audio_path.unlink(missing_ok=False)
            persistence_logger.info(f"Deleted audio file: {transcript.audio_path}")
        except FileNotFoundError:
            persistence_logger.warning(f"Audio file not found for deletion: {transcript.audio_path}")
            raise
        except OSError as e:
            persistence_logger.error(f"Failed to delete audio file: {e}")
            raise

    def _get_recordings_folder(self) -> Path:
        """Get the path to the recordings folder.

        Returns:
            Path to the Recordings directory in Application Support

        Example:
            >>> folder = client._get_recordings_folder()
            >>> print(folder)
            ~/Library/Application Support/com.kitlangton.Hex/Recordings
        """
        if self.app_support_path:
            # Use custom path if provided
            base_path = self.app_support_path
        else:
            # Use default Application Support location (matching Swift implementation)
            # On macOS, this is ~/Library/Application Support
            from pathlib import Path

            home = Path.home()
            base_path = home / "Library" / "Application Support" / "com.kitlangton.Hex"

        # Create recordings subfolder path
        recordings_folder = base_path / "Recordings"

        return recordings_folder


__all__ = ["TranscriptPersistenceClient"]
