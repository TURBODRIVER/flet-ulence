import asyncio
import concurrent.futures
import contextlib
import inspect
import logging
import os
import signal
import traceback
from collections.abc import Awaitable
from pathlib import Path
from typing import Any, Callable, Optional, Union

from flet.controls.context import _context_page, context
from flet.controls.page import Page
from flet.controls.types import AppView
from flet.messaging.session import Session
from flet.utils import (
    get_current_script_dir,
    is_embedded,
)
from flet.utils.deprecated import deprecated

logger = logging.getLogger("flet")

AppCallable = Callable[[Page], Union[Any, Awaitable[Any]]]
"""Type alias for Flet app lifecycle callbacks.

Represents a callable (synchronous or asynchronous) that accepts a single argument of
type :class:`~flet.Page`. The return value is ignored.

Used for both `main` and `before_main` handlers.
"""


@deprecated(
    "Use run() instead.",
    docs_reason="Use [`run()`][flet.run] instead.",
    version="0.80.0",
    show_parentheses=True,
)
def app(*args, **kwargs):
    new_args = list(args)
    if "target" in kwargs:
        new_args.insert(0, kwargs["target"])
    return run(*new_args, **kwargs)


@deprecated(
    "Use run_async() instead.",
    docs_reason="Use [`run_async()`][flet.run_async] instead.",
    version="0.80.0",
    show_parentheses=True,
)
def app_async(*args, **kwargs):
    new_args = list(args)
    if "target" in kwargs:
        new_args.insert(0, kwargs["target"])
    return run_async(*new_args, **kwargs)


def run(
    main: AppCallable,
    before_main: Optional[AppCallable] = None,
    port: int = 0,
    view: Optional[AppView | str] = AppView.FLET_APP,
    assets_dir: Optional[str] = "assets",
    target=None,
):
    """
    Runs the Flet app.

    Args:
        main: Application entry point. Handler (function or coroutine) must
            have 1 parameter of instance :class:`~flet.Page`.
        before_main: Called after `Page` is created but before `main`.
        port: TCP port to bind. If `0`, an available port is chosen when needed.
        view: Preferred app presentation mode.
        assets_dir: A path to app's assets directory.
        target: Deprecated alias for `main`.
    """
    return asyncio.run(
        run_async(
            main=main or target,
            before_main=before_main,
            port=port,
            view=view,
            assets_dir=assets_dir,
        )
    )


async def run_async(
    main: AppCallable,
    before_main: Optional[AppCallable] = None,
    port: int = 0,
    view: Optional[AppView | str] = AppView.FLET_APP,
    assets_dir: Optional[str] = "assets",
    target=None,
):
    """
    Asynchronously run a Flet app using socket transport.

    Args:
        main: Application entry point. Handler (function or coroutine) must
            have 1 parameter of instance :class:`~flet.Page`.
        before_main: Called after `Page` is created but before `main`.
        port: TCP port to bind. If `0`, default/free port is selected.
        view: Preferred app presentation mode.
        assets_dir: Path to app assets directory.
        target: Deprecated alias for `main`.
    """
    if isinstance(view, str):
        view = AppView(view)

    env_port = os.getenv("FLET_SERVER_PORT")
    if env_port is not None and env_port:
        port = int(env_port)

    assets_dir = __get_assets_dir_path(assets_dir)
    url_prefix = os.getenv("FLET_DISPLAY_URL_PREFIX")

    def on_app_startup(page_url: str):
        """
        Handle app-start notification.

        Args:
            page_url: Resolved URL of the running app.
        """

        if url_prefix is not None:
            parts = [url_prefix, page_url]
            if view is not None:
                parts.append(view.value)
            print(*parts)
        else:
            logger.info("App URL: %s", page_url)

    loop = asyncio.get_running_loop()
    terminate = asyncio.Event()

    if not is_embedded():
        def exit_gracefully(signum, frame):
            """
            Signal handler that requests graceful app termination.

            Args:
                signum: Received OS signal number.
                frame: Current stack frame (unused).
            """

            logger.debug("Gracefully terminating Flet app...")
            loop.call_soon_threadsafe(terminate.set)
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            signal.signal(signal.SIGTERM, signal.SIG_DFL)

        signal.signal(signal.SIGINT, exit_gracefully)
        signal.signal(signal.SIGTERM, exit_gracefully)

    # Embedded runtime can opt into the in-process dart_bridge transport
    # (provided by libdart_bridge from flet-dev/serious-python) by setting
    # FLET_DART_BRIDGE_PORT. Falls back to the existing socket when the
    # env var is absent.
    bridge_port_env = os.getenv("FLET_DART_BRIDGE_PORT")

    if is_embedded() and bridge_port_env:
        conn = await __run_dart_bridge_server(
            port=int(bridge_port_env),
            main=main or target,
            before_main=before_main,
        )
    else:
        conn = await __run_socket_server(
            port=port,
            main=main or target,
            before_main=before_main,
            blocking=is_embedded(),
        )

    logger.info("Flet app has started...")

    try:
        if (
            (view in [AppView.FLET_APP, AppView.FLET_APP_HIDDEN])
            and not is_embedded()
            and url_prefix is None
        ):
            from flet.utils.pip import ensure_flet_desktop_package_installed
            ensure_flet_desktop_package_installed()
            from flet_desktop import close_flet_view, open_flet_view_async

            on_app_startup(conn.page_url)

            fvp, pid_file = await open_flet_view_async(
                conn.page_url,
                assets_dir,
                view == AppView.FLET_APP_HIDDEN,
            )
            with contextlib.suppress(Exception):
                await fvp.wait()

            close_flet_view(pid_file)

        elif url_prefix:
            on_app_startup(conn.page_url)

            with contextlib.suppress(KeyboardInterrupt):
                await terminate.wait()

        elif is_embedded() and bridge_port_env:
            # dart_bridge has no serve_forever (no socket accept loop) — the
            # embedded interpreter would otherwise exit as soon as the user's
            # main() returns. Park here until the host process tears us down.
            with contextlib.suppress(KeyboardInterrupt):
                await terminate.wait()

        elif view is None:
            with contextlib.suppress(KeyboardInterrupt):
                await terminate.wait()

    finally:
        await conn.close()


def __get_on_session_created(
    main: Optional[AppCallable],
) -> Callable[[Session], Awaitable[None]]:
    """
    Build session-start callback that executes the user `main` handler.

    Args:
        main: User-provided app entry handler.

    Returns:
        Async callback that initializes page context and runs `main`.
    """

    async def on_session_created(session: Session):
        """
        Initialize per-session context and execute app entry handler.

        Args:
            session: Active page session.
        """

        logger.info("App session started")
        try:
            assert main is not None
            _context_page.set(session.page)
            context.reset_auto_update()
            if inspect.iscoroutinefunction(main):
                await main(session.page)

            elif inspect.isasyncgenfunction(main):
                async for _ in main(session.page):
                    await session.after_event(session.page)

            elif inspect.isgeneratorfunction(main):
                for _ in main(session.page):
                    await session.after_event(session.page)
            else:
                # run synchronously
                main(session.page)

            await session.after_event(session.page)

        except Exception as e:
            logger.error("Unhandled error in main() handler", exc_info=True)
            session.error(f"{e}\n{traceback.format_exc()}")

    return on_session_created


async def __run_socket_server(
    port: int = 0,
    main: Optional[AppCallable] = None,
    before_main: Optional[AppCallable] = None,
    blocking: bool = False,
):
    """
    Start Flet socket server transport and return active connection object.

    Args:
        port: TCP port to bind (`0` lets OS choose).
        main: User app entry handler.
        before_main: Optional hook called before `main`.
        blocking: Whether server should run in blocking mode.

    Returns:
        Started socket-server connection instance.
    """

    from flet.messaging.flet_socket_server import FletSocketServer

    uds_path = os.getenv("FLET_SERVER_UDS_PATH")
    executor = concurrent.futures.ThreadPoolExecutor()

    conn = FletSocketServer(
        loop=asyncio.get_running_loop(),
        port=port,
        uds_path=uds_path,
        on_session_created=__get_on_session_created(main),
        before_main=before_main,
        blocking=blocking,
        executor=executor,
    )
    await conn.start()
    return conn


class _DartBridgeServerHandle:
    """
    Forwarding facade over the currently-active `FletDartBridgeServer`.
    """

    def __init__(self, build_conn):
        # `build_conn` is a callable that creates a fresh
        # FletDartBridgeServer for the given port — used both initially
        # and on every restart so we don't capture stale args.
        self._build_conn = build_conn
        self._conn = None  # type: ignore[assignment]
        # Pending swap-in tasks during a restart — tracked so close()
        # can wait for an in-flight swap rather than racing.
        self._swap_lock = asyncio.Lock()

    @property
    def page_url(self) -> str:
        return self._conn.page_url if self._conn is not None else ""

    @property
    def pubsubhub(self):
        # `flet.app.run_async` doesn't touch this, but keep parity in case
        # downstream callers (tests, alternative entry points) do.
        return self._conn.pubsubhub if self._conn is not None else None

    async def start(self, port: int):
        self._conn = self._build_conn(port)
        await self._conn.start()

    async def _swap_to_port(self, port: int):
        """Close the current connection and bring up a new one on `port`."""
        async with self._swap_lock:
            old = self._conn
            new = self._build_conn(port)
            await new.start()
            self._conn = new
            if old is not None:
                try:
                    await old.close()
                except Exception:
                    logger.warning(
                        "Error closing previous dart_bridge connection during "
                        "session restart",
                        exc_info=True,
                    )

    async def close(self):
        async with self._swap_lock:
            if self._conn is not None:
                await self._conn.close()
                self._conn = None


async def __run_dart_bridge_server(
    port: int,
    main: Optional[AppCallable] = None,
    before_main: Optional[AppCallable] = None,
):
    """
    Start Flet dart_bridge transport and return active connection object.

    This transport exchanges the same MsgPack-framed protocol as
    `__run_socket_server`, but over the in-process `dart_bridge` byte channel
    instead of a Unix socket — eliminating the socket file, kernel context
    switches, and the connect/handshake retry loop for embedded apps.

    Args:
        port: Dart native port (passed in via env var by the embedding side;
            doubles as the keyed channel identifier).
        main: User app entry handler.
        before_main: Optional hook called before `main`.

    Returns:
        Started dart_bridge-server handle.
    """
    # Imported lazily so non-embedded runs never try to load libdart_bridge.
    from flet.messaging.flet_dart_bridge_server import FletDartBridgeServer

    loop = asyncio.get_running_loop()
    executor = concurrent.futures.ThreadPoolExecutor()

    def _build_conn(p: int) -> FletDartBridgeServer:
        return FletDartBridgeServer(
            loop=loop,
            port=p,
            on_session_created=__get_on_session_created(main),
            before_main=before_main,
            executor=executor,
        )

    handle = _DartBridgeServerHandle(_build_conn)
    await handle.start(port)

    # Subscribe to Dart VM restart events. The C-side
    # `dart_bridge_signal_dart_session` (libdart_bridge >= 1.3.0) fires
    # every registered Python callback with `{label: new_port}`. On
    # pre-1.3.0 binaries the symbol is absent and Dart-side
    # `signalDartSession` is a no-op, so this handler never fires and the
    # flow degrades to the existing "one-Dart-VM lifetime" behavior — no
    # crash, no regression.
    try:
        import dart_bridge  # type: ignore[import-not-found]
    except ImportError:
        # Not running inside libdart_bridge (e.g. unit tests). Skip
        # restart subscription; nothing to swap to.
        return handle

    add_handler = getattr(dart_bridge, "add_session_restart_handler", None)
    if add_handler is None:
        # Older libdart_bridge without the restart API. Same fallback as
        # above — first session only.
        logger.debug(
            "dart_bridge.add_session_restart_handler not available; "
            "process-reuse restarts will be unsupported"
        )
        return handle

    def _on_session_restart(port_map):
        # Called from libdart_bridge (under the GIL, possibly off the
        # asyncio loop's thread). Marshal back onto the loop and run the
        # swap as a regular asyncio task.
        new_port = int(port_map.get("protocol", 0))
        if new_port <= 0 or new_port == port:
            return
        logger.info(
            "Dart VM restart detected; rebinding FletDartBridgeServer "
            "from port %s → %s",
            port,
            new_port,
        )
        loop.call_soon_threadsafe(
            lambda: asyncio.create_task(handle._swap_to_port(new_port))
        )

    add_handler(_on_session_restart)
    return handle


def __get_assets_dir_path(assets_dir: Optional[str], relative_to_cwd=False):
    """
    Resolve assets directory to an absolute path and apply env override.

    Args:
        assets_dir: Input assets directory path.
        relative_to_cwd: Resolve relative paths from current working directory
            instead of current script directory.

    Returns:
        Resolved assets directory path or `None`.
    """

    if assets_dir:
        if not Path(assets_dir).is_absolute():
            assets_dir = str(
                Path(os.getcwd() if relative_to_cwd else get_current_script_dir())
                .joinpath(assets_dir)
                .resolve()
            )
        logger.info("Assets path configured: %s", assets_dir)

    env_assets_dir = os.getenv("FLET_ASSETS_DIR")
    if env_assets_dir:
        assets_dir = env_assets_dir
    return assets_dir


def __get_upload_dir_path(upload_dir: Optional[str], relative_to_cwd=False):
    """
    Resolve upload directory to an absolute path.

    Args:
        upload_dir: Input upload directory path.
        relative_to_cwd: Resolve relative paths from current working directory
            instead of current script directory.

    Returns:
        Resolved upload directory path or `None`.
    """

    if upload_dir and not Path(upload_dir).is_absolute():
        upload_dir = str(
            Path(os.getcwd() if relative_to_cwd else get_current_script_dir())
            .joinpath(upload_dir)
            .resolve()
        )
    return upload_dir
