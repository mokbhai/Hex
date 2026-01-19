"""TranscriptPersistenceClient for saving and managing transcriptions.

This module provides persistence functionality for transcription history.
It mirrors the structure from HexCore/Sources/HexCore/TranscriptPersistenceClient
in the Swift app.

The client handles:
- Saving audio files to persistent storage
- Creating transcript records with metadata
- Deleting audio files when transcripts are removed
- Loading and saving transcription history
- Trimming history to max_history_entries
"""

import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional

from hex.models.transcription import Transcript, TranscriptionHistory
from hex.utils.logging import get_logger, LogCategory


# Module logger
persistence_logger = get_logger(LogCategory.HISTORY)

# History filename
HISTORY_FILENAME = "history.json"


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

    def _get_history_path(self) -> Path:
        """Get the path to the history JSON file.

        Returns:
            Path to the history.json file in Application Support

        Example:
            >>> path = client._get_history_path()
            >>> print(path)
            ~/Library/Application Support/com.kitlangton.Hex/history.json
        """
        if self.app_support_path:
            # Use custom path if provided
            base_path = self.app_support_path
        else:
            # Use default Application Support location
            home = Path.home()
            base_path = home / "Library" / "Application Support" / "com.kitlangton.Hex"

        # Create history file path
        history_path = base_path / HISTORY_FILENAME

        return history_path

    async def load(self) -> list[Transcript]:
        """Load transcription history from disk.

        Reads the history JSON file and deserializes it into a list of
        Transcript objects. If the file doesn't exist or contains invalid
        data, returns an empty list.

        Returns:
            List of Transcript objects representing the history

        Example:
            >>> history = await client.load()
            >>> print(f"Loaded {len(history)} transcripts")
        """
        history_path = self._get_history_path()

        # Check if history file exists
        if not history_path.exists():
            persistence_logger.info("History file not found, returning empty history")
            return []

        try:
            # Read and parse JSON file
            with open(history_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Deserialize list of transcripts
            history = []
            for item in data:
                # Convert timestamp string back to datetime
                item["timestamp"] = datetime.fromisoformat(item["timestamp"])
                # Convert audio_path string back to Path
                item["audio_path"] = Path(item["audio_path"])
                # Create Transcript object
                transcript = Transcript(**item)
                history.append(transcript)

            persistence_logger.debug(f"Loaded {len(history)} transcripts from {history_path}")
            return history

        except json.JSONDecodeError as e:
            persistence_logger.error(f"Invalid JSON in history file: {e}")
            return []

        except (ValueError, KeyError, TypeError) as e:
            persistence_logger.error(f"Error parsing history: {e}")
            return []

        except Exception as e:
            persistence_logger.error(f"Unexpected error loading history: {e}")
            return []

    async def save_history(self, history: list[Transcript]) -> None:
        """Save transcription history to disk.

        Serializes the provided list of Transcript objects to JSON and
        writes it to disk. Creates the configuration directory if it
        doesn't exist.

        Args:
            history: List of Transcript objects to save

        Raises:
            OSError: If unable to write to the history file
            TypeError: If history cannot be serialized to JSON

        Example:
            >>> await client.save_history(history)
        """
        history_path = self._get_history_path()

        try:
            # Ensure directory exists
            history_path.parent.mkdir(parents=True, exist_ok=True)

            # Serialize transcripts to list of dicts
            data = []
            for transcript in history:
                # Convert Transcript to dict
                transcript_dict = {
                    "id": str(transcript.id),
                    "text": transcript.text,
                    "audio_path": str(transcript.audio_path),
                    "duration": transcript.duration,
                    "timestamp": transcript.timestamp.isoformat(),
                    "source_app_bundle_id": transcript.source_app_bundle_id,
                    "source_app_name": transcript.source_app_name,
                }
                data.append(transcript_dict)

            # Atomic write pattern (write to temp, then rename)
            temp_path = history_path.with_suffix(".tmp")
            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            # Atomic rename
            temp_path.replace(history_path)

            persistence_logger.debug(f"Saved {len(history)} transcripts to {history_path}")

        except (TypeError, ValueError) as e:
            persistence_logger.error(f"Error serializing history: {e}")
            raise

        except OSError as e:
            persistence_logger.error(f"Error writing history file: {e}")
            raise

        except Exception as e:
            persistence_logger.error(f"Unexpected error saving history: {e}")
            raise

    async def trim_history(
        self, history: list[Transcript], max_entries: Optional[int]
    ) -> list[Transcript]:
        """Trim history to maximum number of entries.

        Removes oldest entries from the history if it exceeds the maximum
        number of entries. History is sorted by timestamp (newest first)
        before trimming, so the oldest transcripts are removed first.

        Args:
            history: List of Transcript objects to trim
            max_entries: Maximum number of entries to keep. If None, no trimming is performed.

        Returns:
            Trimmed list of Transcript objects

        Example:
            >>> trimmed = await client.trim_history(history, max_entries=100)
            >>> print(f"Trimmed to {len(trimmed)} entries")
        """
        # If max_entries is None or 0, no trimming
        if max_entries is None or max_entries <= 0:
            return history

        # If history is already within limit, no trimming needed
        if len(history) <= max_entries:
            return history

        # Sort by timestamp (newest first) and keep max_entries most recent
        sorted_history = sorted(history, key=lambda t: t.timestamp, reverse=True)
        trimmed_history = sorted_history[:max_entries]

        # Log removed entries
        removed_count = len(history) - len(trimmed_history)
        persistence_logger.info(
            f"Trimmed history from {len(history)} to {len(trimmed_history)} entries "
            f"(removed {removed_count} oldest entries)"
        )

        # Return in original order (oldest first)
        return sorted(trimmed_history, key=lambda t: t.timestamp)


__all__ = ["TranscriptPersistenceClient"]
