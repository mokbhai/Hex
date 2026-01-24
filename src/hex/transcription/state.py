"""Transcription state management for Hex.

This module provides the state data structure for the transcription feature,
mirroring the TranscriptionFeature.State from the Swift implementation.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class Meter:
    """Audio meter levels for recording visualization.

    Represents the current audio levels being captured during recording.
    This mirrors the Meter struct from HexCore/Clients/RecordingClient.swift.

    Attributes:
        averagePower: Average power level in decibels
        peakPower: Peak power level in decibels

    Examples:
        >>> meter = Meter(averagePower=-10.5, peakPower=-5.2)
        >>> meter.averagePower
        -10.5
    """

    averagePower: float = 0.0
    peakPower: float = 0.0


@dataclass
class TranscriptionState:
    """State for the transcription feature.

    This dataclass holds the current state of the transcription system,
    including recording status, transcription progress, and metadata.
    It mirrors TranscriptionFeature.State from the Swift implementation.

    Attributes:
        is_recording: Whether audio recording is currently active
        is_transcribing: Whether transcription is currently in progress
        is_prewarming: Whether the model is being pre-warmed
        error: Optional error message if something went wrong
        recording_start_time: When the current recording started
        meter: Current audio meter levels
        source_app_bundle_id: Bundle ID of the app where recording started
        source_app_name: Human-readable name of the source app

    Examples:
        >>> state = TranscriptionState()
        >>> state.is_recording
        False
        >>> state.meter.averagePower
        0.0
    """

    is_recording: bool = False
    is_transcribing: bool = False
    is_prewarming: bool = False
    error: Optional[str] = None
    recording_start_time: Optional[datetime] = None
    meter: Meter = field(default_factory=Meter)
    source_app_bundle_id: Optional[str] = None
    source_app_name: Optional[str] = None
