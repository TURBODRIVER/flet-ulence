# https://github.com/PraiseTheDarkFlo/flet-extended-interactive-viewer

from dataclasses import dataclass
from typing import Optional, Annotated

from flet.controls.base_control import control
from flet.controls.control import Control
from flet.controls.control_event import Event, EventHandler
from flet.controls.duration import DurationValue
from flet.controls.layout_control import LayoutControl
from flet.controls.types import ColorValue, Number
from flet.utils.validation import V

__all__ = [
    "ExtendedInteractiveViewer",
    "ViewerUpdateEvent",
]


@dataclass
class ViewerUpdateEvent(Event["ExtendedInteractiveViewer"]):
    """
    Event raised when the user interacts with the viewer.

    Example:
        ```python
        import flet as ft
        from flet_extended_interactive_viewer import ExtendedInteractiveViewer, ViewerUpdateEvent

        def main(page: ft.Page):
            def on_update(e: ViewerUpdateEvent):
                print(e.offset_x, e.offset_y, e.scale)

            fei = ExtendedInteractiveViewer(
                content=ft.Container(width=900, height=800, gradient=ft.LinearGradient(
                    colors=[ft.Colors.PINK, ft.Colors.ORANGE_700],
                )),
                width=400, height=250,
                on_interaction_update=on_update,
            )
            page.add(fei)

        ft.run(main)
        ```
    """
    offset_x: float
    """
    The X offset of the content in the Interactive Viewer.
    """
    offset_y: float
    """
    The Y offset of the content in the Interactive Viewer.
    """
    scale: float
    """
    The scale of the content in the Interactive Viewer.
    """


@control("ExtendedInteractiveViewer")
class ExtendedInteractiveViewer(LayoutControl):
    """
    A powerful 2D navigation control for [Flet](https://flet.dev/) that adds synchronized scrollbars and enhanced transformation control to the standard InteractiveViewer.

    Key Features:
        - **Synchronized XY Scrollbars:** Real-time visual feedback and manual scrolling for both axes, perfectly synced with panning and zoom.
        - **Granular Navigation:** Toggle panning, scroll-axis visibility, and scrollbar interaction independently to suit your tool's needs.
        - **Precision Zooming:** Smooth zoom control via mouse/touchpad or function calls, with optional constraints to keep content within the viewport.
        - **Transformation API:** Direct programmatic access to current offsets (X, Y) and scale factors for real-time UI synchronization.
        - **Flexible Layouts:** Supports both constrained and unconstrained content, making it ideal for everything from document viewers to infinite canvas editors.
    """
    content: Annotated[Control, V.visible_control]
    """
    The Control to be transformed.

    Raises:
        ValueError: If it is not visible.
    """
    x_scroll_enabled: bool = True
    """
    Whether X scrollbar should appear or not.
    """
    y_scroll_enabled: bool = True
    """
    Whether Y scrollbar should appear or not.
    """
    over_zoom_enabled: bool = False
    """
    Whether it should be possible to zoom beyond the content's native resolution.
    """
    interactive_scroll_enabled: bool = True
    """
    Whether the scrollbars are interactive or serve only as a visual position indicator.
    """
    pan_enabled: bool = True
    """
    Whether panning is enabled.
    """
    max_scale: Annotated[
        Number,
        V.gt(0),
        V.ge_field("min_scale"),
    ] = 2.5
    """
    The maximum allowed scale.
    Default is 2.5.

    Raises:
        ValueError: If it is not strictly greater than `0`.
        ValueError: If it is not greater than or equal to `min_scale`.
    """
    min_scale: Annotated[
        Number,
        V.gt(0),
        V.le_field("max_scale"),
    ] = 0.8
    """
    The minimum allowed scale.
    Default is 0.8.

    Raises:
        ValueError: If it is not strictly greater than `0`.
        ValueError: If it is not less than or equal to `max_scale`.
    """
    scale_enabled: bool = True
    """
    Whether scaling is enabled.
    """
    scale_factor: Number = 200.0
    """
    The amount of scale to be performed per pointer scroll.
    Default is 200.0. 

    Increasing this value above the default causes scaling to feel slower,
    while decreasing it causes scaling to feel faster.

    Note:
        Has effect only on pointer device scrolling, not pinch to zoom.
    """
    constrained: bool = False
    """
    Whether the normal size constraints at this point in the control tree are applied \
    to the `content`.

    If set to `False`, then the content will be given infinite constraints. This
    is often useful when a content should be bigger than this `InteractiveViewer`.

    For example, for a content which is bigger than the viewport but can be
    panned to reveal parts that were initially offscreen, `constrained` must
    be set to `False` to allow it to size itself properly. If `constrained` is
    `True` and the content can only size itself to the viewport, then areas
    initially outside of the viewport will not be able to receive user
    interaction events. If experiencing regions of the content that are not
    receptive to user gestures, make sure `constrained` is `False` and the content
    is sized properly.
    """
    on_interaction_update: Optional[EventHandler[ViewerUpdateEvent]] = None
    """
    Called when the user interacts with the viewer.
    """
    # scrollbarTheme
    thumbs_color: Optional[ColorValue] = None
    """
    Defines the color of the thumbs when interacting with the viewer.
    """

    async def get_transformation_data(self) -> tuple[float, float, float]:
        """
        Gets the transformation data for this viewer.

        Returns:
            offset_x (float): The horizontal translation of the content.
            offset_y (float): The vertical translation of the content.
            scale (float): The current scale factor.
        """
        data = await self._invoke_method("get_transformation_data", {})
        return data["offset_x"], data["offset_y"], data["scale"]

    async def set_transformation_data(self, offset_x: Optional[Number] = None, offset_y: Optional[Number] = None,
                                      scale: Optional[Number] = None, animation_duration: Optional[DurationValue] = None):
        """
        Translate the current transformation matrix.
        By default, the translation is with no animation (immediately).

        Args:
            offset_x: The horizontal translation of the content.
            offset_y: The vertical translation of the content.
            scale: The scale factor.
            animation_duration: The duration of the animation. If `None`, the reset is applied immediately.
        """
        await self._invoke_method(
            "set_transformation_data",
            arguments={
                "offSetX": offset_x,
                "offSetY": offset_y,
                "scale": scale,
                "duration": animation_duration
            },
        )

    async def reset(self, animation_duration: Optional[DurationValue] = None):
        """
        Reset the viewer transformation matrix.
        By default, the translation is with no animation (immediately).

        Args:
            animation_duration: Animation duration for the reset transition. If `None`, the reset is applied immediately.
        """
        await self._invoke_method(
            "reset", arguments={
                "duration": animation_duration
            }
        )

    async def zoom(self, factor: Number):
        """
        Applies multiplicative zoom to the current transform.

        Args:
            factor: Scale multiplier relative to the current scale.
                Values greater than `1` zoom in, values between `0` and `1`
                zoom out.

        Note:
            The resulting scale is NOT clamped to `min_scale` or `max_scale`.
            The only restriction applied is based on `over_zoom_enabled`
            to prevent the content from shrinking smaller than the viewport.
        """
        await self._invoke_method("zoom", arguments={
            "factor": factor
        })