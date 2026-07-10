// https://github.com/PraiseTheDarkFlo/flet-extended-interactive-viewer

import 'dart:math' as math;

import 'package:flet/flet.dart';
import 'package:flutter/material.dart';

// TODO Update deprecated code

// child class to handle size change event
class _ChildSize extends StatefulWidget {
  final Widget child;
  final Function(Size) onSizeChanged;

  const _ChildSize({
    required this.child,
    required this.onSizeChanged,
  });

  @override
  State<_ChildSize> createState() => _ChildSizeState();
}

class _ChildSizeState extends State<_ChildSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSize = context.size;
      if (currentSize != null && _lastSize != currentSize) {
        _lastSize = currentSize;
        widget.onSizeChanged(currentSize);
      }
    });
    return widget.child;
  }
}

//main class
class ExtendedInteractiveViewerControl extends StatefulWidget {
  final Control control;

  ExtendedInteractiveViewerControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<ExtendedInteractiveViewerControl> createState() =>
      _ExtendedInteractiveViewerControlState();
}

// state control with state attributes
class _ExtendedInteractiveViewerControlState extends State<ExtendedInteractiveViewerControl> with SingleTickerProviderStateMixin{
  // attributes
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  bool _ignoreTransformationChange = false;
  bool _ignorScroll = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  Size? _childSize;
  Size? _viewportSize;
  double? _scale;
  VoidCallback _animationListener = (){};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: Duration.zero);
    _transformationController.addListener(_onTransformationChanged);
    _horizontalScrollController.addListener(_onScroll);
    _verticalScrollController.addListener(_onScroll);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  //Catches method call which comes from the python file
  Future<dynamic> _invokeMethod(String name, args) async {
    debugPrint("InteractiveViewer.$name($args)");
    switch (name) {
      case "zoom":
        var factor = parseDouble(args["factor"]);
        if (factor == null) return null;
        if (_viewportSize == null || _childSize == null) return null;

        final matrix = _transformationController.value;
        final screenCenter = Offset(_viewportSize!.width / 2, _viewportSize!.height / 2);

        final contentCenter = MatrixUtils.transformPoint(matrix.clone()..invert(), screenCenter);

        double newScale = _scale! * factor;

        double contentWidth = _childSize!.width * newScale;
        double contentHeight = _childSize!.height * newScale;

        // Prevent zooming out so far that the content is smaller than the viewport,
        // unless overZoomEnabled is true.
        final overZoomEnabled = widget.control.getBool("over_zoom_enabled", false)!;
        if (!overZoomEnabled) {
          if (contentWidth < _viewportSize!.width || contentHeight < _viewportSize!.height) {
            newScale = math.max(
              _viewportSize!.width / _childSize!.width,
              _viewportSize!.height / _childSize!.height,
            );
            factor = newScale / _scale!;
            contentWidth = _childSize!.width * newScale;
            contentHeight = _childSize!.height * newScale;
          }
        }

        Matrix4 newMatrix = matrix.clone()
          ..translate(contentCenter.dx, contentCenter.dy)
          ..scale(factor, factor)
          ..translate(-contentCenter.dx, -contentCenter.dy);

        final translation = newMatrix.getTranslation();
        double maxScrollX = math.max(0.0, contentWidth - _viewportSize!.width);
        double maxScrollY = math.max(0.0, contentHeight - _viewportSize!.height);

        double clampedX = (-translation.x).clamp(0.0, maxScrollX);
        double clampedY = (-translation.y).clamp(0.0, maxScrollY);

        if (clampedX == maxScrollX) clampedX = maxScrollX;
        if (clampedY == maxScrollY) clampedY = maxScrollY;

        newMatrix.setTranslationRaw(-clampedX, -clampedY, translation.z);

        _transformationController.value = newMatrix;
        return null;
      case "get_transformation_data":
        final translation = _transformationController.value.getTranslation();
        double offset_x = translation.x;
        double offset_y = translation.y;
        double scale = _transformationController.value.getMaxScaleOnAxis();
        final eventData = {
          "offset_x": offset_x,
          "offset_y": offset_y,
          "scale": scale,
        };
        return  eventData;
      case "set_transformation_data":
        if (_viewportSize == null || _childSize == null) return null;
        var off_set_x = parseDouble(args["offSetX"],0)!;
        var off_set_y = parseDouble(args["offSetY"],0)!;
        var scale = parseDouble(args["scale"],1)!;
        var animationDuration = parseDuration(args["duration"]?? 0);

        double contentWidth = _childSize!.width * scale;
        double contentHeight = _childSize!.height * scale;

        double maxScrollX = math.max(0, contentWidth - _viewportSize!.width);
        double maxScrollY = math.max(0, contentHeight - _viewportSize!.height);

        double scrollX = (-off_set_x).clamp(0.0, maxScrollX);
        double scrollY = (-off_set_y).clamp(0.0, maxScrollY);
        if (animationDuration == 0) {
          _transformationController.value = Matrix4.identity()
            ..scale(scale, scale)
            ..translate(-scrollX / scale, -scrollY / scale);
        } else {
          final startScale = _scale!;
          final startTranslation = _transformationController.value.getTranslation();

          final scaleTween = Tween<double>(begin: startScale, end: scale);
          final offsetTween = Tween<Offset>(
            begin: Offset(-startTranslation.x * startScale, -startTranslation.y * startScale),
            end: Offset(scrollX, scrollY),
          );

          _animationController.duration = animationDuration;
          _animationController.removeListener(_animationListener);
          _animationListener = () {
            final s = scaleTween.evaluate(_animationController);
            final offset = offsetTween.evaluate(_animationController);

            _transformationController.value = Matrix4.identity()
              ..scale(s, s)
              ..translate(-offset.dx / s, -offset.dy / s);
          };
          _animationController.addListener(_animationListener);
          _animationController.forward(from: 0);
        }
        return null;
      case "reset":
        var animationDuration = parseDuration(args["duration"] ?? 0);
        if (animationDuration == 0) {
          _transformationController.value = Matrix4.identity();
        } else {
          _animationController.duration = animationDuration;
          _animation = Matrix4Tween(
            begin: _transformationController.value,
            end: Matrix4.identity(),
          ).animate(_animationController)
            ..addListener(() {
              _transformationController.value = _animation!.value;
            });
          _animationController.forward(from: 0);
        }
        return null;
      default:
        throw Exception("Unknown ExtendedInteractiveViewer method: $name");
    }
  }
  // handles when the transformation of the interactive_viewer got changed
  void _onTransformationChanged() {
    if (_ignoreTransformationChange) return;
    if (_viewportSize == null || _childSize == null) return;

    final translation = _transformationController.value.getTranslation();
    double scale = _transformationController.value.getMaxScaleOnAxis();

    double contentWidth = _childSize!.width * scale;
    double contentHeight = _childSize!.height * scale;

    double maxScrollX = math.max(0.0, contentWidth - _viewportSize!.width);
    double maxScrollY = math.max(0.0, contentHeight - _viewportSize!.height);

    double scrollX = (-translation.x).clamp(0.0, maxScrollX);
    double scrollY = (-translation.y).clamp(0.0, maxScrollY);

    _ignorScroll = true; // prevent loop
    _horizontalScrollController.jumpTo(scrollX);
    _verticalScrollController.jumpTo(scrollY);
    // check if scale changed so rebuild to generate new slider for the new scale
    if (mounted && scale != _scale) {
      setState(() {
        // rebuild
      });
    }
    final eventData = {
      "offset_x": scrollX,
      "offset_y": scrollY,
      "scale": scale,
    };
    widget.control.triggerEvent("interaction_update", eventData);
    _ignorScroll = false;
  }

  // handles when the scrollbars got scrolled
  void _onScroll() {
    if (_ignorScroll) return;
    if (_viewportSize == null || _childSize == null) return;
    double scrollX = 0;
    double scrollY = 0;
    if (_horizontalScrollController.hasClients) {
      scrollX = _horizontalScrollController.position.pixels;
    }
    if (_verticalScrollController.hasClients) {
      scrollY = _verticalScrollController.position.pixels;
    }
    double scale = _transformationController.value.getMaxScaleOnAxis();

    _ignoreTransformationChange = true; // prevent loop
    Matrix4 newMatrix = Matrix4.identity()
      ..scale(scale, scale)
      ..translate(-scrollX / scale, -scrollY / scale);
    _transformationController.value = newMatrix;
    _ignoreTransformationChange = false;
  }

  // update if size of child changed
  void _onChildSizeChanged(Size size) {
    if (size != _childSize) {
      setState(() {
        _childSize = size;
      });
      _onTransformationChanged();
    }
  }

  // clean up method
  @override
  void dispose() {
    // clean up all attributes which has objects and/or has listener assigned
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    _verticalScrollController.removeListener(_onScroll);
    _verticalScrollController.dispose();
    _horizontalScrollController.removeListener(_onScroll);
    _horizontalScrollController.dispose();

    // unsubscribe so no longer methode call gets forwarded
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // get child for interactive_viewer
    List<Widget> contentItems = widget.control.buildWidgets("content");

    //Placeholder if no content is provided
    if (contentItems.isEmpty) {
      contentItems = [
        Container(
          child: const Center(
            child: Text(
              "No content provided to show!",
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ),
      ];
    }

    ScrollbarThemeData scrollbarTheme = ScrollbarThemeData(
      mainAxisMargin: 2.0,
      crossAxisMargin: 2.0,
      trackBorderColor: null,
      thumbColor: WidgetStatePropertyAll(widget.control.getColor("thumbs_color", context)),
    );

    // create interactive_viewer
    Widget interactive_viewer = LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _onTransformationChanged();
          }
        });

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.zero,
          minScale: widget.control.getDouble("min_scale", 0.8)!,
          maxScale: widget.control.getDouble("max_scale", 2.5)!,
          panEnabled: widget.control.getBool("pan_enabled", true)!,
          scaleEnabled: widget.control.getBool("scale_enabled", true)!,
          scaleFactor: widget.control.getDouble("scale_factor", 200)!,
          constrained: widget.control.getBool("constrained", false)!,
          child: _ChildSize(
            onSizeChanged: _onChildSizeChanged,
            child: contentItems.first,
          ),
        );
      },
    );

    _scale = _transformationController.value.getMaxScaleOnAxis();

    // calc current content width and high
    double contentWidth = _childSize != null ? _childSize!.width * _scale! : 0;
    double contentHeight = _childSize != null ? _childSize!.height * _scale! : 0;

    // calc max off_set x and y
    double maxScrollX = math.max(0, contentWidth - (_viewportSize?.width ?? 0));
    double maxScrollY = math.max(0, contentHeight - (_viewportSize?.height ?? 0));

    // check if x and y scrollbars should spawn
    bool check_spawn_x = (maxScrollX > 0 && widget.control.getBool("x_scroll_enabled", true)!);
    bool check_spawn_y = (maxScrollY > 0 &&  widget.control.getBool("y_scroll_enabled", true)!);

    Widget fei = Stack(
      children: [
        Positioned.fill(child: interactive_viewer),

        if (check_spawn_x)
          Positioned(
            left: 0,
            right: check_spawn_y ? 12 : 0,
            bottom: 0,
            child: SizedBox(
              height: 12,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: widget.control.getBool("interactive_scroll_enabled", true)!
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: check_spawn_y? contentWidth-12:contentWidth,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),

        if (check_spawn_y)
          Positioned(
            top: 0,
            right: 0,
            bottom: check_spawn_x ? 12 : 0,
            child: SizedBox(
              width: 12,
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  physics: widget.control.getBool("interactive_scroll_enabled", true)!
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: 1,
                    height: check_spawn_x? contentHeight-12:contentHeight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    Widget themedFei = Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: scrollbarTheme,
      ),
      child: fei,
    );

    return LayoutControl(control: widget.control, child: themedFei);
  }
}