"""KeyEventMonitorClient for global keyboard and mouse event monitoring.

This module provides cross-platform global keyboard and mouse event monitoring
using the pynput library. It mirrors the functionality of the Swift
KeyEventMonitorClient.swift, which uses CGEvent tap on macOS.

The client supports:
- Global keyboard event monitoring (press/release)
- Global mouse click monitoring
- Multiple simultaneous event handlers
- Thread-safe event delivery
- Handler cancellation via tokens
- HotKeyProcessor integration for hotkey detection
"""

import asyncio
import threading
from dataclasses import dataclass
from datetime import datetime
from typing import Callable, Dict, List, Optional, Set, Tuple, Union
from uuid import uuid4

from pynput import keyboard, mouse
from pynput.keyboard import Key, KeyCode

from hex.models.hotkey import HotKey, Key as HexKey, Modifier, ModifierKind, Modifiers
from hex.models.key_event import InputEvent, InputEventType, KeyEvent
from hex.hotkeys.processor import HotKeyProcessor, Output as ProcessorOutput
from hex.utils.logging import get_logger

logger = get_logger("keyEvent")


@dataclass
class KeyEventMonitorToken:
    """A token that can be used to cancel an event handler.

    This is equivalent to Swift's KeyEventMonitorToken struct.
    """

    cancel_handler: Callable[[], None]

    def cancel(self) -> None:
        """Cancel the event handler associated with this token."""
        self.cancel_handler()

    @classmethod
    def noop(cls) -> "KeyEventMonitorToken":
        """Create a token that does nothing."""
        return cls(cancel_handler=lambda: None)


class KeyEventMonitorClient:
    """Client for monitoring global keyboard and mouse events.

    This class provides cross-platform global event monitoring using pynput.
    It supports multiple concurrent handlers and thread-safe event delivery.

    The implementation mirrors the Swift KeyEventMonitorClient's architecture:
    - Multiple handlers can be registered simultaneously
    - Handlers receive events in the order they were registered
    - Handlers return True to consume the event, False to let it propagate
    - Tokens are provided for handler cancellation

    Attributes:
        _handlers: Dictionary mapping handler UUIDs to callable handlers
        _keyboard_listener: Active pynput keyboard listener
        _mouse_listener: Active pynput mouse listener
        _is_monitoring: Whether monitoring is currently active
        _lock: Thread lock for handler management
    """

    def __init__(self) -> None:
        """Initialize the KeyEventMonitorClient."""
        logger.info("Initializing KeyEventMonitorClient with pynput")

        self._handlers: Dict[str, Callable[[KeyEvent], bool]] = {}
        self._input_handlers: Dict[str, Callable[[InputEvent], bool]] = {}
        self._keyboard_listener: Optional[keyboard.Listener] = None
        self._mouse_listener: Optional[mouse.Listener] = None
        self._is_monitoring = False
        self._lock = threading.Lock()

        # Track pressed keys for modifier detection
        self._pressed_keys: Set[Union[keyboard.KeyCode, Key]] = set()

    def listen_for_key_press(self) -> asyncio.Queue[KeyEvent]:
        """Create an async queue that receives key events.

        This provides a simpler interface than handleKeyEvent for cases where
        you just want to consume events asynchronously.

        Returns:
            An asyncio.Queue that will receive KeyEvent objects as they occur

        Example:
            >>> client = KeyEventMonitorClient()
            >>> client.start_monitoring()
            >>> queue = client.listen_for_key_press()
            >>> event = await queue.get()
        """
        queue: asyncio.Queue[KeyEvent] = asyncio.Queue()

        def handler(event: KeyEvent) -> bool:
            try:
                queue.put_nowait(event)
            except asyncio.QueueFull:
                logger.warning("Key event queue full, dropping event")
            return False  # Don't consume the event

        self.handle_key_event(handler)
        return queue

    def handle_key_event(self, handler: Callable[[KeyEvent], bool]) -> KeyEventMonitorToken:
        """Register a keyboard event handler.

        The handler will be called for every keyboard event. It should return
        True to consume the event (prevent it from reaching other applications)
        or False to let it propagate normally.

        Args:
            handler: A callable that receives a KeyEvent and returns a bool

        Returns:
            A token that can be used to cancel this handler

        Example:
            >>> def my_handler(event: KeyEvent) -> bool:
            ...     print(f"Key pressed: {event.key}")
            ...     return False  # Don't consume the event
            >>> token = client.handle_key_event(my_handler)
            >>> # Later: token.cancel() to unregister
        """
        handler_id = str(uuid4())

        with self._lock:
            self._handlers[handler_id] = handler
            should_start = len(self._handlers) == 1 and len(self._input_handlers) == 0

        if should_start:
            self.start_monitoring()

        return KeyEventMonitorToken(
            cancel_handler=lambda: self._remove_handler(handler_id)
        )

    def handle_input_event(self, handler: Callable[[InputEvent], bool]) -> KeyEventMonitorToken:
        """Register an input event handler (keyboard or mouse).

        The handler will be called for both keyboard and mouse click events.
        It should return True to consume the event or False to let it propagate.

        Args:
            handler: A callable that receives an InputEvent and returns a bool

        Returns:
            A token that can be used to cancel this handler
        """
        handler_id = str(uuid4())

        with self._lock:
            self._input_handlers[handler_id] = handler
            should_start = len(self._input_handlers) == 1 and len(self._handlers) == 0

        if should_start:
            self.start_monitoring()

        return KeyEventMonitorToken(
            cancel_handler=lambda: self._remove_input_handler(handler_id)
        )

    def handle_hotkey_processor(
        self,
        processor: HotKeyProcessor,
        output_callback: Callable[[ProcessorOutput], None]
    ) -> KeyEventMonitorToken:
        """Register a HotKeyProcessor to process keyboard and mouse events.

        This method integrates a HotKeyProcessor with the key event monitor.
        All keyboard events and mouse clicks will be processed through the
        HotKeyProcessor state machine, and the callback will be invoked with
        the processor's output (START_RECORDING, STOP_RECORDING, CANCEL, DISCARD)
        when actions are triggered.

        This is equivalent to the Swift handleKeyEvent() method that integrates
        with the HotKeyProcessor for hotkey detection.

        Mouse Click Behavior:
            Mouse clicks are processed to prevent accidental recordings for modifier-only
            hotkeys. If a mouse click occurs within the threshold after activating a
            modifier-only hotkey (e.g., Option+click in Finder), a DISCARD action is
            emitted to cancel the recording.

        Args:
            processor: A HotKeyProcessor instance configured with the desired hotkey
            output_callback: A callable that receives ProcessorOutput actions

        Returns:
            A token that can be used to cancel this processor integration

        Example:
            >>> from hex.models.hotkey import HotKey, Modifier, Modifiers
            >>> from hex.hotkeys.processor import HotKeyProcessor
            >>> processor = HotKeyProcessor(
            ...     hotkey=HotKey(key=None, modifiers=Modifiers.from_list([Modifier.OPTION]))
            ... )
            >>> def on_action(output):
            ...     print(f"Action: {output.name}")
            >>> token = client.handle_hotkey_processor(processor, on_action)
        """
        # Create a wrapper handler that processes keyboard events through the HotKeyProcessor
        def key_event_handler(event: KeyEvent) -> bool:
            # Process the key event through the HotKeyProcessor state machine
            result = processor.process(event)

            # If the processor returned an output, invoke the callback
            if result is not None:
                try:
                    output_callback(result)
                    logger.debug(f"HotKeyProcessor output: {result.name}")
                except Exception as e:
                    logger.error(f"Error in processor output callback: {e}")

            # Never consume the event - let it propagate to other applications
            return False

        # Create a wrapper handler that processes mouse clicks for discard logic
        def input_event_handler(event: InputEvent) -> bool:
            # Only process mouse clicks
            if event.is_mouse_click:
                # Process the mouse click through the HotKeyProcessor for discard detection
                result = processor.process_mouse_click()

                # If the processor returned an output, invoke the callback
                if result is not None:
                    try:
                        output_callback(result)
                        logger.debug(f"HotKeyProcessor mouse click output: {result.name}")
                    except Exception as e:
                        logger.error(f"Error in processor mouse click callback: {e}")

            # Never consume the event - let it propagate to other applications
            return False

        # Register both handlers - keyboard for hotkey detection, input for mouse clicks
        keyboard_token = self.handle_key_event(key_event_handler)
        input_token = self.handle_input_event(input_event_handler)

        # Return a composite token that cancels both handlers
        def cancel_both() -> None:
            keyboard_token.cancel()
            input_token.cancel()

        return KeyEventMonitorToken(cancel_handler=cancel_both)

    def start_monitoring(self) -> None:
        """Start monitoring keyboard and mouse events.

        This method starts the global event listeners. It's called automatically
        when the first handler is registered, but can also be called explicitly.

        Note:
            Monitoring is stopped automatically when all handlers are cancelled.
        """
        if self._is_monitoring:
            return

        logger.info("Starting global keyboard and mouse monitoring")

        # Start keyboard listener
        self._keyboard_listener = keyboard.Listener(
            on_press=self._on_key_press,
            on_release=self._on_key_release,
            suppress=False  # Don't suppress events (let them pass through)
        )

        # Start mouse listener
        self._mouse_listener = mouse.Listener(
            on_click=self._on_mouse_click,
            suppress=False
        )

        self._keyboard_listener.start()
        self._mouse_listener.start()

        self._is_monitoring = True
        logger.info("Successfully started keyboard and mouse monitoring")

    def stop_monitoring(self) -> None:
        """Stop monitoring keyboard and mouse events.

        This method stops the global event listeners. It's called automatically
        when all handlers are cancelled.
        """
        if not self._is_monitoring:
            return

        logger.info("Stopping global keyboard and mouse monitoring")

        if self._keyboard_listener:
            self._keyboard_listener.stop()
            self._keyboard_listener = None

        if self._mouse_listener:
            self._mouse_listener.stop()
            self._mouse_listener = None

        self._is_monitoring = False
        logger.info("Successfully stopped keyboard and mouse monitoring")

    def _remove_handler(self, handler_id: str) -> None:
        """Remove a keyboard event handler.

        Args:
            handler_id: The UUID of the handler to remove
        """
        with self._lock:
            self._handlers.pop(handler_id, None)
            should_stop = len(self._handlers) == 0 and len(self._input_handlers) == 0

        if should_stop:
            self.stop_monitoring()

    def _remove_input_handler(self, handler_id: str) -> None:
        """Remove an input event handler.

        Args:
            handler_id: The UUID of the handler to remove
        """
        with self._lock:
            self._input_handlers.pop(handler_id, None)
            should_stop = len(self._handlers) == 0 and len(self._input_handlers) == 0

        if should_stop:
            self.stop_monitoring()

    def _on_key_press(self, key: Union[keyboard.KeyCode, Key]) -> None:
        """Handle a key press event from pynput.

        Args:
            key: The key that was pressed (pynput format)
        """
        try:
            # Track pressed key
            self._pressed_keys.add(key)

            # Convert pynput key to Hex KeyEvent
            key_event = self._pynput_key_to_event(key, is_press=True)

            if key_event:
                logger.debug(f"Key pressed: {key_event}")

                # Deliver to keyboard handlers
                handlers = list(self._handlers.values())
                for handler in handlers:
                    try:
                        if handler(key_event):
                            # Handler consumed the event
                            break
                    except Exception as e:
                        logger.error(f"Error in key event handler: {e}")

                # Deliver to input handlers
                input_event = InputEvent.keyboard(key_event)
                self._deliver_to_input_handlers(input_event)

        except Exception as e:
            logger.error(f"Error processing key press: {e}")

    def _on_key_release(self, key: Union[keyboard.KeyCode, Key]) -> None:
        """Handle a key release event from pynput.

        Args:
            key: The key that was released (pynput format)
        """
        try:
            # Remove from pressed keys
            self._pressed_keys.discard(key)

            # Convert pynput key to Hex KeyEvent
            key_event = self._pynput_key_to_event(key, is_press=False)

            if key_event:
                logger.debug(f"Key released: {key_event}")

                # Deliver to keyboard handlers
                handlers = list(self._handlers.values())
                for handler in handlers:
                    try:
                        if handler(key_event):
                            # Handler consumed the event
                            break
                    except Exception as e:
                        logger.error(f"Error in key event handler: {e}")

                # Deliver to input handlers
                input_event = InputEvent.keyboard(key_event)
                self._deliver_to_input_handlers(input_event)

        except Exception as e:
            logger.error(f"Error processing key release: {e}")

    def _on_mouse_click(
        self,
        x: int,
        y: int,
        button: mouse.Button,
        pressed: bool
    ) -> None:
        """Handle a mouse click event from pynput.

        Args:
            x: X coordinate of the mouse
            y: Y coordinate of the mouse
            button: The button that was clicked
            pressed: True if pressed, False if released
        """
        try:
            # Only handle press events, not releases
            if not pressed:
                return

            logger.debug(f"Mouse clicked at ({x}, {y})")

            # Create mouse click input event
            input_event = InputEvent.mouse_click()

            # Deliver to input handlers
            self._deliver_to_input_handlers(input_event)

        except Exception as e:
            logger.error(f"Error processing mouse click: {e}")

    def _deliver_to_input_handlers(self, event: InputEvent) -> None:
        """Deliver an input event to all registered input handlers.

        Args:
            event: The InputEvent to deliver
        """
        handlers = list(self._input_handlers.values())
        for handler in handlers:
            try:
                if handler(event):
                    # Handler consumed the event
                    break
            except Exception as e:
                logger.error(f"Error in input event handler: {e}")

    def _pynput_key_to_event(self, key: Union[keyboard.KeyCode, Key], is_press: bool) -> Optional[KeyEvent]:
        """Convert a pynput key to a Hex KeyEvent.

        This method translates pynput's key representation into our Hex KeyEvent model,
        extracting both the key (if any) and the active modifiers.

        Args:
            key: The pynput key (KeyCode or Key)
            is_press: True if this is a press event, False for release

        Returns:
            A KeyEvent, or None if the key couldn't be converted
        """
        try:
            # Extract modifiers from currently pressed keys
            modifiers = self._extract_modifiers()

            # Convert pynput key to Hex key
            hex_key = self._pynput_key_to_hex_key(key)

            # Create KeyEvent
            key_event = KeyEvent(
                key=hex_key,
                modifiers=modifiers,
                timestamp=datetime.now()
            )

            return key_event

        except Exception as e:
            logger.error(f"Error converting pynput key to event: {e}")
            return None

    def _extract_modifiers(self) -> Modifiers:
        """Extract the current modifier state from pressed keys.

        Returns:
            A Modifiers object containing all currently pressed modifiers
        """
        modifier_list: List[Modifier] = []

        # Check for common modifier keys
        if any(k in self._pressed_keys for k in [Key.cmd, Key.cmd_l, Key.cmd_r]):
            modifier_list.append(Modifier.COMMAND)

        if any(k in self._pressed_keys for k in [Key.alt, Key.alt_l, Key.alt_r, Key.alt_gr]):
            modifier_list.append(Modifier.OPTION)

        if any(k in self._pressed_keys for k in [Key.shift, Key.shift_l, Key.shift_r]):
            modifier_list.append(Modifier.SHIFT)

        if any(k in self._pressed_keys for k in [Key.ctrl, Key.ctrl_l, Key.ctrl_r]):
            modifier_list.append(Modifier.CONTROL)

        return Modifiers.from_list(modifier_list)

    def _pynput_key_to_hex_key(self, key: Union[keyboard.KeyCode, Key]) -> Optional[HexKey]:
        """Convert a pynput key to a Hex Key enum value.

        Args:
            key: The pynput key to convert

        Returns:
            A Hex Key enum value, or None if the key doesn't map to a known key
        """
        # Handle special keys
        if isinstance(key, Key):
            key_map = {
                Key.space: HexKey.SPACE,
                Key.enter: HexKey.ENTER,
                Key.tab: HexKey.TAB,
                Key.esc: HexKey.ESCAPE,
                Key.backspace: HexKey.BACKSPACE,
                Key.left: HexKey.LEFT_ARROW,
                Key.right: HexKey.RIGHT_ARROW,
                Key.up: HexKey.UP_ARROW,
                Key.down: HexKey.DOWN_ARROW,
                Key.f1: HexKey.F1,
                Key.f2: HexKey.F2,
                Key.f3: HexKey.F3,
                Key.f4: HexKey.F4,
                Key.f5: HexKey.F5,
                Key.f6: HexKey.F6,
                Key.f7: HexKey.F7,
                Key.f8: HexKey.F8,
                Key.f9: HexKey.F9,
                Key.f10: HexKey.F10,
                Key.f11: HexKey.F11,
                Key.f12: HexKey.F12,
            }
            return key_map.get(key)

        # Handle regular character keys
        if isinstance(key, KeyCode):
            char = key.char

            if char is None:
                return None

            # Handle letters
            if char.isalpha() and char.islower():
                key_map = {
                    'a': HexKey.A, 'b': HexKey.B, 'c': HexKey.C,
                    'd': HexKey.D, 'e': HexKey.E, 'f': HexKey.F,
                    'g': HexKey.G, 'h': HexKey.H, 'i': HexKey.I,
                    'j': HexKey.J, 'k': HexKey.K, 'l': HexKey.L,
                    'm': HexKey.M, 'n': HexKey.N, 'o': HexKey.O,
                    'p': HexKey.P, 'q': HexKey.Q, 'r': HexKey.R,
                    's': HexKey.S, 't': HexKey.T, 'u': HexKey.U,
                    'v': HexKey.V, 'w': HexKey.W, 'x': HexKey.X,
                    'y': HexKey.Y, 'z': HexKey.Z,
                }
                if char in key_map:
                    return key_map[char]

            # Handle numbers
            if char.isdigit():
                num_map = {
                    '0': HexKey.ZERO, '1': HexKey.ONE, '2': HexKey.TWO,
                    '3': HexKey.THREE, '4': HexKey.FOUR, '5': HexKey.FIVE,
                    '6': HexKey.SIX, '7': HexKey.SEVEN, '8': HexKey.EIGHT,
                    '9': HexKey.NINE,
                }
                if char in num_map:
                    return num_map[char]

            # Handle punctuation
            punct_map = {
                '.': HexKey.PERIOD,
                ',': HexKey.COMMA,
                '/': HexKey.SLASH,
                "'": HexKey.QUOTE,
                '\\': HexKey.BACKSLASH,
                ';': HexKey.SEMICOLON,
                '`': HexKey.GRAVE,
            }
            if char in punct_map:
                return punct_map[char]

        # Key not recognized
        return None


# Convenience function for creating a client
def create_key_event_monitor() -> KeyEventMonitorClient:
    """Create a new KeyEventMonitorClient instance.

    Returns:
        A new KeyEventMonitorClient ready for use
    """
    return KeyEventMonitorClient()
