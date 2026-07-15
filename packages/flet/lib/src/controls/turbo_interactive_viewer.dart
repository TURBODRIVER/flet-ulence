import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

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

class TurboInteractiveViewerControl extends StatefulWidget {
  final Control control;

  TurboInteractiveViewerControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<TurboInteractiveViewerControl> createState() =>
      _TurboInteractiveViewerControlState();
}

class _TurboInteractiveViewerControlState extends State<TurboInteractiveViewerControl> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  bool _ignoreTransformationChange = false;
  bool _ignoreScroll = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  Size? _childSize;
  Size? _viewportSize;
  double? _scale;
  VoidCallback _animationListener = (){};

  int _interactionUpdateInterval = 200;
  int _interactionUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
  double? _lastEmittedOffsetX;
  double? _lastEmittedOffsetY;
  double? _lastEmittedScale;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: Duration.zero);
    _transformationController.addListener(_onTransformationChanged);
    _horizontalScrollController.addListener(_onScroll);
    _verticalScrollController.addListener(_onScroll);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("TurboInteractiveViewer.$name($args)");
    switch (name) {
      case "get_transformation_data":
        final double scale = _transformationController.value.getMaxScaleOnAxis();
        final offsetX = _offsetXFromMatrix(_transformationController.value, scale);
        final offsetY = _offsetYFromMatrix(_transformationController.value, scale);
        return {
          "offset_x": offsetX,
          "offset_y": offsetY,
          "scale": scale,
        };

      case "set_transformation_data":
        if (_viewportSize == null || _childSize == null || _scale == null) {
          return null;
        }

        final Matrix4 startMatrix = _transformationController.value.clone();
        final double startScale = _scale!;
        final double startOffsetX = _offsetXFromMatrix(startMatrix, startScale);
        final double startOffsetY = _offsetYFromMatrix(startMatrix, startScale);

        final double targetScale = parseDouble(args["scale"]) ?? startScale;
        final double rawOffsetX = parseDouble(args["offsetX"]) ?? startOffsetX;
        final double rawOffsetY = parseDouble(args["offsetY"]) ?? startOffsetY;

        final double targetOffsetX = _clampOffsetX(rawOffsetX, targetScale);
        final double targetOffsetY = _clampOffsetY(rawOffsetY, targetScale);

        final animationDuration = parseDuration(args["duration"]);
        final animationCurve = parseCurve(args["curve"], Curves.linear);

        final Matrix4 targetMatrix = _matrixFromOffset(targetOffsetX, targetOffsetY, targetScale);

        if (animationDuration == null) {
          _transformationController.value = targetMatrix;
        } else {
          _animationController.duration = animationDuration;
          _animationController.removeListener(_animationListener);

          final curvedAnimation = CurvedAnimation(
            parent: _animationController,
            curve: animationCurve!,
          );

          final scaleTween = Tween<double>(begin: startScale, end: targetScale);
          final Offset finalViewportPoint = _viewportPointForOffset(targetOffsetX, targetOffsetY, targetScale);
          final Matrix4 inverseTarget = Matrix4.inverted(targetMatrix);
          final Offset focalScenePoint = _matrixTransformPoint(inverseTarget, finalViewportPoint);
          final Offset startViewportPoint = _matrixTransformPoint(startMatrix, focalScenePoint);

          final viewportPointTween = Tween<Offset>(
            begin: startViewportPoint,
            end: finalViewportPoint,
          );

          _animationListener = () {
            final s = scaleTween.evaluate(curvedAnimation);
            final vp = viewportPointTween.evaluate(curvedAnimation);

            _transformationController.value = _matrixFromFocalPoint(
              scenePoint: focalScenePoint,
              viewportPoint: vp,
              scale: s,
            );
          };

          _animationController.addListener(_animationListener);
          _animationController.forward(from: 0);
        }
        return null;

      default:
        throw Exception("Unknown TurboInteractiveViewer method: $name");
    }
  }

  void _onTransformationChanged() {
    if (_ignoreTransformationChange) return;
    if (_viewportSize == null || _childSize == null) return;

    final double scale = _transformationController.value.getMaxScaleOnAxis();
    final double offsetX = _offsetXFromMatrix(_transformationController.value, scale);
    final double offsetY = _offsetYFromMatrix(_transformationController.value, scale);

    final double clampedOffsetX = _clampOffsetX(offsetX, scale);
    final double clampedOffsetY = _clampOffsetY(offsetY, scale);

    final double screenScrollX = clampedOffsetX * scale;
    final double screenScrollY = clampedOffsetY * scale;

    _ignoreScroll = true; // prevent feedback loop
    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(screenScrollX);
    }
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.jumpTo(screenScrollY);
    }

    // Rebuild if scale changed to update scrollbars
    if (mounted && scale != _scale) {
      setState(() {
        // rebuild
      });
    }

    _triggerInteractionUpdate(clampedOffsetX, clampedOffsetY, scale);
    _ignoreScroll = false;
  }

  void _onScroll() {
    if (_ignoreScroll) return;
    if (_viewportSize == null || _childSize == null) return;

    double screenScrollX = 0;
    double screenScrollY = 0;
    if (_horizontalScrollController.hasClients) {
      screenScrollX = _horizontalScrollController.position.pixels;
    }
    if (_verticalScrollController.hasClients) {
      screenScrollY = _verticalScrollController.position.pixels;
    }

    final double scale = _transformationController.value.getMaxScaleOnAxis();
    final double offsetX = screenScrollX / scale;
    final double offsetY = screenScrollY / scale;

    _ignoreTransformationChange = true;
    _transformationController.value = _matrixFromOffset(offsetX, offsetY, scale);
    _triggerInteractionUpdate(offsetX, offsetY, scale);
    _ignoreTransformationChange = false;
  }

  void _triggerInteractionUpdate(double offsetX, double offsetY, double scale) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _interactionUpdateTimestamp < _interactionUpdateInterval) return;

    const epsilon = 1e-6;
    final unchanged = _lastEmittedOffsetX != null &&
        _lastEmittedOffsetY != null &&
        _lastEmittedScale != null &&
        (offsetX - _lastEmittedOffsetX!).abs() < epsilon &&
        (offsetY - _lastEmittedOffsetY!).abs() < epsilon &&
        (scale - _lastEmittedScale!).abs() < epsilon;
    if (unchanged) return;

    _interactionUpdateTimestamp = now;
    _lastEmittedOffsetX = offsetX;
    _lastEmittedOffsetY = offsetY;
    _lastEmittedScale = scale;

    widget.control.triggerEvent("interaction_update", {
      "offset_x": offsetX,
      "offset_y": offsetY,
      "scale": scale,
    });
  }

  void _onTapUp(TapUpDetails details) {
    widget.control.triggerEvent("click", {
      "local_x": details.localPosition.dx,
      "local_y": details.localPosition.dy,
      "global_x": details.globalPosition.dx,
      "global_y": details.globalPosition.dy,
    });
  }

  void _onChildSizeChanged(Size size) {
    if (size != _childSize) {
      setState(() {
        _childSize = size;
      });
      _onTransformationChanged();
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    _verticalScrollController.removeListener(_onScroll);
    _verticalScrollController.dispose();
    _horizontalScrollController.removeListener(_onScroll);
    _horizontalScrollController.dispose();
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("TurboInteractiveViewer build: ${widget.control.id}");

    List<Widget> contents = widget.control.buildWidgets("content");
    if (contents.isEmpty) {
      return const ErrorControl(
          "InteractiveViewer.content must be provided and visible");
    }

    _interactionUpdateInterval = widget.control.getInt("interaction_update_interval", 200)!;

    ScrollbarThemeData scrollbarTheme = ScrollbarThemeData(
      mainAxisMargin: 2.0,
      crossAxisMargin: 2.0,
      trackBorderColor: const WidgetStatePropertyAll(null),
      thumbColor: WidgetStatePropertyAll(widget.control.getColor("thumbs_color", context)),
    );

    Widget interactiveViewer = LayoutBuilder(
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _onTapUp,
            child: _ChildSize(
              onSizeChanged: _onChildSizeChanged,
              child: contents.first,
            ),
          ),
        );
      },
    );

    _scale = _transformationController.value.getMaxScaleOnAxis();

    double contentWidth = _childSize != null ? _childSize!.width * _scale! : 0;
    double contentHeight = _childSize != null ? _childSize!.height * _scale! : 0;

    double maxScrollX = math.max(0, contentWidth - (_viewportSize?.width ?? 0));
    double maxScrollY = math.max(0, contentHeight - (_viewportSize?.height ?? 0));

    bool spawnX = (maxScrollX > 0 && widget.control.getBool("x_scroll_enabled", true)!);
    bool spawnY = (maxScrollY > 0 && widget.control.getBool("y_scroll_enabled", true)!);

    final scrollPhysics =
        widget.control.getBool("interactive_scroll_enabled", true)!
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics();

    Widget fei = Stack(
      children: [
        Positioned.fill(child: interactiveViewer),
        if (spawnX)
          Positioned(
            left: 0,
            right: spawnY ? 12 : 0,
            bottom: 0,
            child: SizedBox(
              height: 12,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: scrollPhysics,
                  child: SizedBox(
                    width: spawnY ? contentWidth - 12 : contentWidth,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        if (spawnY)
          Positioned(
            top: 0,
            right: 0,
            bottom: spawnX ? 12 : 0,
            child: SizedBox(
              width: 12,
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  physics: scrollPhysics,
                  child: SizedBox(
                    width: 1,
                    height: spawnX ? contentHeight - 12 : contentHeight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    Widget themedFei = Theme(
      data: Theme.of(context).copyWith(scrollbarTheme: scrollbarTheme),
      child: fei,
    );

    return LayoutControl(control: widget.control, child: themedFei);
  }

  double _maxScrollX(double scale) {
    if (_childSize == null || _viewportSize == null) return 0.0;
    return math.max(0.0, _childSize!.width * scale - _viewportSize!.width);
  }

  double _maxScrollY(double scale) {
    if (_childSize == null || _viewportSize == null) return 0.0;
    return math.max(0.0, _childSize!.height * scale - _viewportSize!.height);
  }

  double _clampOffsetX(double offsetX, double scale) {
    final maxScrollX = _maxScrollX(scale);
    final screenScrollX = clampDouble(offsetX * scale, 0.0, maxScrollX);
    return screenScrollX / scale;
  }

  double _clampOffsetY(double offsetY, double scale) {
    final maxScrollY = _maxScrollY(scale);
    final screenScrollY = clampDouble(offsetY * scale, 0.0, maxScrollY);
    return screenScrollY / scale;
  }

  double _offsetXFromMatrix(Matrix4 matrix, double scale) {
    return -matrix.getTranslation().x / scale;
  }

  double _offsetYFromMatrix(Matrix4 matrix, double scale) {
    return -matrix.getTranslation().y / scale;
  }

  Matrix4 _matrixFromOffset(double offsetX, double offsetY, double scale) {
    final screenScrollX = offsetX * scale;
    final screenScrollY = offsetY * scale;
    return Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1.0)
      ..translateByDouble(-screenScrollX / scale, -screenScrollY / scale, 0.0, 1.0);
  }

  Offset _matrixTransformPoint(Matrix4 matrix, Offset point) {
    return MatrixUtils.transformPoint(matrix, point);
  }

  Offset _viewportPointForOffset(double offsetX, double offsetY, double scale) {
    final screenScrollX = offsetX * scale;
    final screenScrollY = offsetY * scale;
    return Offset(-screenScrollX, -screenScrollY);
  }

  Matrix4 _matrixFromFocalPoint({
    required Offset scenePoint,
    required Offset viewportPoint,
    required double scale,
  }) {
    return Matrix4.identity()
      ..translateByDouble(viewportPoint.dx, viewportPoint.dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0.0, 1.0);
  }

}
