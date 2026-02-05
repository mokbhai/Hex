"""Recording indicator overlay for Hex voice-to-text application.

This module provides a visual overlay that appears during recording and
transcription, showing audio levels with a reactive capsule-shaped indicator.
It mirrors TranscriptionIndicatorView.swift from the Swift implementation.
"""

from enum import Enum
from dataclasses import dataclass

from PySide6.QtWidgets import QWidget, QApplication
from PySide6.QtCore import Qt, QTimer, QPointF, QRectF, Signal, Property, QPropertyAnimation
from PySide6.QtGui import QPainter, QColor, QPen, QRadialGradient, QBrush, QPainterPath

from vox.transcription.state import Meter
from vox.utils.logging import get_logger

logger = get_logger("gui.indicator")


class IndicatorStatus(Enum):
    """Status states for the recording indicator.

    Matches the Status enum in TranscriptionIndicatorView.swift.
    """

    HIDDEN = "hidden"
    OPTION_KEY_PRESSED = "option_key_pressed"
    RECORDING = "recording"
    TRANSCRIBING = "transcribing"
    PREWARMING = "prewarming"


class RecordingIndicator(QWidget):
    """Recording indicator overlay with audio level visualization.

    A frameless, top-level widget that displays a capsule-shaped indicator
    which reacts to audio levels during recording. The indicator changes
    color and size based on the current status and audio meter levels.

    Attributes:
        status: Current indicator status (HIDDEN, RECORDING, etc.)
        meter: Current audio meter levels

    Signals:
        animation_complete: Emitted when show/hide animation completes
    """

    animation_complete = Signal()

    # Visual constants matching Swift implementation
    _CORNER_RADIUS = 8.0
    _BASE_WIDTH = 16.0
    _EXPANDED_WIDTH = 56.0
    _HEIGHT = 16.0

    # Color constants
    _RECORDING_COLOR = QColor(255, 0, 0)  # Red
    _TRANSCRIBING_COLOR = QColor(0, 0, 255)  # Blue
    _OPTION_PRESSED_COLOR = QColor(0, 0, 0)  # Black

    def __init__(self) -> None:
        """Initialize the recording indicator widget."""
        super().__init__()

        # Window flags: frameless, stays on top, tool window (no taskbar entry)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)  # Transparent background
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)  # Don't steal focus

        # State
        self._status = IndicatorStatus.HIDDEN
        self._meter = Meter(averagePower=0.0, peakPower=0.0)

        # Animation state
        self._opacity = 0.0
        self._scale = 0.0
        self._width = self._BASE_WIDTH

        # Setup animation timer for smooth transitions
        self._animation_timer = QTimer(self)
        self._animation_timer.timeout.connect(self._update_animation)
        self._animation_timer.setInterval(16)  # ~60 FPS

        # Target values for animation
        self._target_opacity = 0.0
        self._target_scale = 0.0
        self._target_width = self._BASE_WIDTH

        # Initial geometry (centered on screen, will be updated when shown)
        screen = QApplication.primaryScreen()
        if screen:
            screen_geometry = screen.availableGeometry()
            center_x = screen_geometry.center().x()
            center_y = screen_geometry.center().y()
            self.setGeometry(
                int(center_x - self._BASE_WIDTH / 2),
                int(center_y - self._HEIGHT / 2),
                int(self._EXPANDED_WIDTH),  # Max width for drawing area
                int(self._HEIGHT),
            )

        logger.debug("Recording indicator initialized")

    @property
    def status(self) -> IndicatorStatus:
        """Get the current indicator status."""
        return self._status

    @status.setter
    def status(self, value: IndicatorStatus) -> None:
        """Set the indicator status and trigger animation.

        Args:
            value: New status (HIDDEN, RECORDING, TRANSCRIBING, etc.)
        """
        if self._status == value:
            return

        self._status = value
        self._update_target_values()
        self._animation_timer.start()

        if value == IndicatorStatus.HIDDEN:
            logger.debug("Indicator hiding")
        else:
            logger.debug(f"Indicator showing: {value.value}")

    @property
    def meter(self) -> Meter:
        """Get the current audio meter levels."""
        return self._meter

    @meter.setter
    def meter(self, value: Meter) -> None:
        """Set the audio meter levels and trigger update.

        Args:
            value: New meter levels with averagePower and peakPower (0.0 to 1.0)
        """
        self._meter = value
        if self._status != IndicatorStatus.HIDDEN:
            self.update()  # Trigger repaint

    def _update_target_values(self) -> None:
        """Update target values for animation based on current status."""
        if self._status == IndicatorStatus.HIDDEN:
            self._target_opacity = 0.0
            self._target_scale = 0.0
            self._target_width = self._BASE_WIDTH
        elif self._status == IndicatorStatus.RECORDING:
            self._target_opacity = 1.0
            self._target_scale = 1.0
            self._target_width = self._EXPANDED_WIDTH
        else:  # OPTION_KEY_PRESSED, TRANSCRIBING, PREWARMING
            self._target_opacity = 1.0
            self._target_scale = 1.0
            self._target_width = self._BASE_WIDTH

    def _update_animation(self) -> None:
        """Update animation state (called by timer)."""
        # Smooth interpolation (ease-out)
        speed = 0.2

        # Update opacity
        if abs(self._opacity - self._target_opacity) > 0.01:
            self._opacity += (self._target_opacity - self._opacity) * speed
        else:
            self._opacity = self._target_opacity

        # Update scale
        if abs(self._scale - self._target_scale) > 0.01:
            self._scale += (self._target_scale - self._scale) * speed
        else:
            self._scale = self._target_scale

        # Update width
        if abs(self._width - self._target_width) > 0.1:
            self._width += (self._target_width - self._width) * speed
        else:
            self._width = self._target_width

        # Update window opacity
        self.setWindowOpacity(self._opacity)

        # Trigger repaint
        self.update()

        # Check if animation complete
        if (
            abs(self._opacity - self._target_opacity) < 0.01
            and abs(self._scale - self._target_scale) < 0.01
            and abs(self._width - self._target_width) < 0.1
        ):
            self._animation_timer.stop()

            # Hide widget if fully hidden
            if self._status == IndicatorStatus.HIDDEN:
                self.hide()

            self.animation_complete.emit()

    def paintEvent(self, event) -> None:  # noqa: N802
        """Paint the indicator capsule.

        Args:
            event: Paint event (unused)
        """
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Calculate dimensions with scale
        scaled_width = self._width * self._scale
        scaled_height = self._HEIGHT * self._scale

        # Center the capsule in the widget
        x = (self.width() - scaled_width) / 2
        y = (self.height() - scaled_height) / 2

        rect = QRectF(x, y, scaled_width, scaled_height)

        # Get colors based on status and meter
        bg_color, stroke_color, glow_color = self._get_colors()

        # Draw capsule with rounded corners
        path = QPainterPath()
        path.addRoundedRect(rect, self._CORNER_RADIUS, self._CORNER_RADIUS)

        # Fill background
        painter.fillPath(path, bg_color)

        # Draw stroke
        pen = QPen(stroke_color, 1.0)
        pen.setCosmetic(True)  # Keep line width constant during scale
        painter.setPen(pen)
        painter.drawPath(path)

        # Draw inner glow (audio-reactive)
        if self._status == IndicatorStatus.RECORDING and self._meter.averagePower > 0.01:
            self._draw_inner_glow(painter, rect)

        # Draw outer glow (audio-reactive)
        if self._status == IndicatorStatus.RECORDING:
            self._draw_outer_glow(painter, rect)

    def _get_colors(self) -> tuple[QColor, QColor, QColor]:
        """Get colors for current status and meter levels.

        Returns:
            Tuple of (background_color, stroke_color, glow_color)
        """
        if self._status == IndicatorStatus.HIDDEN:
            return (
                QColor(0, 0, 0, 0),  # Transparent
                QColor(0, 0, 0, 0),
                QColor(0, 0, 0, 0),
            )

        elif self._status == IndicatorStatus.OPTION_KEY_PRESSED:
            return (
                QColor(0, 0, 0, 255),  # Black
                QColor(0, 0, 0, 255),
                QColor(0, 0, 0, 0),
            )

        elif self._status == IndicatorStatus.RECORDING:
            # Audio-reactive red
            avg_power = min(1.0, self._meter.averagePower * 3)
            peak_power = min(1.0, self._meter.peakPower * 3)

            # Background: black mixed with red based on audio level
            bg_mix = 0.5 + (avg_power * 0.3)  # 0.5 to 0.8
            bg_color = QColor(
                int(255 * avg_power * bg_mix),
                0,
                0,
                255,
            )

            # Stroke: red with white tint
            stroke_color = QColor(255, 50, 50, 150)  # Semi-transparent red

            # Glow: red based on peak
            glow_color = QColor(255, 0, 0, int(255 * peak_power))

            return (bg_color, stroke_color, glow_color)

        elif self._status == IndicatorStatus.TRANSCRIBING:
            # Blue with slight darkening
            bg_color = QColor(0, 0, 180, 255)  # Dark blue
            stroke_color = QColor(50, 50, 255, 150)  # Semi-transparent blue
            glow_color = QColor(0, 0, 255, 100)

            return (bg_color, stroke_color, glow_color)

        elif self._status == IndicatorStatus.PREWARMING:
            # Blue (same as transcribing)
            bg_color = QColor(0, 0, 180, 255)
            stroke_color = QColor(50, 50, 255, 150)
            glow_color = QColor(0, 0, 255, 100)

            return (bg_color, stroke_color, glow_color)

        # Fallback
        return (QColor(0, 0, 0), QColor(0, 0, 0), QColor(0, 0, 0, 0))

    def _draw_inner_glow(self, painter: QPainter, rect: QRectF) -> None:
        """Draw inner glow effect for recording state.

        Args:
            painter: QPainter instance
            rect: Capsule rectangle
        """
        avg_power = min(1.0, self._meter.averagePower * 3)

        # Inner glow (red center, fades to edges)
        inner_rect = rect.adjusted(6, 6, -6, -6)

        if inner_rect.width() > 0 and inner_rect.height() > 0:
            gradient = QRadialGradient(inner_rect.center(), inner_rect.width() / 2)

            # Center is bright red, edges fade to background
            alpha = int(255 * (avg_power if avg_power < 0.1 else avg_power / 0.1))
            gradient.setColorAt(0.0, QColor(255, 0, 0, alpha))
            gradient.setColorAt(1.0, QColor(255, 0, 0, 0))

            painter.fillRect(inner_rect, gradient)

    def _draw_outer_glow(self, painter: QPainter, rect: QRectF) -> None:
        """Draw outer glow effect for recording state.

        Args:
            painter: QPainter instance
            rect: Capsule rectangle
        """
        avg_power = min(1.0, self._meter.averagePower * 3)
        peak_power = min(1.0, self._meter.peakPower * 3)

        # Outer glow (red shadow based on audio level)
        if avg_power > 0.01:
            # Simple glow effect by drawing slightly larger, translucent rectangles
            glow_alpha = int(100 * avg_power)

            for offset in [4, 8]:
                glow_rect = rect.adjusted(-offset, -offset, offset, offset)
                glow_color = QColor(255, 0, 0, glow_alpha // (offset // 2))

                painter.setPen(Qt.PenStyle.NoPen)
                painter.setBrush(glow_color)
                painter.drawRoundedRect(
                    glow_rect,
                    self._CORNER_RADIUS,
                    self._CORNER_RADIUS,
                )

    def show_indicator(self, status: IndicatorStatus, meter: Meter | None = None) -> None:
        """Show the indicator with specified status.

        Args:
            status: Status to display (RECORDING, TRANSCRIBING, etc.)
            meter: Optional audio meter levels (uses current if not provided)
        """
        if meter is not None:
            self._meter = meter

        self.status = status

        if status != IndicatorStatus.HIDDEN:
            # Position centered on screen
            screen = QApplication.primaryScreen()
            if screen:
                screen_geometry = screen.availableGeometry()
                center = screen_geometry.center()
                self.move(
                    int(center.x() - self._EXPANDED_WIDTH / 2),
                    int(center.y() - self._HEIGHT / 2),
                )

            self.show()
            self.raise_()
            self.activateWindow()

    def hide_indicator(self) -> None:
        """Hide the indicator with animation."""
        self.status = IndicatorStatus.HIDDEN
