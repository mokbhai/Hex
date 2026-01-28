"""Tests for TranscriptionClient."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from pathlib import Path
import httpx

from vox.clients.transcription import (
    TranscriptionClient,
    TranscriptionError,
    OllamaConnectionError,
    ModelNotFoundError,
    DecodingOptions,
    TranscriptionProgress,
)


@pytest.fixture
def transcription_client():
    """Provide a TranscriptionClient instance for testing."""
    return TranscriptionClient(
        ollama_host="http://localhost:11434",
        default_model="whisper",
        timeout=30,
    )


@pytest.fixture
def mock_http_client():
    """Provide a mocked HTTP client."""
    client = AsyncMock(spec=httpx.AsyncClient)
    return client


class TestTranscriptionClient:
    """Test suite for TranscriptionClient."""

    def test_client_initialization(self, transcription_client):
        """Test that client initializes correctly."""
        assert transcription_client.ollama_host == "http://localhost:11434"
        assert transcription_client.default_model == "whisper"
        assert transcription_client.timeout == 30
        assert transcription_client._http_client is None

    @pytest.mark.asyncio
    async def test_check_ollama_server_success(self, transcription_client, mock_http_client):
        """Test successful Ollama server connection check."""
        # Mock successful response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.get.return_value = mock_response

        transcription_client._http_client = mock_http_client

        # Should not raise any exception
        result = await transcription_client._check_ollama_server()
        assert result is True

        # Verify correct endpoint was called
        mock_http_client.get.assert_called_once_with("http://localhost:11434/api/tags")

    @pytest.mark.asyncio
    async def test_check_ollama_server_connection_error(self, transcription_client):
        """Test Ollama server connection error handling."""
        transcription_client._http_client = AsyncMock()

        # Mock connection error
        transcription_client._http_client.get.side_effect = httpx.ConnectError("Connection refused")

        with pytest.raises(OllamaConnectionError) as exc_info:
            await transcription_client._check_ollama_server()

        assert "Cannot connect to Ollama server" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_is_model_downloaded_true(self, transcription_client, mock_http_client):
        """Test is_model_downloaded returns True when model exists."""
        # Mock successful model list response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.get.return_value = mock_response
        mock_http_client.get.return_value.json.return_value = {
            "models": [{"name": "whisper"}]
        }

        transcription_client._http_client = mock_http_client

        result = await transcription_client.is_model_downloaded("whisper")
        assert result is True

    @pytest.mark.asyncio
    async def test_is_model_downloaded_false(self, transcription_client, mock_http_client):
        """Test is_model_downloaded returns False when model doesn't exist."""
        # Mock successful model list response without the model
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.get.return_value = mock_response
        mock_http_client.get.return_value.json.return_value = {
            "models": [{"name": "other-model"}]
        }

        transcription_client._http_client = mock_http_client

        result = await transcription_client.is_model_downloaded("whisper")
        assert result is False

    @pytest.mark.asyncio
    async def test_preprocess_audio_placeholder(self, transcription_client, tmp_path):
        """Test that _preprocess_audio currently returns original path (placeholder for subtask-6-4)."""
        audio_file = tmp_path / "test.wav"
        audio_file.write_text("fake audio")

        result = await transcription_client._preprocess_audio(str(audio_file))

        # Currently just returns the original path
        assert result == str(audio_file)

    @pytest.mark.asyncio
    async def test_transcribe_model_not_found(self, transcription_client, mock_http_client):
        """Test transcribe raises error when model is not available."""
        # Mock server available but model not in list
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.get.return_value = mock_response
        mock_http_client.get.return_value.json.return_value = {"models": []}

        transcription_client._http_client = mock_http_client

        with pytest.raises(ModelNotFoundError) as exc_info:
            await transcription_client.transcribe("test.wav", model="whisper")

        assert "not available in Ollama" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_transcribe_with_ollama_success(
        self, transcription_client, mock_http_client, tmp_path
    ):
        """Test successful transcription with Ollama."""
        # Create a fake audio file
        audio_file = tmp_path / "test.wav"
        audio_file.write_text("fake audio content")

        # Mock successful transcription response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.post.return_value = mock_response
        mock_http_client.post.return_value.json.return_value = {"text": "Hello world"}

        transcription_client._http_client = mock_http_client

        result = await transcription_client._transcribe_with_ollama(str(audio_file), "whisper")

        assert result == "Hello world"

        # Verify correct endpoint and data
        mock_http_client.post.assert_called_once()
        call_args = mock_http_client.post.call_args
        assert "api/transcribe" in call_args[0][0]

    @pytest.mark.asyncio
    async def test_transcribe_with_ollama_empty_response(
        self, transcription_client, mock_http_client, tmp_path
    ):
        """Test transcription with empty response from Ollama."""
        # Create a fake audio file
        audio_file = tmp_path / "test.wav"
        audio_file.write_text("fake audio content")

        # Mock empty transcription response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_client.post.return_value = mock_response
        mock_http_client.post.return_value.json.return_value = {"text": ""}

        transcription_client._http_client = mock_http_client

        result = await transcription_client._transcribe_with_ollama(str(audio_file), "whisper")

        # Should return empty string, not raise error
        assert result == ""

    @pytest.mark.asyncio
    async def test_transcribe_with_ollama_file_not_found(self, transcription_client):
        """Test transcription with non-existent audio file."""
        with pytest.raises(TranscriptionError) as exc_info:
            await transcription_client._transcribe_with_ollama("/nonexistent/file.wav", "whisper")

        assert "not found" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_cleanup(self, transcription_client, mock_http_client):
        """Test cleanup closes HTTP client."""
        transcription_client._http_client = mock_http_client

        await transcription_client.cleanup()

        assert transcription_client._http_client is None
        mock_http_client.aclose.assert_called_once()


class TestTranscriptionProgress:
    """Test suite for TranscriptionProgress."""

    def test_progress_initialization(self):
        """Test progress dataclass initialization."""
        progress = TranscriptionProgress(current=50, total=100, message="Half done")
        assert progress.current == 50
        assert progress.total == 100
        assert progress.message == "Half done"

    def test_fraction_completed(self):
        """Test fraction_completed calculation."""
        progress = TranscriptionProgress(current=75, total=100)
        assert progress.fraction_completed == 0.75

    def test_fraction_completed_zero_total(self):
        """Test fraction_completed with zero total."""
        progress = TranscriptionProgress(current=50, total=0)
        assert progress.fraction_completed == 0.0


class TestDecodingOptions:
    """Test suite for DecodingOptions enum."""

    def test_decoding_options_enum(self):
        """Test DecodingOptions enum exists."""
        assert DecodingOptions.DEFAULT is not None
        # For Ollama, we keep it simple - just DEFAULT option
        assert hasattr(DecodingOptions, "DEFAULT")
