import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/geometry/viewport_transform.dart';

class CanvasViewport extends StatefulWidget {
  const CanvasViewport({super.key});

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  ViewportTransform _transform = const ViewportTransform(
    translation: Point2(0, 0),
  );

  final FocusNode _focusNode = FocusNode(debugLabel: 'FlutterDraw canvas');

  bool _spacePressed = false;
  bool _isPanning = false;
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

  void _handlePointerDown(PointerDownEvent event) {
    final isMiddleMouse = event.kind == PointerDeviceKind.mouse &&
        event.buttons & kMiddleMouseButton != 0;
    final isSpaceDrag = event.kind == PointerDeviceKind.mouse &&
        _spacePressed &&
        event.buttons & kPrimaryMouseButton != 0;

    if (isMiddleMouse || isSpaceDrag) {
      _focusNode.requestFocus();
      setState(() {
        _isPanning = true;
        _lastPointerPosition = event.localPosition;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isPanning || _lastPointerPosition == null) return;

    final delta = event.localPosition - _lastPointerPosition!;
    _lastPointerPosition = event.localPosition;
    _panBy(delta);
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_isPanning) return;

    setState(() {
      _isPanning = false;
      _lastPointerPosition = null;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    // A conventional mouse wheel zooms around the cursor.
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

    if (panDelta != Offset.zero) {
      _panBy(panDelta);
    }
    if (scaleFactor.isFinite && scaleFactor > 0 && scaleFactor != 1) {
      _zoomAt(event.localPosition, scaleFactor);
    }
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _lastPanZoomOffset = null;
    _lastPanZoomScale = 1;
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

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF202124) : const Color(0xFFFCFCFD);
    final dotColor =
        isDark ? const Color(0xFF41434A) : const Color(0xFFD5D6DC);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: _isPanning ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerUp,
          onPointerSignal: _handlePointerSignal,
          onPointerPanZoomStart: _handlePanZoomStart,
          onPointerPanZoomUpdate: _handlePanZoomUpdate,
          onPointerPanZoomEnd: _handlePanZoomEnd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return CustomPaint(
                size: size,
                painter: _CanvasGridPainter(
                  transform: _transform,
                  backgroundColor: backgroundColor,
                  dotColor: dotColor,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  const _CanvasGridPainter({
    required this.transform,
    required this.backgroundColor,
    required this.dotColor,
  });

  final ViewportTransform transform;
  final Color backgroundColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);

    if (size.isEmpty) return;

    final topLeft = transform.screenToWorld(const Point2(0, 0));
    final bottomRight = transform.screenToWorld(
      Point2(size.width, size.height),
    );

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
        final screenPoint =
            transform.worldToScreen(Point2(worldX, worldY));
        canvas.drawCircle(
          Offset(screenPoint.x, screenPoint.y),
          1.1,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) {
    return oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.translation != transform.translation ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dotColor != dotColor;
  }
}
