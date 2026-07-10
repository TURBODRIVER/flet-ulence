from typing import Optional

from flet.controls.base_control import control
from flet.controls.exceptions import FletUnsupportedPlatformException
from flet.controls.services.service import Service

__all__ = ["StoragePaths"]


@control("StoragePaths")
class StoragePaths(Service):
    """
    Provides access to commonly used storage paths on the device.
    """

    async def get_application_cache_directory(self) -> str:
        """Returns the path to the application-specific cache directory.

        If this directory does not exist, it is created automatically.

        Returns:
            The path to a directory where the application may place cache files.
        """
        return await self._invoke_method("get_application_cache_directory")

    async def get_application_documents_directory(self) -> str:
        """Returns the path to a directory for user-generated data.

        This directory is intended for data that cannot be recreated by your
        application.

        For non-user-generated data, consider using:

        - :meth:`get_application_support_directory`
        - :meth:`get_application_cache_directory`

        Returns:
            The path to the application documents directory.
        """
        return await self._invoke_method("get_application_documents_directory")

    async def get_application_support_directory(self) -> str:
        """Returns the path to a directory for application support files.

        This directory is created automatically if it does not exist.
        Use this for files not exposed to the user. Do not use for user data files.

        Returns:
            The path to the application support directory.
        """
        return await self._invoke_method("get_application_support_directory")

    async def get_downloads_directory(self) -> Optional[str]:
        """Returns the path to the downloads directory.

        The returned directory may not exist; clients should verify and create it
        if necessary.

        Returns:
            The path to the downloads directory, or None if unavailable.
        """
        return await self._invoke_method("get_downloads_directory")

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

    async def get_temporary_directory(self) -> str:
        """Returns the path to the temporary directory.

        This directory is not backed up and is suitable for storing caches
        of downloaded files.
        Files may be cleared at any time.
        The caller is responsible for managing files within this directory.

        Returns:
            The path to the temporary directory.
        """
        return await self._invoke_method("get_temporary_directory")

    async def get_console_log_filename(self) -> str:
        """Returns the path to a `console.log` file for debugging.

        This file is located in the
        :meth:`flet.StoragePaths.get_application_cache_directory`.

        Returns:
            The path to the console log file.
        """
        return await self._invoke_method("get_console_log_filename")
