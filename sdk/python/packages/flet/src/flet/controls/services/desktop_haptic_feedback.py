from flet.controls.base_control import control
from flet.controls.services.service import Service

__all__ = ["DesktopHapticFeedback"]


@control("DesktopHapticFeedback")
class DesktopHapticFeedback(Service):
    """
    Allows access to the haptic feedback interface on desktop.
    """

    async def generic(self):
        """
        MacOS only: A general haptic feedback pattern. Use this when no other feedback patterns apply.
        """
        await self._invoke_method("macos_generic_haptic")

    async def alignment(self):
        """
        MacOS only: A haptic feedback pattern to be used in response to the alignment of an object the user is dragging around.
        """
        await self._invoke_method("macos_alignment_haptic")

    async def level_change(self):
        """
        MacOS only: A haptic feedback pattern to be used as the user moves between discrete levels of pressure.
        """
        await self._invoke_method("macos_level_change_haptic")
