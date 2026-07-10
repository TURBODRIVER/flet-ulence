from dataclasses import dataclass

from flet.controls.base_control import control
from flet.controls.services.service import Service
from flet.utils import from_dict

__all__ = ["AccessibilityFeatures", "SemanticsService"]


@dataclass
class AccessibilityFeatures:
    """
    Accessibility features that may be enabled by the platform.

    Note:
        It is not possible to enable these settings from Flet, instead they are
        used by the platform to indicate that additional accessibility features are
        enabled.
    """

    accessible_navigation: bool
    """
    Whether there is a running accessibility service which is changing the interaction \
    model of the device.
    """

    bold_text: bool
    """
    The platform is requesting that text be rendered at a bold font weight.
    """

    disable_animations: bool
    """
    The platform is requesting that animations be disabled or simplified.
    """

    invert_colors: bool
    """
    The platform is inverting the colors of the application.
    """

    supports_announcements: bool
    """
    Whether the platform supports accessibility announcement API, i.e.
    :meth:`flet.SemanticsService.announce_message`.

    Will be `False` on platforms where announcements are deprecated or
    unsupported by the underlying platform and `True` on platforms where such
    announcements are generally supported without discouragement.

    Note:
        Some platforms do not support or discourage the use of
        announcement. Using `SemanticsService.announce_message()` on those platforms
        may be ignored. Consider using other way to convey message to the user.
    """


@control("SemanticsService")
class SemanticsService(Service):
    """
    Allows access to the platform's accessibility services.
    """

    async def announce_message(
        self,
        message: str,
        rtl: bool = False
    ):
        """
        Sends a semantic announcement with the given message.

        Args:
            message: The message to be announced.
            rtl: Indicates if the message text direction is right-to-left.

        Notes:
            This method should be used for announcements that are not automatically
            handled by the system as a result of a UI state change.
        """
        await self._invoke_method(
            "announce_message",
            arguments={
                "message": message,
                "rtl": rtl,
            },
        )

    async def get_accessibility_features(self) -> AccessibilityFeatures:
        """
        Returns the current platform accessibility feature flags.

        Returns:
            A snapshot of the platform's accessibility
                preferences at the time of invocation.
        """
        features = await self._invoke_method("get_accessibility_features")
        return from_dict(AccessibilityFeatures, features)
