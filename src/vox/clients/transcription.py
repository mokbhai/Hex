"""TranscriptionClient for audio transcription using Ollama.

This module provides transcription functionality using the Ollama Python library.
It mirrors the structure from Hex/Clients/TranscriptionClient.swift in the Swift app,
but replaces WhisperKit with Ollama for cross-platform compatibility.

The client handles:
- Ollama server connection management
- Audio file transcription
- Model availability checking
- Audio format preprocessing
"""

import asyncio
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from typing import Optional

import httpx
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample

from vox.utils.logging import get_logger, LogCategory


# Module logger
transcription_logger = get_logger(LogCategory.TRANSCRIPTION)
models_logger = get_logger(LogCategory.MODELS)


class TranscriptionError(Exception):
    """Base exception for transcription errors."""

    pass


class OllamaConnectionError(TranscriptionError):
    """Raised when Ollama server is not available."""

    pass


class ModelNotFoundError(TranscriptionError):
    """Raised when requested model is not available in Ollama."""

    pass


class DecodingOptions(Enum):
    """Decoding options for transcription.

    Matches DecodingOptions from Swift implementation where applicable.
    For Ollama, these are more limited than WhisperKit options.
    """

    DEFAULT = auto()
    # Note: Ollama uses its own decoding options internally
    # We keep this enum for API compatibility with Swift version


@dataclass
class TranscriptionProgress:
    """Progress information for transcription operations.

    Attributes:
        current: Current progress value (0-100)
        total: Total progress value (typically 100)
        message: Optional progress message
    """

    current: float = 0.0
    total: float = 100.0
    message: Optional[str] = None

    @property
    def fraction_completed(self) -> float:
        """Return fraction completed (0.0 to 1.0)."""
        if self.total == 0:
            return 0.0
        return self.current / self.total


class TranscriptionClient:
    """Client for audio transcription using Ollama.

    This class provides async transcription functionality using the Ollama server.
    It handles audio preprocessing, model management, and server connectivity.

    Attributes:
        ollama_host: Host URL for Ollama server (default: http://localhost:11434)
        default_model: Default model to use for transcription (default: whisper)
        timeout: HTTP timeout in seconds (default: 30)

    Example:
        >>> client = TranscriptionClient()
        >>> text = await client.transcribe(
        ...     audio_path="/path/to/audio.wav",
        ...     model="whisper"
        ... )
        >>> print(f"Transcription: {text}")
    """

    def __init__(
        self,
        ollama_host: str = "http://localhost:11434",
        default_model: str = "whisper",
        timeout: int = 30,
    ) -> None:
        """Initialize the TranscriptionClient.

        Args:
            ollama_host: Host URL for Ollama server (default: http://localhost:11434)
            default_model: Default model for transcription (default: whisper)
            timeout: HTTP timeout in seconds (default: 30)
        """
        self.ollama_host = ollama_host
        self.default_model = default_model
        self.timeout = timeout
        self._http_client: Optional[httpx.AsyncClient] = None

    async def transcribe(
        self,
        audio_path: str,
        model: Optional[str] = None,
        options: DecodingOptions = DecodingOptions.DEFAULT,
        progress_callback: Optional[callable] = None,
    ) -> str:
        """Transcribe an audio file using Ollama.

        Args:
            audio_path: Path to audio file to transcribe
            model: Model name to use (default: whisper or client default)
            options: Decoding options (for API compatibility)
            progress_callback: Optional callback for progress updates

        Returns:
            Transcribed text

        Raises:
            OllamaConnectionError: If Ollama server is not available
            ModelNotFoundError: If requested model is not available
            TranscriptionError: For other transcription errors

        Example:
            >>> text = await client.transcribe(
            ...     audio_path="/path/to/audio.wav",
            ...     model="whisper"
            ... )
        """
        model = model or self.default_model

        try:
            # Check Ollama server connection first
            await self._check_ollama_server()

            # Check if model is available
            if not await self.is_model_downloaded(model):
                raise ModelNotFoundError(
                    f"Model '{model}' is not available in Ollama. "
                    f"Please run: ollama pull {model}"
                )

            # Report initial progress
            if progress_callback:
                progress_callback(
                    TranscriptionProgress(current=0, message="Starting transcription")
                )

            # Preprocess audio if needed
            processed_path = await self._preprocess_audio(audio_path)

            # Report preprocessing complete
            if progress_callback:
                progress_callback(
                    TranscriptionProgress(current=50, message="Transcribing audio")
                )

            # Perform transcription
            text = await self._transcribe_with_ollama(processed_path, model)

            # Report completion
            if progress_callback:
                progress_callback(
                    TranscriptionProgress(current=100, message="Transcription complete")
                )

            transcription_logger.info(f"Transcription completed for {audio_path}")

            return text

        except OllamaConnectionError:
            raise
        except ModelNotFoundError:
            raise
        except Exception as e:
            transcription_logger.error(f"Transcription failed: {e}")
            raise TranscriptionError(f"Transcription failed: {e}") from e

    async def is_model_downloaded(self, model_name: str) -> bool:
        """Check if a model is available in Ollama.

        Args:
            model_name: Name of the model to check

        Returns:
            True if model is available, False otherwise

        Example:
            >>> available = await client.is_model_downloaded("whisper")
            >>> if available:
            ...     print("Whisper model is ready")
        """
        try:
            # First ensure server is running
            await self._check_ollama_server()

            # Get list of available models
            models = await self._get_available_models()

            # Check if requested model is in the list
            is_available = any(model_name in model.get("name", "") for model in models)

            models_logger.debug(f"Model {model_name} available: {is_available}")

            return is_available

        except OllamaConnectionError:
            # Server not running, model not available
            return False
        except Exception as e:
            models_logger.error(f"Error checking model availability: {e}")
            return False

    async def _check_ollama_server(self) -> bool:
        """Check if Ollama server is running and accessible.

        Returns:
            True if server is accessible

        Raises:
            OllamaConnectionError: If server is not available with helpful error message

        Example:
            >>> try:
            ...     await client._check_ollama_server()
            ...     print("Ollama server is running")
            ... except OllamaConnectionError:
            ...     print("Ollama server is not available")
        """
        try:
            # Create HTTP client if needed
            if self._http_client is None:
                self._http_client = httpx.AsyncClient(timeout=self.timeout)

            # Try to ping Ollama server
            response = await self._http_client.get(f"{self.ollama_host}/api/tags")

            if response.status_code == 200:
                transcription_logger.debug("Ollama server is accessible")
                return True
            else:
                raise OllamaConnectionError(
                    f"Ollama server returned unexpected status {response.status_code}. "
                    f"Expected 200 OK. Server URL: {self.ollama_host}"
                )

        except httpx.ConnectError as e:
            # Connection refused - server not running or wrong address
            error_msg = (
                "Cannot connect to Ollama server.\n\n"
                f"  Server URL: {self.ollama_host}\n\n"
                "Possible solutions:\n"
                "  1. Start Ollama server: run 'ollama serve' in a terminal\n"
                "  2. Verify Ollama is installed: visit https://ollama.ai/download\n"
                "  3. Check if the server URL is correct\n"
                "  4. Ensure no firewall is blocking port 11434"
            )
            raise OllamaConnectionError(error_msg) from e

        except httpx.TimeoutException:
            # Server took too long to respond
            error_msg = (
                "Ollama server connection timed out.\n\n"
                f"  Server URL: {self.ollama_host}\n"
                f"  Timeout: {self.timeout} seconds\n\n"
                "Possible solutions:\n"
                "  1. Check if Ollama server is running: 'ollama serve'\n"
                "  2. Verify the server is responding: curl http://localhost:11434/api/tags\n"
                "  3. Check system resources - server may be overloaded"
            )
            raise OllamaConnectionError(error_msg)

        except httpx.HTTPStatusError as e:
            # Server responded but with an error status
            error_msg = (
                f"Ollama server returned error status {e.response.status_code}.\n\n"
                f"  Server URL: {self.ollama_host}\n\n"
                "Possible solutions:\n"
                "  1. Restart Ollama server\n"
                "  2. Check Ollama logs for errors\n"
                "  3. Ensure you're using a compatible version of Ollama"
            )
            raise OllamaConnectionError(error_msg) from e

        except Exception as e:
            # Catch-all for other errors (network issues, etc.)
            error_msg = (
                f"Failed to connect to Ollama server: {type(e).__name__}: {e}\n\n"
                f"  Server URL: {self.ollama_host}\n\n"
                "Troubleshooting:\n"
                "  1. Ensure Ollama is installed and running\n"
                "  2. Test connection: curl http://localhost:11434/api/tags\n"
                "  3. Check network settings and firewall\n"
                "  4. Try restarting Ollama server"
            )
            raise OllamaConnectionError(error_msg) from e

    async def _get_available_models(self) -> list[dict]:
        """Get list of available models from Ollama.

        Returns:
            List of model dictionaries with 'name' and other metadata

        Raises:
            OllamaConnectionError: If server is not available
        """
        try:
            if self._http_client is None:
                self._http_client = httpx.AsyncClient(timeout=self.timeout)

            response = await self._http_client.get(f"{self.ollama_host}/api/tags")
            response.raise_for_status()

            data = response.json()
            models = data.get("models", [])

            models_logger.debug(f"Found {len(models)} available models")

            return models

        except httpx.HTTPError as e:
            models_logger.error(f"Failed to get available models: {e}")
            raise OllamaConnectionError(f"Failed to get models: {e}") from e

    async def _preprocess_audio(self, audio_path: str) -> str:
        """Preprocess audio file for Ollama transcription.

        Ensures audio is in correct format (16kHz mono WAV) for optimal transcription.
        If the file is already in correct format, returns the original path.

        Args:
            audio_path: Path to audio file

        Returns:
            Path to processed audio file (may be same as input)

        Raises:
            TranscriptionError: If audio file cannot be processed
        """
        target_sample_rate = 16000  # 16kHz

        try:
            # Read audio file
            audio_path_obj = Path(audio_path)

            if not audio_path_obj.exists():
                raise TranscriptionError(f"Audio file not found: {audio_path}")

            # Read the WAV file
            try:
                sample_rate, audio_data = wavfile.read(audio_path)
            except Exception as e:
                transcription_logger.error(f"Failed to read audio file: {e}")
                raise TranscriptionError(f"Failed to read audio file: {e}") from e

            transcription_logger.debug(
                f"Audio info: sample_rate={sample_rate}, "
                f"shape={audio_data.shape}, dtype={audio_data.dtype}"
            )

            # Check if conversion is needed
            needs_conversion = False

            # Check sample rate
            if sample_rate != target_sample_rate:
                transcription_logger.debug(
                    f"Sample rate {sample_rate}Hz != {target_sample_rate}Hz, resampling needed"
                )
                needs_conversion = True

            # Check if stereo (needs conversion to mono)
            if len(audio_data.shape) > 1:
                transcription_logger.debug(f"Audio is stereo ({audio_data.shape[1]} channels), converting to mono")
                needs_conversion = True

            # If no conversion needed, return original path
            if not needs_conversion:
                transcription_logger.debug("Audio is already in correct format (16kHz mono)")
                return audio_path

            # Perform conversion
            transcription_logger.info("Converting audio to 16kHz mono WAV format")

            # Convert to mono if stereo
            if len(audio_data.shape) > 1:
                # Average channels to create mono
                audio_data = np.mean(audio_data, axis=1, dtype=audio_data.dtype)

            # Resample if needed
            if sample_rate != target_sample_rate:
                # Calculate number of samples for target sample rate
                duration_seconds = len(audio_data) / sample_rate
                target_length = int(duration_seconds * target_sample_rate)

                # Resample using scipy
                audio_data = resample(audio_data, target_length)

                # Convert back to original dtype (usually int16)
                if audio_data.dtype != np.int16:
                    # Normalize and convert to int16
                    audio_data = np.clip(audio_data, -1.0, 1.0)
                    audio_data = (audio_data * 32767).astype(np.int16)

            # Create temporary file for converted audio
            import tempfile

            with tempfile.NamedTemporaryFile(
                suffix=".wav", delete=False, prefix="hex_audio_"
            ) as temp_file:
                temp_path = temp_file.name

            # Write the converted audio
            wavfile.write(temp_path, target_sample_rate, audio_data)

            transcription_logger.info(f"Audio converted and saved to {temp_path}")

            return temp_path

        except TranscriptionError:
            raise
        except Exception as e:
            transcription_logger.error(f"Audio preprocessing failed: {e}")
            raise TranscriptionError(f"Audio preprocessing failed: {e}") from e

    async def _transcribe_with_ollama(self, audio_path: str, model: str) -> str:
        """Perform transcription using Ollama API.

        Args:
            audio_path: Path to audio file
            model: Model name to use

        Returns:
            Transcribed text

        Raises:
            TranscriptionError: If transcription fails
        """
        try:
            if self._http_client is None:
                self._http_client = httpx.AsyncClient(timeout=self.timeout)

            # Read audio file
            audio_path_obj = Path(audio_path)
            if not audio_path_obj.exists():
                raise TranscriptionError(f"Audio file not found: {audio_path}")

            # Ollama API expects multipart form data with audio file
            with open(audio_path, "rb") as audio_file:
                files = {
                    "file": (audio_path_obj.name, audio_file, "audio/wav")
                }

                data = {
                    "model": model,
                }

                response = await self._http_client.post(
                    f"{self.ollama_host}/api/transcribe",
                    files=files,
                    data=data,
                )

            response.raise_for_status()

            # Parse response - Ollama's /api/transcribe returns "text" field
            result = response.json()
            text = result.get("text", "").strip()

            if not text:
                transcription_logger.warning("Empty transcription returned")

            return text

        except httpx.HTTPError as e:
            transcription_logger.error(f"HTTP error during transcription: {e}")
            raise TranscriptionError(f"Transcription HTTP error: {e}") from e
        except Exception as e:
            transcription_logger.error(f"Error during transcription: {e}")
            raise TranscriptionError(f"Transcription failed: {e}") from e

    async def cleanup(self) -> None:
        """Release transcription client resources.

        Should be called on app termination to properly clean up resources.
        """
        if self._http_client is not None:
            await self._http_client.aclose()
            self._http_client = None

        transcription_logger.info("TranscriptionClient cleaned up")
