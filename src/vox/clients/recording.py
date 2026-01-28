"""RecordingClient for audio recording using sounddevice.

This module provides audio recording functionality using the sounddevice library.
It mirrors the structure from Hex/Clients/RecordingClient.swift in the Swift app.

The client handles:
- Audio recording from microphone
- Audio level monitoring (metering)
- Device enumeration and selection
- Microphone permission handling
- Recording warmup for faster startup
"""

import asyncio
import queue
import tempfile
import threading
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from typing import AsyncGenerator, Optional

import numpy as np
import sounddevice as sd

from vox.utils.logging import get_logger, LogCategory


# Module logger
recording_logger = get_logger(LogCategory.RECORDING)


@dataclass
class AudioInputDevice:
    """Represents an audio input device.

    Attributes:
        id: Device identifier (index for sounddevice)
        name: Human-readable device name
    """

    id: str
    name: str


@dataclass
class Meter:
    """Simple structure representing audio metering values.

    Attributes:
        averagePower: Average power level (0.0 to 1.0)
        peakPower: Peak power level (0.0 to 1.0)
    """

    averagePower: float
    peakPower: float


class RecordingAudioBehavior(Enum):
    """Defines how the app handles audio during recording.

    Matches RecordingAudioBehavior from Swift implementation.
    """

    PAUSE_MEDIA = auto()
    MUTE = auto()
    DO_NOTHING = auto()


class RecordingClient:
    """Client for audio recording using sounddevice.

    This class provides async audio recording functionality with device management,
    audio level monitoring, and proper resource cleanup.

    Attributes:
        sample_rate: Audio sample rate in Hz (default: 16000 for speech recognition)
        channels: Number of audio channels (default: 1 for mono)
        dtype: NumPy data type for audio samples (default: float32)

    Example:
        >>> client = RecordingClient()
        >>> await client.start_recording()
        >>> # ... do some work ...
        >>> recording_url = await client.stop_recording()
        >>> print(f"Recording saved to: {recording_url}")
    """

    def __init__(
        self,
        sample_rate: int = 16000,
        channels: int = 1,
        dtype: type = np.float32,
    ) -> None:
        """Initialize the RecordingClient.

        Args:
            sample_rate: Audio sample rate in Hz (default: 16000)
            channels: Number of audio channels (default: 1)
            dtype: NumPy data type for audio samples (default: np.float32)
        """
        self.sample_rate = sample_rate
        self.channels = channels
        self.dtype = dtype

        # Recording state
        self._is_recording = False
        self._recording_stream: Optional[sd.InputStream] = None
        self._recording_data: list[np.ndarray] = []
        self._recording_file: Optional[Path] = None

        # Audio level monitoring
        self._audio_queue: queue.Queue[np.ndarray] = queue.Queue(maxsize=10)
        self._meter_task: Optional[asyncio.Task] = None
        self._meter_stop_event = threading.Event()
        self._meter_queue: asyncio.Queue[Meter] = asyncio.Queue(maxsize=10)

        # Device management
        self._selected_device_id: Optional[int] = None
        self._is_warmed_up = False

    async def start_recording(self) -> None:
        """Start audio recording.

        Creates a new recording session and begins capturing audio from the
        selected input device (or system default if none selected).

        Raises:
            RuntimeError: If recording is already in progress
        """
        if self._is_recording:
            recording_logger.error("Recording is already in progress")
            raise RuntimeError("Recording is already in progress")

        # Clear previous recording data
        self._recording_data = []

        # Clear meter queue from previous recording
        while not self._meter_queue.empty():
            try:
                self._meter_queue.get_nowait()
            except asyncio.QueueEmpty:
                break

        # Determine which device to use
        device_id = self._selected_device_id

        try:
            # Create audio input stream
            self._recording_stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=self.channels,
                dtype=self.dtype,
                device=device_id,
                callback=self._audio_callback,
            )

            # Start recording
            self._recording_stream.start()
            self._is_recording = True

            # Start meter task for audio level monitoring
            self._meter_stop_event.clear()
            self._meter_task = asyncio.create_task(self._monitor_audio_levels())

            recording_logger.info("Recording started")

        except Exception as e:
            recording_logger.error(f"Failed to start recording: {e}")
            self._cleanup_recording_resources()
            raise

    async def stop_recording(self) -> str:
        """Stop audio recording and save to file.

        Stops the current recording session, writes the captured audio to a
        temporary WAV file, and returns the file path.

        Returns:
            Path to the recorded audio file

        Raises:
            RuntimeError: If no recording is in progress
        """
        if not self._is_recording:
            recording_logger.warning("stop_recording() called while no recording was active")
            # Return empty path for consistency with Swift implementation
            return ""

        # Stop the recording stream
        if self._recording_stream is not None:
            self._recording_stream.stop()
            self._recording_stream.close()
            self._recording_stream = None

        # Stop meter task
        self._meter_stop_event.set()
        if self._meter_task is not None:
            try:
                await asyncio.wait_for(self._meter_task, timeout=1.0)
            except asyncio.TimeoutError:
                recording_logger.warning("Meter task did not stop in time")
            self._meter_task = None

        self._is_recording = False

        # Save recording to file
        try:
            recording_path = self._save_recording()
            recording_logger.info(f"Recording stopped and saved to: {recording_path}")
            return str(recording_path)
        except Exception as e:
            recording_logger.error(f"Failed to save recording: {e}")
            # Clean up resources even if save failed
            self._cleanup_recording_resources()
            raise

    async def request_microphone_access(self) -> bool:
        """Request microphone access from the user.

        On macOS, this will trigger the system permission prompt if not already granted.
        The actual permission is handled by the OS when we try to create an audio stream.

        Returns:
            True if microphone access is available, False otherwise
        """
        try:
            # Try to create a temporary stream to check permissions
            # This will trigger the permission dialog on macOS if needed
            test_stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=self.channels,
                dtype=self.dtype,
            )
            test_stream.close()
            recording_logger.info("Microphone access granted")
            return True
        except Exception as e:
            recording_logger.error(f"Microphone access denied: {e}")
            return False

    async def observe_audio_level(self) -> AsyncGenerator[Meter, None]:
        """Monitor audio levels during recording.

        Yields meter values approximately 10 times per second while recording.
        The meter contains average and peak power levels.

        Yields:
            Meter with current audio level information

        Example:
            >>> async for meter in client.observe_audio_level():
            ...     print(f"Avg: {meter.averagePower:.2f}, Peak: {meter.peakPower:.2f}")
        """
        while not self._meter_stop_event.is_set():
            try:
                # Get meter from queue (with timeout)
                try:
                    meter = await asyncio.wait_for(self._meter_queue.get(), timeout=0.2)
                    yield meter
                except asyncio.TimeoutError:
                    # No new meter data, yield zero meter
                    yield Meter(averagePower=0.0, peakPower=0.0)

            except asyncio.CancelledError:
                break
            except Exception as e:
                recording_logger.error(f"Error monitoring audio levels: {e}")
                break

    async def get_available_input_devices(self) -> list[AudioInputDevice]:
        """Get all available audio input devices.

        Queries the system for all audio devices that have input capabilities.

        Returns:
            List of available input devices

        Example:
            >>> devices = await client.get_available_input_devices()
            >>> for device in devices:
            ...     print(f"{device.id}: {device.name}")
        """
        devices = []

        try:
            # Query all devices
            device_list = sd.query_devices()

            for idx, device_info in enumerate(device_list):
                # Check if device has input channels
                if device_info["max_input_channels"] > 0:
                    device = AudioInputDevice(
                        id=str(idx),
                        name=device_info["name"],
                    )
                    devices.append(device)

            recording_logger.debug(f"Found {len(devices)} input devices")

        except Exception as e:
            recording_logger.error(f"Failed to query input devices: {e}")

        return devices

    async def get_default_input_device_name(self) -> Optional[str]:
        """Get the system default input device name.

        Returns:
            Name of the default input device, or None if not found
        """
        try:
            default_device = sd.query_devices(kind="input")
            return default_device["name"]
        except Exception as e:
            recording_logger.error(f"Failed to query default input device: {e}")
            return None

    def set_input_device(self, device_id: str) -> None:
        """Set the audio input device to use for recording.

        Args:
            device_id: Device identifier (string representation of index)

        Example:
            >>> await client.set_input_device("1")  # Use device at index 1
        """
        try:
            idx = int(device_id)
            device = sd.query_devices(idx)

            if device["max_input_channels"] == 0:
                recording_logger.error(f"Device {device_id} has no input channels")
                return

            self._selected_device_id = idx
            recording_logger.info(f"Input device set to: {device['name']}")

        except (ValueError, Exception) as e:
            recording_logger.error(f"Failed to set input device {device_id}: {e}")

    async def warm_up_recorder(self) -> None:
        """Warm up the recorder for faster startup.

        Pre-allocates resources and initializes the audio subsystem to reduce
        latency when recording actually starts.

        This method can be called during app initialization to improve
        the responsiveness of the first recording.
        """
        if self._is_warmed_up:
            recording_logger.debug("Recorder already warmed up")
            return

        try:
            # Create and close a test stream to initialize audio subsystem
            test_stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=self.channels,
                dtype=self.dtype,
            )
            test_stream.start()
            test_stream.stop()
            test_stream.close()

            self._is_warmed_up = True
            recording_logger.info("Recorder warmed up")

        except Exception as e:
            recording_logger.error(f"Failed to warm up recorder: {e}")

    async def cleanup(self) -> None:
        """Release recorder resources.

        Should be called on app termination to properly clean up resources.
        Stops any active recording and closes all streams.
        """
        # Stop recording if active
        if self._is_recording:
            await self.stop_recording()

        # Clean up resources
        self._cleanup_recording_resources()

        # Clear state
        self._is_warmed_up = False
        recording_logger.info("RecordingClient cleaned up")

    def _audio_callback(self, outdata: np.ndarray, frames: int, time, status: sd.CallbackFlags) -> None:
        """Callback for sounddevice audio stream.

        This is called by the sounddevice library when new audio data is available.
        It stores the audio data for later processing and puts a copy in the queue
        for audio level monitoring.

        Args:
            outdata: Audio data buffer (note: sounddevice calls it 'outdata' even for input)
            frames: Number of frames in the buffer
            time: Timing information
            status: Callback status flags
        """
        if status:
            recording_logger.warning(f"Audio callback status: {status}")

        # Store audio data for recording
        audio_chunk = outdata.copy()
        self._recording_data.append(audio_chunk)

        # Put copy in queue for metering (non-blocking)
        try:
            self._audio_queue.put_nowait(audio_chunk)
        except queue.Full:
            # Queue is full, drop this sample
            pass

    async def _monitor_audio_levels(self) -> None:
        """Background task to monitor audio levels.

        This task runs in the background while recording to calculate
        and publish meter values to the meter queue.
        """
        try:
            while not self._meter_stop_event.is_set():
                try:
                    # Get audio data from queue (non-blocking with timeout)
                    audio_data = self._audio_queue.get_nowait()

                    # Calculate audio levels
                    if len(audio_data) > 0:
                        # Calculate RMS (root mean square) for average power
                        rms = np.sqrt(np.mean(audio_data**2))
                        average_power = float(min(rms, 1.0))

                        # Calculate peak power
                        peak_power = float(np.max(np.abs(audio_data)))
                        peak_power = min(peak_power, 1.0)

                        meter = Meter(averagePower=average_power, peakPower=peak_power)

                        # Put meter in queue (non-blocking)
                        try:
                            self._meter_queue.put_nowait(meter)
                        except asyncio.QueueFull:
                            # Meter queue is full, drop this reading
                            pass
                except queue.Empty:
                    # No new audio data, wait a bit
                    pass

                # Wait a bit before next sample (~10 Hz = 100ms)
                await asyncio.sleep(0.1)
        except asyncio.CancelledError:
            pass

    def _save_recording(self) -> Path:
        """Save recording data to a WAV file.

        Returns:
            Path to the saved recording file

        Raises:
            RuntimeError: If no recording data is available
        """
        if not self._recording_data:
            raise RuntimeError("No recording data to save")

        # Create temporary file for recording
        temp_dir = Path(tempfile.gettempdir())
        recording_path = temp_dir / f"vox-recording-{asyncio.get_event_loop().time()}.wav"

        # Concatenate all audio chunks
        full_recording = np.concatenate(self._recording_data, axis=0)

        # Save as WAV file
        from scipy.io import wavfile

        wavfile.write(
            recording_path,
            self.sample_rate,
            (full_recording * 32767).astype(np.int16),  # Convert to int16 for WAV
        )

        self._recording_file = recording_path
        return recording_path

    def _cleanup_recording_resources(self) -> None:
        """Clean up recording resources.

        Stops any active streams and clears recording data.
        """
        # Stop and close stream
        if self._recording_stream is not None:
            try:
                if self._recording_stream.active:
                    self._recording_stream.stop()
                self._recording_stream.close()
            except Exception as e:
                recording_logger.error(f"Error closing stream: {e}")
            finally:
                self._recording_stream = None

        # Clear recording data
        self._recording_data = []

        # Stop metering
        self._meter_stop_event.set()

        # Clear audio queue
        try:
            while not self._audio_queue.empty():
                self._audio_queue.get_nowait()
        except queue.Empty:
            pass

        # Clear meter queue (need to create a new task to run async code in sync context)
        # This is okay - the queue will be cleared on next recording start
