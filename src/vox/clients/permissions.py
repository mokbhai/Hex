"""Permission checking and requesting for system permissions.

This module provides functions to check and request system permissions
required by Hex, such as Accessibility and Input Monitoring permissions on macOS.

It mirrors the functionality from HexCore/Sources/HexCore/PermissionClient/PermissionClient.swift
and PermissionClient+Live.swift.
"""

import sys
from enum import Enum
from typing import Optional

# Optional logging import to avoid dependency issues during testing
try:
    from vox.utils.logging import get_logger, LogCategory
    logger = get_logger(LogCategory.PERMISSIONS)
except ImportError:
    # Fallback to basic logging if vox.utils.logging is not available
    import logging
    logger = logging.getLogger(__name__)


class PermissionStatus(Enum):
    """Represents the authorization status for a system permission.

    This mirrors the PermissionStatus enum in the Swift implementation.
    See: HexCore/Sources/HexCore/PermissionClient/PermissionStatus.swift
    """

    NOT_DETERMINED = "not_determined"
    """Permission has not been requested yet."""

    GRANTED = "granted"
    """Permission has been granted by the user."""

    DENIED = "denied"
    """Permission has been denied or restricted by the user."""


def check_accessibility_permission() -> PermissionStatus:
    """Check the current accessibility permission status on macOS.

    This function checks whether the app has accessibility permissions
    without triggering a system prompt.

    On macOS, this uses the AXIsProcessTrustedWithOptions function from
    the Application Services framework. The check is performed without
    prompting (kAXTrustedCheckOptionPrompt: false).

    Returns:
        PermissionStatus: The current permission status.
            - GRANTED: Accessibility permission is granted
            - DENIED: Accessibility permission is denied

    Raises:
        NotImplementedError: If called on a non-macOS platform.

    Example:
        >>> status = check_accessibility_permission()
        >>> if status == PermissionStatus.DENIED:
        ...     print("Accessibility permission required")
    """
    if sys.platform != "darwin":
        logger.error(
            f"Accessibility permission check not supported on {sys.platform}"
        )
        raise NotImplementedError(
            f"Accessibility permissions are only applicable on macOS, "
            f"but current platform is {sys.platform}"
        )

    try:
        import ctypes

        # Load the Application Services framework
        app_services = ctypes.CDLL(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        )

        # Define the function signature
        # AXIsProcessTrustedWithOptions(CFDictionaryRef options) -> Boolean
        app_services.AXIsProcessTrustedWithOptions.restype = ctypes.c_bool
        app_services.AXIsProcessTrustedWithOptions.argtypes = [ctypes.c_void_p]

        # Create options dictionary with kAXTrustedCheckOptionPrompt: false
        # to check without triggering the system prompt
        core_foundation = ctypes.CDLL(
            "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
        )

        # Create CFDictionary with one key-value pair
        # kAXTrustedCheckOptionPrompt = "AXTrustedCheckOptionPrompt"
        # false = 0

        # For simplicity, we pass None (NULL) which is equivalent to
        # an empty options dictionary, which also doesn't prompt
        options = None

        # Call the function
        is_trusted = app_services.AXIsProcessTrustedWithOptions(options)

        status = PermissionStatus.GRANTED if is_trusted else PermissionStatus.DENIED

        logger.info(f"Accessibility permission status: {status.value}")

        return status

    except Exception as e:
        logger.error(f"Failed to check accessibility permission: {e}")
        # On error, assume denied to be safe
        return PermissionStatus.DENIED


def check_input_monitoring_permission() -> PermissionStatus:
    """Check the current input monitoring permission status on macOS.

    This function checks whether the app has input monitoring permissions
    (also known as "listen event" permission) required for global hotkey monitoring.

    On macOS, this uses the IOHIDCheckAccess function from the IOKit framework.

    Returns:
        PermissionStatus: The current permission status.
            - GRANTED: Input monitoring permission is granted
            - DENIED: Input monitoring permission is denied
            - NOT_DETERMINED: Permission status cannot be determined

    Raises:
        NotImplementedError: If called on a non-macOS platform.

    Example:
        >>> status = check_input_monitoring_permission()
        >>> if status == PermissionStatus.DENIED:
        ...     print("Input monitoring permission required")
    """
    if sys.platform != "darwin":
        logger.error(
            f"Input monitoring permission check not supported on {sys.platform}"
        )
        raise NotImplementedError(
            f"Input monitoring permissions are only applicable on macOS, "
            f"but current platform is {sys.platform}"
        )

    try:
        import ctypes

        # Load the IOKit framework
        iokit = ctypes.CDLL("/System/Library/Frameworks/IOKit.framework/IOKit")

        # Define the function signature
        # IOHIDCheckAccess(IOHIDRequestType requestType) -> IOHIDAccessType
        iokit.IOHIDCheckAccess.restype = ctypes.c_uint  # IOHIDAccessType is a uint
        iokit.IOHIDCheckAccess.argtypes = [ctypes.c_uint]

        # kIOHIDRequestTypeListenEvent = 0
        kIOHIDRequestTypeListenEvent = 0

        # Define IOHIDAccessType values
        # kIOHIDAccessTypeGranted = 0
        # kIOHIDAccessTypeDenied = 1
        # kIOHIDAccessTypeUnknown = 2
        kIOHIDAccessTypeGranted = 0
        kIOHIDAccessTypeDenied = 1

        # Call the function
        access_type = iokit.IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)

        if access_type == kIOHIDAccessTypeGranted:
            status = PermissionStatus.GRANTED
        elif access_type == kIOHIDAccessTypeDenied:
            status = PermissionStatus.DENIED
        else:
            status = PermissionStatus.NOT_DETERMINED

        logger.info(
            f"Input monitoring permission status: {status.value} "
            f"(access_type: {access_type})"
        )

        return status

    except Exception as e:
        logger.error(f"Failed to check input monitoring permission: {e}")
        # On error, return not determined
        return PermissionStatus.NOT_DETERMINED
