import asyncio
import os

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


import platform


def is_windows():
    """
    Indicates whether the current platform is Windows.

    Returns:
        `True` on Windows hosts, otherwise `False`.
    """
    return platform.system() == "Windows"


def is_linux():
    """
    Indicates whether the current platform is Linux.

    Returns:
        `True` on Linux hosts, otherwise `False`.
    """
    return platform.system() == "Linux"


def is_linux_server():
    """
    Indicates whether the current environment is a headless Linux server.

    The environment is considered a Linux server when:
    - the host platform is Linux;
    - it is not Windows Subsystem for Linux (WSL);
    - the `DISPLAY` environment variable is not set.

    Returns:
        `True` for headless Linux server environments, otherwise `False`.
    """
    if platform.system() == "Linux":
        # check if it's WSL
        p = "/proc/version"
        if os.path.exists(p):
            with open(p, encoding="utf-8") as file:
                if "microsoft" in file.read():
                    return False  # it's WSL, not a server
        return os.environ.get("DISPLAY") is None
    return False


def is_macos():
    """
    Indicates whether the current platform is macOS.

    Returns:
        `True` on macOS hosts, otherwise `False`.
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
    if is_windows():
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
