import asyncio
import logging
import os
import signal
import stat
import subprocess
import tempfile
from pathlib import Path

import flet_desktop
import flet_desktop.version
from flet.utils import (
    is_linux,
    is_macos,
    is_windows,
    random_string,
)

logger = logging.getLogger(flet_desktop.__name__)


def open_flet_view(page_url, assets_dir, debug, hidden):
    """
    Start a desktop view process and return the process object and PID file path.

    Args:
        page_url: Page endpoint the desktop client should open.
        assets_dir: Optional assets directory passed to the client process.
        debug: Whether to output flutter logger.
        hidden: Whether the window should start hidden.

    Returns:
        A tuple containing:
            - `subprocess.Popen`: started desktop process.
            - `str`: path to a temporary PID file used by `close_flet_view()`.
    """

    args, flet_env, pid_file = __locate_and_unpack_flet_view(
        page_url, assets_dir, hidden, debug
    )
    return subprocess.Popen(args, env=flet_env), pid_file


async def open_flet_view_async(page_url, assets_dir, debug, hidden):
    """
    Asynchronously start a desktop view process.

    Args:
        page_url: Page endpoint the desktop client should open.
        assets_dir: Optional assets directory passed to the client process.
        debug: Whether to output flutter logger.
        hidden: Whether the window should start hidden.

    Returns:
        A tuple containing:
            - `asyncio.subprocess.Process`: started desktop process.
            - `str`: path to a temporary PID file used by `close_flet_view()`.
    """

    args, flet_env, pid_file = __locate_and_unpack_flet_view(
        page_url, assets_dir, debug, hidden
    )
    return (
        await asyncio.create_subprocess_exec(args[0], *args[1:], env=flet_env),
        pid_file,
    )


def close_flet_view(pid_file):
    """
    Terminate a running desktop view process using its PID file.

    The function attempts to read the process ID from `pid_file`, send a
    termination signal, and remove the PID file. Failures while terminating are
    intentionally ignored, but the PID file is removed when possible.

    Args:
        pid_file: Path to the PID file returned by `open_flet_view()`
            or `open_flet_view_async()`.
    """

    if pid_file is not None and os.path.exists(pid_file):
        try:
            with open(pid_file, encoding="utf-8") as f:
                fvp_pid = int(f.read())
            logger.debug(f"Flet View process {fvp_pid}")
            os.kill(fvp_pid, signal.SIGKILL)
        except Exception:
            pass
        finally:
            os.remove(pid_file)


def __locate_and_unpack_flet_view(page_url, assets_dir, debug, hidden):
    """
    Resolve desktop client executable, prepare launch arguments, and environment.

    Resolution strategy (per platform):

    1. Prefer app binaries produced by `flet build` in the current workspace.
    2. Use `FLET_VIEW_PATH` when provided.
    3. Use cached / downloaded client from `~/.flet/client/`.

    Platform-specific launch commands are prepared for Windows, macOS, and Linux.

    Args:
        page_url: Page endpoint the desktop client should open.
        assets_dir: Optional assets directory passed to the client process.
        debug: Whether to output flutter logger.
        hidden: Whether to set `FLET_HIDE_WINDOW_ON_START=true` in process env.

    Returns:
        A tuple containing:
            - `list[str]`: command arguments for the desktop client.
            - `dict[str, str]`: environment variables for the launched process.
            - `str`: path to the temporary PID file.

    Raises:
        FileNotFoundError: If a required desktop executable or archive
            cannot be located or downloaded.
    """

    logger.info("Starting Flet View app...")

    args = []

    # pid file - Flet client writes its process ID to this file
    pid_file = str(Path(tempfile.gettempdir()).joinpath(random_string(20)))

    if is_windows():
        flet_path = None
        # 1. Try loading Flet client built with the latest run of `flet build`
        build_windows = os.path.join(os.getcwd(), "build", "windows")
        if os.path.exists(build_windows):
            for f in os.listdir(build_windows):
                if f.endswith(".exe"):
                    flet_path = os.path.join(build_windows, f)

        # 2. Check FLET_VIEW_PATH (developer mode)
        if not flet_path:
            flet_view_path = os.environ.get("FLET_VIEW_PATH")
            if flet_view_path and os.path.exists(flet_view_path):
                exe_path = os.path.join(flet_view_path, "flet.exe")
                if os.path.isfile(exe_path):
                    logger.info(f"Flet View found via FLET_VIEW_PATH: {flet_view_path}")
                    flet_path = exe_path
                else:
                    logger.warning(
                        f"FLET_VIEW_PATH set to {flet_view_path} "
                        f"but flet.exe not found there"
                    )

        if not flet_path:
            raise FileNotFoundError(
                f"Application executable not found. Build application first."
            )

        args = [flet_path, page_url, pid_file]

    elif is_macos():
        app_path = None
        # 1. Try loading Flet client built with the latest run of `flet build`
        build_macos = os.path.join(os.getcwd(), "build", "macos")
        if os.path.exists(build_macos):
            for f in os.listdir(build_macos):
                if f.endswith(".app"):
                    app_path = os.path.join(build_macos, f)

        # 2. Check FLET_VIEW_PATH (developer mode)
        if not app_path:
            flet_view_path = os.environ.get("FLET_VIEW_PATH")
            if flet_view_path:
                logger.info(f"Flet.app is set via FLET_VIEW_PATH: {flet_view_path}")
                temp_flet_dir = Path(flet_view_path)
            else:
                raise FileNotFoundError(
                    f"Application executable not found. Build application first."
                )

            app_name = None
            for f in os.listdir(temp_flet_dir):
                if f.endswith(".app"):
                    app_name = f
            if app_name is None:
                raise FileNotFoundError(
                    f"Application bundle not found in {temp_flet_dir}"
                )
            app_path = temp_flet_dir.joinpath(app_name)

        logger.info(f"page_url: {page_url}")
        logger.info(f"pid_file: {pid_file}")
        args = ["open", str(app_path), "-n", "-W", "--args", page_url, pid_file]

    elif is_linux():
        app_path = None
        # 1. Try loading Flet client built with the latest run of `flet build`
        build_linux = os.path.join(os.getcwd(), "build", "linux")
        if os.path.exists(build_linux):
            for f in os.listdir(build_linux):
                ef = os.path.join(build_linux, f)
                if os.path.isfile(ef) and stat.S_IXUSR & os.stat(ef)[stat.ST_MODE]:
                    app_path = ef

        # 2. Check FLET_VIEW_PATH (developer mode)
        if not app_path:
            flet_view_path = os.environ.get("FLET_VIEW_PATH")
            if flet_view_path:
                exe_path = str(Path(flet_view_path).joinpath("flet"))
                if os.path.isfile(exe_path):
                    logger.info(
                        f"Flet View is set via FLET_VIEW_PATH: {flet_view_path}"
                    )
                    app_path = exe_path
                else:
                    logger.warning(
                        f"FLET_VIEW_PATH set to {flet_view_path} "
                        f"but flet executable not found there"
                    )
            if not app_path:
                raise FileNotFoundError(
                    f"Application executable not found. Build application first."
                )

        args = [str(app_path), page_url, pid_file]

    flet_env = {**os.environ}

    if assets_dir:
        args.append(assets_dir)

    if debug:
        args.append("debug")

    if hidden:
        flet_env["FLET_HIDE_WINDOW_ON_START"] = "true"

    return args, flet_env, pid_file
