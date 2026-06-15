import asyncio
import concurrent.futures
import os
import threading
from pathlib import Path
from typing import Optional

import flet as ft

_profiler = None


class App():
    def __init__(self, title="No Name", dimensions=(800, 600), version="1.0"):
        self.title = title
        self.dimensions = dimensions
        self.version = version

        self.page: 'Optional[ft.Page]' = None

        # Tasks
        self._current_task_token: 'list[threading.Event]' = [threading.Event()]
        self._active_tasks = set()
        self._threaded_tasks_executor = concurrent.futures.ThreadPoolExecutor(max_workers=4, thread_name_prefix="threaded_task")

        # Views
        self.example_view = ExampleAppView(self)

    def create_task_token(self) -> 'threading.Event':
        token = threading.Event()
        self._current_task_token[0] = token
        return token

    def cancel_current_task(self):
        self._current_task_token[0].set()

        for task in list(self._active_tasks):
            task.cancel()

        self._active_tasks.clear()

    def _kill_all_tasks(self):
        self._current_task_token[0].set()

        for task in list(self._active_tasks):
            task.cancel()

        self._active_tasks.clear()
        self._threaded_tasks_executor.shutdown(wait=False, cancel_futures=True)

    def run_async_task(self, func):
        async def _wrapper():
            try:
                await func()
            except asyncio.CancelledError:
                pass  # silent exit
            finally:
                self._active_tasks.discard(asyncio.current_task())

        task = self.page.run_task(_wrapper)
        self._active_tasks.add(task)

        return task

    def run_threaded_task(self, func, *args):
        loop = asyncio.get_running_loop()
        loop.run_in_executor(self._threaded_tasks_executor, func, *args)

    async def init_app(self, page: 'ft.Page'):
        self.page = page

        page.title = self.title

        page.window.width = self.dimensions[0]
        page.window.height = self.dimensions[1]
        page.window.min_width = self.dimensions[0]
        page.window.min_height = self.dimensions[1]

        page.update()

        self._update_theme()
        self._init_window_events()

        self.example_view.display()

        await page.window.center()
        await page.window.to_front()
        page.window.visible = True
        page.window.focused = True

        page.update()

    def _update_theme(self):
        self.page.theme_mode = ft.ThemeMode.LIGHT
        self.page.bgcolor = "#FFFFFF"
        self.page.update()

    def _init_window_events(self):
        def on_window_event(e):
            if e.type == ft.WindowEventType.CLOSE:
                self._kill_all_tasks()

                self.page.window.prevent_close = False
                self.page.window.on_event = None

                async def _do_close():
                    await self.page.window.close()

                self.page.run_task(_do_close)

        self.page.window.prevent_close = True
        self.page.window.on_event = on_window_event


class BaseAppView():
    def __init__(self, app: 'App'):
        self.app = app

    def build(self, *args):
        raise NotImplementedError

    def display(self, *args):
        self.app.cancel_current_task()


class ExampleAppView(BaseAppView):
    def __init__(self, app: 'App'):
        super().__init__(app)

        self.files_list_ref = ft.Ref[ft.ListView]()
        self.files_count_ref = ft.Ref[ft.Text]()
        self.found_files_count = 0

    def display(self, *_):
        super().display()

        task_token = self.app.create_task_token()

        self.app.page.controls.clear()
        self.app.page.controls.append(self.build(self.files_list_ref, self.files_count_ref))
        self.app.page.update()

        async def _scan_files():
            queue: 'asyncio.Queue[Optional[Path]]' = asyncio.Queue()
            self.found_files_count = 0

            def _produce_files():
                documents_dir = Path(os.path.expanduser("~")) / "Documents"
                file_paths = sorted(Path(documents_dir).glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)

                for file_path in file_paths:
                    queue.put_nowait(file_path)

                queue.put_nowait(None)

            self.app.run_threaded_task(_produce_files)

            loading_element = ft.Container(
                expand=True,
                alignment=ft.Alignment.CENTER,
                padding=ft.Padding(top=10, bottom=10),
                content=ft.Column(
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=10, tight=True,
                    controls=[
                        ft.ProgressRing(width=32, height=32, stroke_width=4, color="#142AFA"),
                        ft.Column(
                            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=0, tight=True,
                            controls=[
                                ft.Text("Scanning Files...", size=12, color="#797876", weight=ft.FontWeight.W_600),
                            ],
                        ),
                    ],
                ),
            )

            if self.files_list_ref.current is not None:
                self.files_list_ref.current.controls = [loading_element]
                self.app.page.update()

            pending_file_entries = []
            is_done = False

            def _flush_pending_file_entries():
                if not pending_file_entries or self.files_list_ref.current is None:
                    pending_file_entries.clear()
                    return

                self.files_list_ref.current.controls.pop()

                for entry in pending_file_entries:
                    self.files_list_ref.current.controls.append(entry)

                self.files_list_ref.current.controls.append(loading_element)

                if self.files_count_ref.current is not None:
                    self.files_count_ref.current.value = f"Found {self.found_files_count} file{'s' if self.found_files_count != 1 else ''}."

                self.app.page.update()
                pending_file_entries.clear()

            while not is_done:
                if task_token.is_set():
                    break

                try:
                    queued_file = await asyncio.wait_for(queue.get(), timeout=0.05)
                except asyncio.TimeoutError:
                    _flush_pending_file_entries()
                    continue

                if queued_file is None:
                    is_done = True
                else:
                    pending_file_entries.append(
                        self._build_file_entry(queued_file)
                    )
                    self.found_files_count += 1

                    if len(pending_file_entries) >= 2:
                        _flush_pending_file_entries()

            _flush_pending_file_entries()

            if self.files_list_ref.current is not None and loading_element in self.files_list_ref.current.controls:
                self.files_list_ref.current.controls.remove(loading_element)

            if self.files_count_ref.current is not None:
                self.files_count_ref.current.value = f"Found {self.found_files_count} file{'s' if self.found_files_count != 1 else ''}."

            if self.found_files_count == 0 and self.files_list_ref.current is not None:
                self.files_list_ref.current.controls = [
                    ft.Column(
                        expand=True,
                        alignment=ft.MainAxisAlignment.CENTER,
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        controls=[
                            ft.Icon(ft.Icons.FOLDER_OPEN_OUTLINED, size=52, color="#393836"),
                            ft.Text("No files found.", size=16, color="#797876", weight=ft.FontWeight.W_600),
                        ],
                    )
                ]

            self.app.page.update()

        self.app.run_async_task(_scan_files)

    def build(self, files_list_ref: 'ft.Ref', files_count_ref: 'ft.Ref', *_):
        header_element = ft.Container(
            padding=ft.Padding.symmetric(horizontal=24, vertical=16),
            bgcolor="#142AFA",
            height=100,
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Container(
                        content=ft.Text(
                            ref=files_count_ref, value=f"Please wait...",
                            size=14, color="#1E1F1F", weight=ft.FontWeight.W_600,
                        ),
                        padding=ft.Padding.symmetric(horizontal=10, vertical=4),
                        border_radius=ft.BorderRadius.all(8),
                        bgcolor="#FFFFFF",
                        border=ft.Border.all(1, "#323232"),
                    ),
                ],
            ),
        )

        list_element = ft.Container(
            expand=True,
            alignment=ft.Alignment.CENTER,
            padding=ft.Padding.symmetric(horizontal=12),
            content=ft.ListView(
                padding=ft.Padding.symmetric(vertical=16, horizontal=12),
                spacing=0,
                ref=files_list_ref, controls=[],
                expand=True
            )
        )

        return ft.Stack(
            expand=True,
            controls=[
                ft.Column(
                    spacing=0,
                    expand=True,
                    controls=[
                        header_element,
                        list_element,
                    ],
                ),
            ]
        )

    def _build_file_entry(self, file_path: 'Path') -> 'ft.Container':
        def _hover(e):
            e.control.border = ft.Border.all(1, "#00DB37") if e.data else ft.Border.all(1, "#969696")
            e.control.update()

        return ft.Container(
            on_hover=_hover,
            border=ft.Border.all(1, "#969696"),
            border_radius=ft.BorderRadius.all(12),
            bgcolor="#FFFFFF",
            padding=ft.Padding.symmetric(horizontal=20, vertical=10),
            margin=ft.Margin(top=5, bottom=5, right=20),
            shadow=ft.BoxShadow(
                spread_radius=0, blur_radius=6,
                color=ft.Colors.with_opacity(0.15, "#323232"),
                offset=ft.Offset(0, 2),
            ),
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Row(
                        spacing=16,
                        expand=True,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        controls=[
                            # Info
                            ft.Column(spacing=10, controls=[
                                ft.Column(
                                    controls=[
                                        ft.Text(str(file_path), size=18, weight=ft.FontWeight.W_600, color="#151616", max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                                    ]
                                ),
                            ]),
                        ],
                    ),

                    # Ok Button
                    ft.Button(
                        content=ft.Row(spacing=6, tight=True, controls=[
                            ft.Icon(ft.Icons.LIST, size=20, color="#1E1F1F"),
                            ft.Text("Ok", size=16, color="#1E1F1F"),
                        ]),
                        bgcolor="#00DB37",
                        elevation=0,
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=12),
                            overlay_color=ft.Colors.with_opacity(0.12, "#323232"),
                            padding=ft.Padding.symmetric(horizontal=14, vertical=18),
                            mouse_cursor=ft.MouseCursor.CLICK
                        ),
                        on_click=None
                    ),
                ],
            ),
        )


if __name__ == "__main__":
    _app = App(
        title="Name of App",
        dimensions=(800, 600),
        version="1.0.0"
    )
    ft.run(_app.init_app)
