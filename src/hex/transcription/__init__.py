"""Transcription feature for Hex.

This package contains the core transcription logic including state management,
actions, and reducers. It mirrors the TranscriptionFeature from the Swift
implementation in Hex/Features/Transcription/TranscriptionFeature.swift.
"""

from hex.transcription.state import TranscriptionState, Meter

__all__ = ["TranscriptionState", "Meter"]
