from flet.controls.base_control import control
from flet.controls.exceptions import FletUnsupportedPlatformException
from flet.controls.services.service import Service

__all__ = ["StoragePaths"]


@control("StoragePaths")
class StoragePaths(Service):
    """
    Provides access to commonly used storage paths on the device.
    """

    async def get_library_directory(self) -> str:
        """Returns the path to the library directory.

        This directory is for persistent, backed-up files not visible to the user
        (e.g., sqlite.db).

        Returns:
            The path to the library directory.
        """
        if not self.page.platform.is_apple():
            raise FletUnsupportedPlatformException(
                "get_library_directory is supported only on macOS"
            )
        return await self._invoke_method("get_library_directory")
