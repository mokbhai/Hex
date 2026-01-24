"""ClipboardClient for system clipboard operations.

This module provides clipboard functionality using pyperclip and platform-specific
paste operations. It mirrors the structure from Hex/Clients/PasteboardClient.swift
in the Swift app.

The client handles:
- Copying text to the system clipboard
- Pasting text to the active application (via clipboard or typing simulation)
- Preserving and restoring clipboard contents during paste operations
"""

import asyncio
import subprocess
from dataclasses import dataclass
from enum import Enum, auto
from typing import Optional

import pyperclip

from hex.utils.logging import get_logger, LogCategory


# Module logger
clipboard_logger = get_logger(LogCategory.PASTEBOARD)


class PasteStrategy(Enum):
    """Different strategies for pasting text.

    Matches PasteStrategy from Swift implementation.
    """

    CMD_V = auto()
    MENU_ITEM = auto()
    TYPING = auto()


@dataclass
class PasteboardSnapshot:
    """Snapshot of clipboard contents for later restoration.

    This allows us to save the user's clipboard, paste our text,
    and then restore the original clipboard contents.

    Attributes:
        text: The text content that was on the clipboard
    """

    text: Optional[str] = None

    @classmethod
    def capture(cls) -> "PasteboardSnapshot":
        """Capture current clipboard contents.

        Returns:
            PasteboardSnapshot with current clipboard text
        """
        try:
            current_text = pyperclip.paste()
            return cls(text=current_text)
        except Exception as e:
            clipboard_logger.error(f"Failed to capture clipboard: {e}")
            return cls(text=None)

    def restore(self) -> None:
        """Restore the clipboard to the saved state.

        If the snapshot contains text, it will be placed back on the clipboard.
        If the snapshot is empty, the clipboard will be cleared.
        """
        try:
            if self.text is not None:
                pyperclip.copy(self.text)
            else:
                # Clear clipboard by copying empty string
                pyperclip.copy("")
            clipboard_logger.debug("Clipboard restored")
        except Exception as e:
            clipboard_logger.error(f"Failed to restore clipboard: {e}")


class ClipboardClient:
    """Client for clipboard operations.

    This class provides async clipboard functionality with paste strategies
    and clipboard preservation/restoration capabilities.

    Attributes:
        use_clipboard_paste: If True, use clipboard-based paste; otherwise use typing
        copy_to_clipboard: If True, keep text in clipboard after paste

    Example:
        >>> client = ClipboardClient()
        >>> await client.copy("Hello, world!")
        >>> await client.paste("This is transcribed text")
    """

    def __init__(
        self,
        use_clipboard_paste: bool = True,
        copy_to_clipboard: bool = False,
    ) -> None:
        """Initialize the ClipboardClient.

        Args:
            use_clipboard_paste: Use clipboard-based paste (Cmd+V) vs typing simulation
            copy_to_clipboard: Keep transcribed text in clipboard after paste
        """
        self.use_clipboard_paste = use_clipboard_paste
        self.copy_to_clipboard = copy_to_clipboard

    async def copy(self, text: str) -> None:
        """Copy text to the system clipboard.

        This places the specified text on the system clipboard, replacing
        any existing clipboard contents.

        Args:
            text: The text to copy to clipboard

        Example:
            >>> await client.copy("This text is now on the clipboard")
        """
        try:
            pyperclip.copy(text)
            clipboard_logger.debug(f"Copied {len(text)} characters to clipboard")
        except Exception as e:
            clipboard_logger.error(f"Failed to copy text to clipboard: {e}")
            raise

    async def paste(self, text: str) -> None:
        """Paste text to the active application.

        This method pastes the specified text to the currently active application
        using the configured paste strategy. If use_clipboard_paste is True,
        it will use the clipboard (Cmd+V); otherwise, it will simulate typing.

        The method can optionally preserve and restore the clipboard contents
        depending on the copy_to_clipboard setting.

        Args:
            text: The text to paste

        Example:
            >>> await client.paste("This text will be pasted into the active app")
        """
        if self.use_clipboard_paste:
            await self._paste_with_clipboard(text)
        else:
            await self._simulate_typing(text)

    async def _paste_with_clipboard(self, text: str) -> None:
        """Paste text using clipboard method.

        This saves the current clipboard, places the new text on the clipboard,
        triggers a paste (Cmd+V), and optionally restores the original clipboard.

        Args:
            text: The text to paste
        """
        # Capture current clipboard state
        snapshot = PasteboardSnapshot.capture()

        # Copy new text to clipboard
        await self.copy(text)

        # Wait a moment for clipboard to update
        await asyncio.sleep(0.05)

        # Attempt paste using available strategies
        paste_succeeded = await self._perform_paste(text)

        # Only restore clipboard if:
        # 1. User doesn't want to keep text in clipboard AND
        # 2. The paste operation succeeded
        if not self.copy_to_clipboard and paste_succeeded:
            # Give slower apps a short window to read the text
            # before we restore the previous clipboard contents
            await asyncio.sleep(0.5)
            snapshot.restore()

        # If we failed to paste AND user doesn't want clipboard retention,
        # log that text is available in clipboard as fallback
        if not paste_succeeded and not self.copy_to_clipboard:
            clipboard_logger.notice(
                "Paste operation failed; text remains in clipboard as fallback"
            )

    async def _perform_paste(self, text: str) -> bool:
        """Attempt to paste using multiple strategies.

        Tries different paste strategies in order until one succeeds.

        Args:
            text: The text to paste

        Returns:
            True if paste succeeded, False otherwise
        """
        strategies = [PasteStrategy.CMD_V, PasteStrategy.MENU_ITEM]

        for strategy in strategies:
            if await self._attempt_paste(text, strategy):
                return True

        return False

    async def _attempt_paste(self, text: str, strategy: PasteStrategy) -> bool:
        """Attempt to paste using a specific strategy.

        Args:
            text: The text to paste
            strategy: The paste strategy to use

        Returns:
            True if paste succeeded, False otherwise
        """
        try:
            if strategy == PasteStrategy.CMD_V:
                return await self._post_cmd_v()
            elif strategy == PasteStrategy.MENU_ITEM:
                return await self._paste_via_menu_item()
            elif strategy == PasteStrategy.TYPING:
                await self._simulate_typing(text)
                return True
        except Exception as e:
            clipboard_logger.warning(f"Paste strategy {strategy.name} failed: {e}")
            return False

        return False

    async def _post_cmd_v(self) -> bool:
        """Post Cmd+V keystroke to trigger paste.

        Uses AppleScript on macOS to simulate Cmd+V keypress.

        Returns:
            True if keystroke was sent successfully, False otherwise
        """
        try:
            script = 'tell application "System Events" to keystroke "v" using command down'
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=1.0,
            )
            if result.returncode == 0:
                clipboard_logger.debug("Sent Cmd+V keystroke")
                return True
            else:
                clipboard_logger.warning(f"Cmd+V failed: {result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            clipboard_logger.error("Cmd+V timed out")
            return False
        except OSError as e:
            clipboard_logger.error(f"System error during Cmd+V: {e}")
            return False
        except Exception as e:
            clipboard_logger.error(f"Unexpected error during Cmd+V: {e}", exc_info=True)
            return False

    async def _paste_via_menu_item(self) -> bool:
        """Paste by clicking the Paste menu item.

        Uses AppleScript to find and click the Paste menu item in the
        frontmost application.

        Returns:
            True if menu click succeeded, False otherwise
        """
        script = """
        if application "System Events" is not running then
            tell application "System Events" to launch
            delay 0.1
        end if
        tell application "System Events"
            tell process (name of first application process whose frontmost is true)
                try
                    tell (menu item "Paste" of menu "Edit" of menu bar item "Edit" of menu bar 1)
                        if exists then
                            if enabled then
                                click it
                                return "true"
                            end if
                        end if
                    end tell
                end try
            end tell
        end tell
        """

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=2.0,
            )
            if result.returncode == 0 and "true" in result.stdout:
                clipboard_logger.debug("Pasted via menu item")
                return True
            else:
                clipboard_logger.warning(f"Menu item paste failed: {result.stderr}")
                return False
        except subprocess.TimeoutExpired:
            clipboard_logger.error("Menu item paste timed out")
            return False
        except OSError as e:
            clipboard_logger.error(f"System error during menu item paste: {e}")
            return False
        except Exception as e:
            clipboard_logger.error(f"Unexpected error during menu item paste: {e}", exc_info=True)
            return False

    async def _simulate_typing(self, text: str) -> None:
        """Simulate typing the text character by character.

        This is a fallback paste method that uses AppleScript to simulate
        keystrokes. It's slower but may work in some edge cases.

        Args:
            text: The text to type
        """
        try:
            # Escape special characters for AppleScript
            escaped_text = text.replace('\\', '\\\\').replace('"', '\\"')

            script = f'tell application "System Events" to keystroke "{escaped_text}"'
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=5.0,
            )

            if result.returncode == 0:
                clipboard_logger.debug(f"Simulated typing {len(text)} characters")
            else:
                clipboard_logger.warning(f"Typing simulation failed: {result.stderr}")
        except subprocess.TimeoutExpired:
            clipboard_logger.error("Typing simulation timed out")
        except OSError as e:
            clipboard_logger.error(f"System error during typing simulation: {e}")
        except Exception as e:
            clipboard_logger.error(f"Unexpected error during typing simulation: {e}", exc_info=True)
