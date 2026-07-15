import argparse
import contextlib
import platform

from rich.console import Group
from rich.live import Live

from flet_cli.commands.build_base import BaseBuildCommand, console


class Command(BaseBuildCommand):
    """
    Run a Flet Python app in debug mode.
    """

    def __init__(self, parser: argparse.ArgumentParser) -> None:
        super().__init__(parser)
        self.debug_platforms = {
            "windows": {"target_platform": "windows"},
            "macos": {"target_platform": "macos"},
            "linux": {"target_platform": "linux"},
        }
        self.debug_platform = None
        self.platform_label = None

    def add_arguments(self, parser: argparse.ArgumentParser) -> None:
        """
        Register command-line arguments for debug builds and run sessions.

        Args:
            parser: Argument parser configured by the command runner.
        """

        parser.add_argument(
            "platform",
            type=str.lower,
            nargs="?",
            choices=["macos", "linux", "windows"],
            help="The target platform to run the app on",
        )
        parser.add_argument(
            "--release",
            dest="release",
            action="store_true",
            default=False,
            help="Build the app in release mode.",
        )
        super().add_arguments(parser)

    def handle(self, options: argparse.Namespace) -> None:
        """
        Prepare project artifacts and run the app in debug/release mode.

        Args:
            options: Parsed command-line options.
        """

        super().handle(options)
        self.options.output_dir = None  # disable output dir for debug builds
        if self.options:
            if "platform" in self.options and self.options.platform:
                self.debug_platform = self.options.platform
            else:
                self.debug_platform = platform.system().lower()
                if self.debug_platform == "darwin":
                    self.debug_platform = "macos"
            self.platform_label = self.platform_labels[self.debug_platform]
            self.target_platform = self.debug_platforms[self.debug_platform][
                "target_platform"
            ]
        self.status = console.status(
            f"[bold blue]Initializing {self.target_platform} debug session...",
            spinner="bouncingBall",
        )
        with Live(Group(self.status, self.progress), console=console) as self.live:
            self.initialize_command()
            self.validate_target_platform()
            self.validate_entry_point()
            self.setup_template_data()
            self.create_flutter_project()
            self.package_python_app()
            self.register_flutter_extensions()
            if self.create_flutter_project(second_pass=True):
                self.update_flutter_dependencies()
            self.customize_icons()
            self.run_flutter()
            self.cleanup(0, message="Debug session ended.")

    def run_flutter(self):
        """
        Run the prepared Flutter project on the selected target device.
        """

        assert self.platforms
        assert self.target_platform
        mode = "release" if self.options.release else "debug"
        self.update_status(
            f"[bold blue]Running {mode} version of the app on "
            f"[cyan]{self.platform_label}[/cyan] device..."
        )

        with contextlib.suppress(KeyboardInterrupt):
            self._run_flutter_command()
