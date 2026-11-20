import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/canvas/canvas_editor_controller.dart';
import '../../../application/canvas/canvas_tool.dart';
import '../../../core/geometry/viewport_transform.dart';
import '../../../domain/elements/rectangle_element.dart';

class CanvasViewport extends StatefulWidget {
  const CanvasViewport({
    required this.controller,
    super.key,
  });

  final CanvasEditorController controller;

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  ViewportTransform _transform = const ViewportTransform();
  final FocusNode _focusNode = FocusNode(debugLabel: 'FlutterDraw canvas');

  bool _spacePressed = false;
  bool _isPanning = false;
  int? _drawingPointer;
  Offset? _lastPointerPosition;
  Offset? _lastPanZoomOffset;
  double _lastPanZoomScale = 1;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _panBy(Offset delta) {
    if (delta == Offset.zero) return;
    setState(() {
      _transform = _transform.panBy(Point2(delta.dx, delta.dy));
    });
  }

  void _zoomAt(Offset screenPosition, double scaleFactor) {
    setState(() {
      _transform = _transform.zoomAt(
        screenAnchor: Point2(screenPosition.dx, screenPosition.dy),
        scaleFactor: scaleFactor,
      );
    });
  }

  Point2 _toWorld(Offset localPosition) {
    return _transform.screenToWorld(
      Point2(localPosition.dx, localPosition.dy),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();

    final isMouse = event.kind == PointerDeviceKind.mouse;
    final isMiddleMouse =
        isMouse && event.buttons & kMiddleMouseButton != 0;
    final isSpaceDrag =
        isMouse && _spacePressed && event.buttons & kPrimaryMouseButton != 0;

    if (isMiddleMouse || isSpaceDrag ||
        widget.controller.activeTool == CanvasTool.hand) {
      setState(() {
        _isPanning = true;
        _lastPointerPosition = event.localPosition;
      });
      return;
    }

    final isPrimaryPointer = event.buttons & kPrimaryMouseButton != 0;
    if (isPrimaryPointer &&
        (widget.controller.activeTool == CanvasTool.rectangle ||
            widget.controller.activeTool == CanvasTool.select)) {
      _drawingPointer = event.pointer;
      widget.controller.pointerDown(
        _toWorld(event.localPosition),
        hitTolerance: 8 / _transform.scale,
      );
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isPanning && _lastPointerPosition != null) {
      final delta = event.localPosition - _lastPointerPosition!;
      _lastPointerPosition = event.localPosition;
      _panBy(delta);
      return;
    }

    if (_drawingPointer == event.pointer) {
      widget.controller.pointerMove(_toWorld(event.localPosition));
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (_isPanning) {
      setState(() {
        _isPanning = false;
        _lastPointerPosition = null;
      });
    }

    if (_drawingPointer == event.pointer) {
      _drawingPointer = null;
      widget.controller.pointerUp(_toWorld(event.localPosition));
    }
  }

  void _handlePointerCancel(PointerEvent event) {
    if (_drawingPointer == event.pointer) {
      _drawingPointer = null;
      widget.controller.cancelGesture();
    }
    if (_isPanning) {
      setState(() {
        _isPanning = false;
        _lastPointerPosition = null;
      });
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = math.exp(-event.scrollDelta.dy * 0.0015);
    _zoomAt(event.localPosition, factor);
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _lastPanZoomOffset = Offset.zero;
    _lastPanZoomScale = 1;
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final previousOffset = _lastPanZoomOffset ?? Offset.zero;
    final panDelta = event.pan - previousOffset;
    final scaleFactor = event.scale / _lastPanZoomScale;

    _lastPanZoomOffset = event.pan;
    _lastPanZoomScale = event.scale;

    if (panDelta != Offset.zero) _panBy(panDelta);
    if (scaleFactor.isFinite && scaleFactor > 0 && scaleFactor != 1) {
      _zoomAt(event.localPosition, scaleFactor);
    }
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _lastPanZoomOffset = null;
    _lastPanZoomScale = 1;
  }

  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus) _spacePressed = false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _spacePressed = true;
      } else if (event is KeyUpEvent) {
        _spacePressed = false;
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace)) {
      widget.controller.deleteSelection();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.controller.cancelGesture();
      widget.controller.clearSelection();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF202124) : const Color(0xFFFCFCFD);
    final dotColor =
        isDark ? const Color(0xFF41434A) : const Color(0xFFD5D6DC);

    final cursor = _isPanning
        ? SystemMouseCursors.grabbing
        : widget.controller.activeTool == CanvasTool.rectangle
            ? SystemMouseCursors.precise
            : SystemMouseCursors.grab;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: cursor,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          onPointerSignal: _handlePointerSignal,
          onPointerPanZoomStart: _handlePanZoomStart,
          onPointerPanZoomUpdate: _handlePanZoomUpdate,
          onPointerPanZoomEnd: _handlePanZoomEnd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              return AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: _CanvasPainter(
                      transform: _transform,
                      backgroundColor: backgroundColor,
                      dotColor: dotColor,
                      rectangles: widget.controller.document.rectangles,
                      preview: widget.controller.rectanglePreview,
                      selected: widget.controller.selectedRectangle,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  const _CanvasPainter({
    required this.transform,
    required this.backgroundColor,
    required this.dotColor,
    required this.rectangles,
    required this.preview,
    required this.selected,
  });

  final ViewportTransform transform;
  final Color backgroundColor;
  final Color dotColor;
  final List<RectangleElement> rectangles;
  final RectangleElement? preview;
  final RectangleElement? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);
    if (size.isEmpty) return;

    _paintGrid(canvas, size);

    canvas.save();
    canvas.translate(transform.translation.x, transform.translation.y);
    canvas.scale(transform.scale);

    for (final rectangle in rectangles) {
      _paintRectangle(canvas, rectangle);
    }
    if (preview != null) {
      _paintRectangle(canvas, preview!, isPreview: true);
    }
    if (selected != null) {
      _paintSelection(canvas, selected!);
    }

    canvas.restore();
  }

  void _paintGrid(Canvas canvas, Size size) {
    final topLeft = transform.screenToWorld(const Point2(0, 0));
    final bottomRight =
        transform.screenToWorld(Point2(size.width, size.height));

    var gridStep = 24.0;
    while (gridStep * transform.scale < 14) {
      gridStep *= 2;
    }
    while (gridStep * transform.scale > 42) {
      gridStep /= 2;
    }

    final firstX = (topLeft.x / gridStep).floor() * gridStep;
    final firstY = (topLeft.y / gridStep).floor() * gridStep;
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (var worldX = firstX;
        worldX <= bottomRight.x + gridStep;
        worldX += gridStep) {
      for (var worldY = firstY;
          worldY <= bottomRight.y + gridStep;
          worldY += gridStep) {
        final point = transform.worldToScreen(Point2(worldX, worldY));
        canvas.drawCircle(Offset(point.x, point.y), 1.1, paint);
      }
    }
  }

  void _paintSelection(Canvas canvas, RectangleElement rectangle) {
    final rect = Rect.fromLTWH(
      rectangle.x,
      rectangle.y,
      rectangle.width,
      rectangle.height,
    );
    final outline = Paint()
      ..color = const Color(0xFF4C8DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, outline);

    final handlePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF3578E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final points = <Offset>[
      rect.topLeft,
      Offset(rect.center.dx, rect.top),
      rect.topRight,
      Offset(rect.right, rect.center.dy),
      rect.bottomRight,
      Offset(rect.center.dx, rect.bottom),
      rect.bottomLeft,
      Offset(rect.left, rect.center.dy),
    ];
    for (final point in points) {
      final handle = Rect.fromCenter(center: point, width: 7, height: 7);
      canvas.drawRect(handle, handlePaint);
      canvas.drawRect(handle, borderPaint);
    }
  }

  void _paintRectangle(
    Canvas canvas,
    RectangleElement rectangle, {
    bool isPreview = false,
  }) {
    if (rectangle.width <= 0 || rectangle.height <= 0) return;

    final random = math.Random(rectangle.seed);
    final path = Path();
    final corners = <Offset>[
      Offset(rectangle.x, rectangle.y),
      Offset(rectangle.x + rectangle.width, rectangle.y),
      Offset(rectangle.x + rectangle.width, rectangle.y + rectangle.height),
      Offset(rectangle.x, rectangle.y + rectangle.height),
    ];

    for (var side = 0; side < corners.length; side++) {
      final start = corners[side];
      final end = corners[(side + 1) % corners.length];
      final segments = 5;

      if (side == 0) path.moveTo(start.dx, start.dy);
      for (var segment = 1; segment <= segments; segment++) {
        final t = segment / segments;
        var x = start.dx + (end.dx - start.dx) * t;
        var y = start.dy + (end.dy - start.dy) * t;

        if (segment < segments && rectangle.roughness > 0) {
          final jitter = (random.nextDouble() * 2 - 1) *
              rectangle.roughness;
          final dx = end.dx - start.dx;
          final dy = end.dy - start.dy;
          final length = math.sqrt(dx * dx + dy * dy);
          if (length > 0) {
            x += -dy / length * jitter;
            y += dx / length * jitter;
          }
        }
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = Color(rectangle.strokeColor)
          .withOpacity(isPreview ? 0.72 : 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rectangle.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.translation != transform.translation ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.rectangles != rectangles ||
        oldDelegate.preview != preview ||
        oldDelegate.selected != selected;
  }
}
