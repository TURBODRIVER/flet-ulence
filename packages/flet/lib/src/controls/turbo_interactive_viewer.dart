import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class _SizeReporter extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSizeChanged;

  const _SizeReporter({
    required this.onSizeChanged,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReporter(onSizeChanged);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderSizeReporter renderObject) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();

    final newSize = size;
    if (_lastReportedSize == newSize) return;
    _lastReportedSize = newSize;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSizeChanged(newSize);
    });
  }
}

class TurboInteractiveViewerControl extends StatefulWidget {
  final Control control;

  TurboInteractiveViewerControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<TurboInteractiveViewerControl> createState() => _TurboInteractiveViewerControlState();
}

class _TurboInteractiveViewerControlState extends State<TurboInteractiveViewerControl> with SingleTickerProviderStateMixin {
  static const double _scrollbarThickness = 12.0;
  static const double _epsilon = 1e-6;

  final TransformationController _transformationController = TransformationController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  Size? _childSize;
  Size? _viewportSize;

  bool _syncingFromTransform = false;
  bool _syncingFromScroll = false;

  late AnimationController _animationController;
  VoidCallback? _animationListener;

  int _interactionUpdateInterval = 200;
  int _interactionUpdateTimestamp = 0;
  double? _lastEmittedOffsetX;
  double? _lastEmittedOffsetY;
  double? _lastEmittedScale;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    _animationController = AnimationController(vsync: this, duration: Duration.zero);
    _horizontalScrollController.addListener(_onScrollChanged);
    _verticalScrollController.addListener(_onScrollChanged);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("TurboInteractiveViewer.$name($args)");
    switch (name) {
      case "get_transformation_data":
        final data = _currentTransformData();
        return {
          "offset_x": data.offsetX,
          "offset_y": data.offsetY,
          "scale": data.scale,
        };

      case "set_transformation_data":
        if (!_hasGeometry) return null;

        final startMatrix = _transformationController.value.clone();
        final startData = _currentTransformData();

        final targetScale = parseDouble(args["scale"]) ?? startData.scale;
        final rawOffsetX = parseDouble(args["offset_x"]) ?? startData.offsetX;
        final rawOffsetY = parseDouble(args["offset_y"]) ?? startData.offsetY;

        final targetOffsetX = _clampOffsetX(rawOffsetX, targetScale);
        final targetOffsetY = _clampOffsetY(rawOffsetY, targetScale);

        final animationDuration = parseDuration(args["duration"]);
        final animationCurve = parseCurve(args["curve"], Curves.linear)!;

        final targetMatrix = _matrixFromOffset(
          targetOffsetX,
          targetOffsetY,
          targetScale,
        );

        if (animationDuration == null) {
          _setMatrix(targetMatrix, emitInteraction: true);
          _syncScrollbarsToTransform();
          return null;
        }

        if (_animationListener != null) {
          _animationController.removeListener(_animationListener!);
        }

        _animationController.duration = animationDuration;

        final curvedAnimation = CurvedAnimation(
          parent: _animationController,
          curve: animationCurve,
        );

        final scaleTween = Tween<double>(
          begin: startData.scale,
          end: targetScale,
        );

        final finalViewportPoint = _viewportPointForOffset(
          targetOffsetX,
          targetOffsetY,
          targetScale,
        );

        final inverseTarget = Matrix4.inverted(targetMatrix);
        final focalScenePoint = _matrixTransformPoint(inverseTarget, finalViewportPoint);
        final startViewportPoint = _matrixTransformPoint(startMatrix, focalScenePoint);

        final viewportPointTween = Tween<Offset>(
          begin: startViewportPoint,
          end: finalViewportPoint,
        );

        _animationListener = () {
          final scale = scaleTween.evaluate(curvedAnimation);
          final viewportPoint = viewportPointTween.evaluate(curvedAnimation);

          _setMatrix(
            _matrixFromFocalPoint(
              scenePoint: focalScenePoint,
              viewportPoint: viewportPoint,
              scale: scale,
            ),
            emitInteraction: true,
          );
        };

        _animationController.addListener(_animationListener!);
        _animationController.forward(from: 0);

        return null;

      default:
        throw Exception("Unknown TurboInteractiveViewer method: $name");
    }
  }

  void _onTransformationChanged() {
    if (_syncingFromScroll) return;
    _syncScrollbarsToTransform(rebuild: true);
  }

  void _onScrollChanged() {
    if (_syncingFromTransform) return;
    if (!_hasGeometry) return;

    final scale = _currentScale;
    if (scale <= 0) return;

    final screenScrollX = _horizontalScrollController.hasClients
        ? _horizontalScrollController.position.pixels
        : 0.0;
    final screenScrollY = _verticalScrollController.hasClients
        ? _verticalScrollController.position.pixels
        : 0.0;

    final offsetX = _clampOffsetX(screenScrollX / scale, scale);
    final offsetY = _clampOffsetY(screenScrollY / scale, scale);

    _syncingFromScroll = true;
    _setMatrix(_matrixFromOffset(offsetX, offsetY, scale), emitInteraction: false);
    _syncingFromScroll = false;

    _triggerInteractionUpdate(offsetX, offsetY, scale);
  }

  void _triggerInteractionUpdate(double offsetX, double offsetY, double scale) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _interactionUpdateTimestamp < _interactionUpdateInterval) return;

    final unchanged =
        _lastEmittedOffsetX != null &&
        _lastEmittedOffsetY != null &&
        _lastEmittedScale != null &&
        (offsetX - _lastEmittedOffsetX!).abs() < _epsilon &&
        (offsetY - _lastEmittedOffsetY!).abs() < _epsilon &&
        (scale - _lastEmittedScale!).abs() < _epsilon;

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

  void _updateChildSize(Size size) {
    if (size == _childSize) return;

    setState(() {
      _childSize = size;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncScrollbarsToTransform(rebuild: true);
      }
    });
  }

  @override
  void dispose() {
    if (_animationListener != null) {
      _animationController.removeListener(_animationListener!);
    }
    _animationController.dispose();

    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _horizontalScrollController.removeListener(_onScrollChanged);
    _horizontalScrollController.dispose();
    _verticalScrollController.removeListener(_onScrollChanged);
    _verticalScrollController.dispose();

    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("TurboInteractiveViewer build: ${widget.control.id}");

    final contents = widget.control.buildWidgets("content");
    if (contents.isEmpty) {
      return const ErrorControl(
        "InteractiveViewer.content must be provided and visible"
      );
    }

    _interactionUpdateInterval = widget.control.getInt("interaction_update_interval", 200)!;

    final scrollbarTheme = ScrollbarThemeData(
      mainAxisMargin: 2.0,
      crossAxisMargin: 2.0,
      trackBorderColor: const WidgetStatePropertyAll(null),
      thumbColor: WidgetStatePropertyAll(
        widget.control.getColor("thumbs_color", context),
      ),
    );

    final scale = _currentScale;
    final viewportWidth = _viewportSize?.width ?? 0.0;
    final viewportHeight = _viewportSize?.height ?? 0.0;
    final contentWidth = (_childSize?.width ?? 0.0) * scale;
    final contentHeight = (_childSize?.height ?? 0.0) * scale;

    final maxScrollX = math.max(0.0, contentWidth - viewportWidth);
    final maxScrollY = math.max(0.0, contentHeight - viewportHeight);

    final spawnX = maxScrollX > 0 && widget.control.getBool("x_scroll_enabled", true)!;
    final spawnY = maxScrollY > 0 && widget.control.getBool("y_scroll_enabled", true)!;

    final scrollPhysics =
        widget.control.getBool("interactive_scroll_enabled", true)!
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics();

    final viewer = _SizeReporter(
      onSizeChanged: _updateViewportSize,
      child: InteractiveViewer(
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
          child: _SizeReporter(
            onSizeChanged: _updateChildSize,
            child: contents.first,
          ),
        ),
      ),
    );

    final stack = Stack(
      children: [
        Positioned.fill(child: viewer),
        if (spawnX)
          Positioned(
            left: 0, bottom: 0,
            right: spawnY ? _scrollbarThickness : 0,
            child: SizedBox(
              height: _scrollbarThickness,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: scrollPhysics,
                  child: SizedBox(
                    width: math.max(
                      0.0,
                      spawnY ? contentWidth - _scrollbarThickness : contentWidth,
                    ),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        if (spawnY)
          Positioned(
            top: 0, right: 0,
            bottom: spawnX ? _scrollbarThickness : 0,
            child: SizedBox(
              width: _scrollbarThickness,
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  physics: scrollPhysics,
                  child: SizedBox(
                    width: 1,
                    height: math.max(
                      0.0,
                      spawnX ? contentHeight - _scrollbarThickness : contentHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return LayoutControl(
      control: widget.control,
      child: Theme(
        data: Theme.of(context).copyWith(scrollbarTheme: scrollbarTheme),
        child: stack,
      ),
    );
  }

  void _updateViewportSize(Size size) {
    if (size == _viewportSize) return;

    setState(() {
      _viewportSize = size;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncScrollbarsToTransform(rebuild: true);
      }
    });
  }

  void _syncScrollbarsToTransform({bool rebuild = false}) {
    if (!_hasGeometry) return;

    final data = _currentTransformData();
    final clampedOffsetX = _clampOffsetX(data.offsetX, data.scale);
    final clampedOffsetY = _clampOffsetY(data.offsetY, data.scale);

    final needsClamp =
        (clampedOffsetX - data.offsetX).abs() > _epsilon ||
        (clampedOffsetY - data.offsetY).abs() > _epsilon;

    if (needsClamp) {
      _syncingFromTransform = true;
      _setMatrix(
        _matrixFromOffset(clampedOffsetX, clampedOffsetY, data.scale),
        emitInteraction: false,
      );
      _syncingFromTransform = false;
    }

    final screenScrollX = clampedOffsetX * data.scale;
    final screenScrollY = clampedOffsetY * data.scale;

    _syncingFromTransform = true;
    if (_horizontalScrollController.hasClients) {
      final max = _horizontalScrollController.position.maxScrollExtent;
      _horizontalScrollController.jumpTo(clampDouble(screenScrollX, 0.0, max));
    }
    if (_verticalScrollController.hasClients) {
      final max = _verticalScrollController.position.maxScrollExtent;
      _verticalScrollController.jumpTo(clampDouble(screenScrollY, 0.0, max));
    }
    _syncingFromTransform = false;

    _triggerInteractionUpdate(clampedOffsetX, clampedOffsetY, data.scale);

    if (mounted && rebuild) {
      setState(() {});
    }
  }

  bool get _hasGeometry => _childSize != null && _viewportSize != null;

  ({double offsetX, double offsetY, double scale}) _currentTransformData() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    return (
      offsetX: _offsetXFromMatrix(matrix, scale),
      offsetY: _offsetYFromMatrix(matrix, scale),
      scale: scale,
    );
  }

  double get _currentScale => _transformationController.value.getMaxScaleOnAxis();

  void _setMatrix(Matrix4 matrix, {bool emitInteraction = true}) {
    _transformationController.value = matrix;
    if (!emitInteraction) return;
    final data = _currentTransformData();
    _triggerInteractionUpdate(data.offsetX, data.offsetY, data.scale);
  }

  double _maxScrollX(double scale) {
    if (!_hasGeometry) return 0.0;
    return math.max(0.0, _childSize!.width * scale - _viewportSize!.width);
  }

  double _maxScrollY(double scale) {
    if (!_hasGeometry) return 0.0;
    return math.max(0.0, _childSize!.height * scale - _viewportSize!.height);
  }

  double _clampOffsetX(double offsetX, double scale) {
    if (scale <= 0) return 0.0;
    final screenScrollX = clampDouble(offsetX * scale, 0.0, _maxScrollX(scale));
    return screenScrollX / scale;
  }

  double _clampOffsetY(double offsetY, double scale) {
    if (scale <= 0) return 0.0;
    final screenScrollY = clampDouble(offsetY * scale, 0.0, _maxScrollY(scale));
    return screenScrollY / scale;
  }

  double _offsetXFromMatrix(Matrix4 matrix, double scale) {
    if (scale <= 0) return 0.0;
    return -matrix.getTranslation().x / scale;
  }

  double _offsetYFromMatrix(Matrix4 matrix, double scale) {
    if (scale <= 0) return 0.0;
    return -matrix.getTranslation().y / scale;
  }

  Matrix4 _matrixFromOffset(double offsetX, double offsetY, double scale) {
    final screenScrollX = offsetX * scale;
    final screenScrollY = offsetY * scale;
    return Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1.0)
      ..translateByDouble(
        -screenScrollX / scale, -screenScrollY / scale, 0.0, 1.0,
      );
  }

  Offset _matrixTransformPoint(Matrix4 matrix, Offset point) {
    return MatrixUtils.transformPoint(matrix, point);
  }

  Offset _viewportPointForOffset(double offsetX, double offsetY, double scale) {
    return Offset(-(offsetX * scale), -(offsetY * scale));
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
