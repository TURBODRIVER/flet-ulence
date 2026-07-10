import asyncio
import concurrent.futures
import contextlib
import inspect
import logging
import os
import traceback
from collections.abc import Awaitable
from pathlib import Path
from typing import Any, Callable, Optional, Union

from flet.controls.context import _context_page, context
from flet.controls.page import Page
from flet.controls.types import AppView
from flet.messaging.session import Session
from flet.utils import get_current_script_dir, is_embedded
from flet.utils.deprecated import deprecated
from flet.utils.pip import ensure_flet_desktop_package_installed

logger = logging.getLogger("flet")

AppCallable = Callable[[Page], Union[Any, Awaitable[Any]]]
"""Type alias for Flet app lifecycle callbacks.

Represents a callable (synchronous or asynchronous) that accepts a single argument of
type :class:`~flet.Page`. The return value is ignored.

Used for both `main` and `before_main` handlers.
"""


@deprecated("Use run() instead.", version="0.80.0", show_parentheses=True)
def app(*args, **kwargs):
    new_args = list(args)
    if "target" in kwargs:
        new_args.insert(0, kwargs["target"])
    return run(*new_args, **kwargs)


@deprecated("Use run() instead.", version="0.80.0", show_parentheses=True)
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
        Handle app-start notification by logging/printing URL and optional browser open.

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

    terminate = asyncio.Event()
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
