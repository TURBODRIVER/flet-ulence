import asyncio
import os
import platform

from flet.controls.exceptions import FletUnsupportedPlatformException


def get_bool_env_var(name: str):
    """
    Parses an environment variable value as a boolean.

    Args:
        name: Environment variable name.

    Returns:
        `True` when the variable value is `true`, `1`, or `yes` (case-insensitive);
        `False` for any other defined value; `None` when the variable is not set.
    """
    v = os.getenv(name)
    return v.lower() in ["true", "1", "yes"] if v is not None else None


def is_asyncio():
    """
    Indicates whether execution is inside an active asyncio task.

    Returns:
        `True` when an asyncio task is active, otherwise `False`.
    """
    try:
        return asyncio.current_task() is not None
    except RuntimeError:
        return False


def is_embedded():
    """
    Indicates whether a platform is explicitly provided by the embedding runtime.

    Returns:
        `True` when `FLET_PLATFORM` is set, otherwise `False`.
    """
    return os.getenv("FLET_PLATFORM") is not None


def is_windows():
    """
    Indicates whether the current host platform is Windows.
    """
    return platform.system() == "Windows"


def is_linux():
    """
    Indicates whether the current host platform is Linux.
    """
    return platform.system() == "Linux"


def is_macos():
    """
    Indicates whether the current host platform is macOS.
    """
    return platform.system() == "Darwin"


def get_platform():
    """
    Returns the normalized platform identifier used by Flet.

    Returns:
        One of: `windows`, `linux`, or `darwin`.

    Raises:
        :class:`~flet.FletUnsupportedPlatformException`: If the current platform is
            unsupported.
    """
    p = platform.system()
    if p == "Windows":
        return "windows"
    elif p == "Linux":
        return "linux"
    elif p == "Darwin":
        return "darwin"
    else:
        raise FletUnsupportedPlatformException(f"Unsupported platform: {p}")


def get_arch():
    """
    Returns the normalized CPU architecture identifier used by Flet.

    Returns:
        One of: `amd64`, `arm64`, or `arm_7`.

    Raises:
        :class:`~flet.FletUnsupportedPlatformException`: If the current architecture is
            unsupported.
    """
    a = platform.machine().lower()
    if a == "x86_64" or a == "amd64":
        return "amd64"
    elif a == "arm64" or a == "aarch64":
        return "arm64"
    elif a.startswith("arm"):
        return "arm_7"
    else:
        raise FletUnsupportedPlatformException(f"Unsupported architecture: {a}")
