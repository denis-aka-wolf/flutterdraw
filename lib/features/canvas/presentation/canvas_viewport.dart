import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../application/canvas/canvas_editor_controller.dart';
import '../../../application/canvas/canvas_tool.dart';
import '../../../core/geometry/viewport_transform.dart';
import '../../../domain/elements/drawing_element.dart';

class CanvasViewport extends StatefulWidget {
  const CanvasViewport({required this.controller, super.key});

  final CanvasEditorController controller;

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  ViewportTransform _transform = const ViewportTransform();
  final FocusNode _focusNode = FocusNode(debugLabel: 'FlutterDraw canvas');

  final Map<String, Uint8List> _imageBytesCache = {};

  bool _spacePressed = false;
  bool _shiftPressed = false;
  bool _isPanning = false;
  int? _drawingPointer;
  Offset? _lastPointerPosition;
  Offset? _lastPanZoomOffset;
  double _lastPanZoomScale = 1;
  String? _editingTextId;
  TextEditingController? _inlineTextController;
  FocusNode? _inlineTextFocus;

  @override
  void dispose() {
    _inlineTextController?.dispose();
    _inlineTextFocus?.dispose();
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

  Point2 _toWorld(Offset localPosition) => _transform.screenToWorld(
        Point2(localPosition.dx, localPosition.dy),
      );

  void _handlePointerDown(PointerDownEvent event) {
    if (_editingTextId != null) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons & kSecondaryMouseButton != 0) { _showContextMenu(event); return; }
    _focusNode.requestFocus();
    final isMouse = event.kind == PointerDeviceKind.mouse;
    final isMiddleMouse = isMouse && event.buttons & kMiddleMouseButton != 0;
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

    if (event.buttons & kPrimaryMouseButton == 0) return;
    if (widget.controller.activeTool == CanvasTool.text) {
      _showTextDialog(_toWorld(event.localPosition));
      return;
    }
    if (widget.controller.activeTool == CanvasTool.select ||
        widget.controller.activeTool == CanvasTool.rectangle ||
        widget.controller.activeTool == CanvasTool.ellipse ||
        widget.controller.activeTool == CanvasTool.diamond ||
        widget.controller.activeTool == CanvasTool.line ||
        widget.controller.activeTool == CanvasTool.arrow ||
        widget.controller.activeTool == CanvasTool.freehand) {
      _drawingPointer = event.pointer;
      widget.controller.pointerDown(
        _toWorld(event.localPosition),
        hitTolerance: 8 / _transform.scale,
        additiveSelection: _shiftPressed,
      );
    }
  }

  Future<void> _showContextMenu(PointerDownEvent event) async {
    final hit = widget.controller.selectElementAt(_toWorld(event.localPosition), tolerance: 8 / _transform.scale, preserveSelection: true);
    if (hit == null) widget.controller.clearSelection();
    final hasSelection = widget.controller.selectedElementIds.isNotEmpty;
    final multi = widget.controller.selectedElementIds.length > 1;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(event.position.dx, event.position.dy,
        MediaQuery.of(context).size.width - event.position.dx,
        MediaQuery.of(context).size.height - event.position.dy),
      items: [
        PopupMenuItem(value: 'copy', enabled: hasSelection, child: const Text('Копировать')),
        const PopupMenuItem(value: 'paste', child: Text('Вставить')),
        PopupMenuItem(value: 'duplicate', enabled: hasSelection, child: const Text('Дублировать')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'group', enabled: multi, child: const Text('Сгруппировать')),
        PopupMenuItem(value: 'ungroup', enabled: widget.controller.canUngroupSelection, child: const Text('Разгруппировать')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'align-left', enabled: multi, child: const Text('По левому краю')),
        PopupMenuItem(value: 'align-center-x', enabled: multi, child: const Text('По центру по горизонтали')),
        PopupMenuItem(value: 'align-right', enabled: multi, child: const Text('По правому краю')),
        PopupMenuItem(value: 'align-top', enabled: multi, child: const Text('По верхнему краю')),
        PopupMenuItem(value: 'align-center-y', enabled: multi, child: const Text('По центру по вертикали')),
        PopupMenuItem(value: 'align-bottom', enabled: multi, child: const Text('По нижнему краю')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'front', enabled: hasSelection, child: const Text('На передний план')),
        PopupMenuItem(value: 'back', enabled: hasSelection, child: const Text('На задний план')),
        PopupMenuItem(value: 'delete', enabled: hasSelection, child: const Text('Удалить')),
      ],
    );
    switch (action) {
      case 'copy': widget.controller.copySelection(); break;
      case 'paste': widget.controller.paste(); break;
      case 'duplicate': widget.controller.duplicateSelection(); break;
      case 'group': widget.controller.groupSelection(); break;
      case 'ungroup': widget.controller.ungroupSelection(); break;
      case 'align-left': widget.controller.alignSelection(ElementAlignment.left); break;
      case 'align-center-x': widget.controller.alignSelection(ElementAlignment.centerHorizontal); break;
      case 'align-right': widget.controller.alignSelection(ElementAlignment.right); break;
      case 'align-top': widget.controller.alignSelection(ElementAlignment.top); break;
      case 'align-center-y': widget.controller.alignSelection(ElementAlignment.centerVertical); break;
      case 'align-bottom': widget.controller.alignSelection(ElementAlignment.bottom); break;
      case 'front': widget.controller.bringSelectionToFront(); break;
      case 'back': widget.controller.sendSelectionToBack(); break;
      case 'delete': widget.controller.deleteSelection(); break;
    }
  }

  Future<void> _showTextDialog(Point2 position) async {
    final textController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый текст'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: textController,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Введите текст',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (!mounted || value == null || value.trim().isEmpty) return;
    widget.controller.addText(position, value);
  }

  void _beginInlineTextEdit(Point2 position) {
    if (_editingTextId != null) return;
    final element = widget.controller.selectElementAt(position, tolerance: 10 / _transform.scale);
    if (element == null || element.type != DrawingElementType.text) return;
    _inlineTextController?.dispose();
    _inlineTextFocus?.dispose();
    _inlineTextController = TextEditingController(text: element.text);
    _inlineTextFocus = FocusNode();
    setState(() => _editingTextId = element.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inlineTextFocus?.requestFocus();
    });
  }

  Widget _buildImageElement(DrawingElement element) {
    final asset = widget.controller.document.assets[element.assetId];
    if (asset == null) return const SizedBox.shrink();
    final topLeft = _transform.worldToScreen(Point2(element.x, element.y));
    final imageBytes = _imageBytesCache.putIfAbsent(
      element.assetId!,
      () => Uint8List.fromList(asset.bytes),
    );
    return Positioned(
      key: ValueKey('image-${element.id}'),
      left: topLeft.x,
      top: topLeft.y,
      width: element.width * _transform.scale,
      height: element.height * _transform.scale,
      child: IgnorePointer(
        child: Opacity(
          opacity: element.fillOpacity.clamp(0.0, 1.0).toDouble(),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Color(0x22FF0000),
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTextEditor() {
    DrawingElement? element;
    for (final item in widget.controller.document.elements) {
      if (item.id == _editingTextId) { element = item; break; }
    }
    if (element == null) return const SizedBox.shrink();
    final screen = _transform.worldToScreen(Point2(element.x, element.y));
    return Positioned(
      left: screen.x, top: screen.y,
      width: math.max(120.0, element.width * _transform.scale),
      height: math.max(48.0, element.height * _transform.scale),
      child: Material(color: Colors.transparent, child: TextField(
        controller: _inlineTextController, focusNode: _inlineTextFocus,
        maxLines: null, expands: true,
        textInputAction: TextInputAction.done,
        onTapOutside: (_) => _finishInlineTextEdit(),
        textAlign: _textAlignFor(element.textAlign),
        style: TextStyle(fontFamily: element.fontFamily,
          fontSize: element.fontSize * _transform.scale,
          color: Color(element.strokeColor).withValues(alpha: element.opacity)),
        decoration: const InputDecoration(contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(), filled: true, fillColor: Color(0x22FFFFFF)),
        onSubmitted: (_) => _finishInlineTextEdit(),
      )),
    );
  }

  void _finishInlineTextEdit() {
    final id = _editingTextId;
    final value = _inlineTextController?.text ?? '';
    if (id != null && widget.controller.selectedElements.any((e) => e.id == id)) {
      widget.controller.updateSelectedText(value);
    }
    setState(() => _editingTextId = null);
    _inlineTextController?.dispose(); _inlineTextController = null;
    _inlineTextFocus?.dispose(); _inlineTextFocus = null;
    _focusNode.requestFocus();
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
    if (event is PointerScrollEvent) {
      _zoomAt(event.localPosition, math.exp(-event.scrollDelta.dy * 0.0015));
    }
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _lastPanZoomOffset = Offset.zero;
    _lastPanZoomScale = 1;
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final panDelta = event.pan - (_lastPanZoomOffset ?? Offset.zero);
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _spacePressed = event is! KeyUpEvent;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _shiftPressed = event is! KeyUpEvent;
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCommand = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (_editingTextId != null &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            (isCommand && event.logicalKey == LogicalKeyboardKey.enter))) {
      _finishInlineTextEdit();
      return KeyEventResult.handled;
    }

    if (isCommand && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.controller.redo();
      } else {
        widget.controller.undo();
      }
      return KeyEventResult.handled;
    }
    if (isCommand && event.logicalKey == LogicalKeyboardKey.keyY) {
      widget.controller.redo();
      return KeyEventResult.handled;
    }

    if (isCommand && event.logicalKey == LogicalKeyboardKey.keyG) {
      if (HardwareKeyboard.instance.isShiftPressed) { widget.controller.ungroupSelection(); } else { widget.controller.groupSelection(); }
      return KeyEventResult.handled;
    }
    if (isCommand) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          widget.controller.copySelection();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyV:
          widget.controller.paste();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyD:
          widget.controller.duplicateSelection();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.bracketRight:
          widget.controller.bringSelectionToFront();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.bracketLeft:
          widget.controller.sendSelectionToBack();
          return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      widget.controller.deleteSelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
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

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _spacePressed = false;
          _shiftPressed = false;
        }
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final cursor = _isPanning
              ? SystemMouseCursors.grabbing
              : widget.controller.activeTool == CanvasTool.hand
                  ? SystemMouseCursors.grab
                  : widget.controller.activeTool == CanvasTool.select
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.precise;
          return MouseRegion(
            cursor: cursor,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: (details) => _beginInlineTextEdit(_toWorld(details.localPosition)),
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
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(child: CustomPaint(
                        painter: _CanvasPainter(
                          transform: _transform, backgroundColor: backgroundColor,
                          dotColor: dotColor, elements: widget.controller.document.elements,
                          preview: widget.controller.drawingPreview,
                          selection: widget.controller.selectionBounds,
                          showResizeHandles: widget.controller.canResizeSelection,
                          marquee: widget.controller.marqueeBounds,
                          editingTextId: _editingTextId,
                          alignmentGuidesX: widget.controller.alignmentGuidesX,
                          alignmentGuidesY: widget.controller.alignmentGuidesY,
                        ),
                      )),
                      for (final element in widget.controller.document.elements)
                        if (element.type == DrawingElementType.image &&
                            element.assetId != null &&
                            widget.controller.document.assets[element.assetId] != null)
                          _buildImageElement(element),
                      if (_editingTextId != null) _buildInlineTextEditor(),
                    ],
                  );
                },
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

TextAlign _textAlignFor(String value) => switch (value) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

class _CanvasPainter extends CustomPainter {
  const _CanvasPainter({
    required this.transform,
    required this.backgroundColor,
    required this.dotColor,
    required this.elements,
    required this.preview,
    required this.selection,
    required this.showResizeHandles,
    required this.marquee,
    required this.editingTextId,
    required this.alignmentGuidesX,
    required this.alignmentGuidesY,
  });

  final ViewportTransform transform;
  final Color backgroundColor;
  final Color dotColor;
  final List<DrawingElement> elements;
  final DrawingElement? preview;
  final SelectionBounds? selection;
  final bool showResizeHandles;
  final SelectionBounds? marquee;
  final String? editingTextId;
  final List<double> alignmentGuidesX;
  final List<double> alignmentGuidesY;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);
    if (size.isEmpty) return;
    _paintGrid(canvas, size);

    canvas.save();
    canvas.translate(transform.translation.x, transform.translation.y);
    canvas.scale(transform.scale);
    for (final element in elements) {
      _paintElement(canvas, element);
    }
    if (preview != null) _paintElement(canvas, preview!, opacity: 0.65);
    if (selection != null) _paintSelection(canvas, selection!);
    if (marquee != null) _paintMarquee(canvas, marquee!);
    canvas.restore();
    final guidePaint = Paint()..color = const Color(0xFF12A6A0).withValues(alpha: 0.9)..strokeWidth = 1;
    for (final x in alignmentGuidesX) {
      final sx = transform.worldToScreen(Point2(x, 0)).x;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), guidePaint);
    }
    for (final y in alignmentGuidesY) {
      final sy = transform.worldToScreen(Point2(0, y)).y;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), guidePaint);
    }
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
    for (var x = firstX; x <= bottomRight.x + gridStep; x += gridStep) {
      for (var y = firstY; y <= bottomRight.y + gridStep; y += gridStep) {
        final point = transform.worldToScreen(Point2(x, y));
        canvas.drawCircle(Offset(point.x, point.y), 1.1, paint);
      }
    }
  }

  void _paintElement(
    Canvas canvas,
    DrawingElement element, {
    double opacity = 1,
  }) {
    if (element.type == DrawingElementType.image) return;
    if (element.type == DrawingElementType.text) {
      if (element.id == editingTextId) return;
      final painter = TextPainter(
        text: TextSpan(
          text: element.text,
          style: TextStyle(
            color: Color(element.strokeColor).withValues(alpha: element.strokeOpacity * opacity),
            fontSize: element.fontSize,
            fontFamily: element.fontFamily,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: _textAlignFor(element.textAlign),
      )..layout(maxWidth: math.max(40.0, element.width));
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(element.x, element.y, element.width, element.height));
      painter.paint(canvas, Offset(element.x, element.y));
      canvas.restore();
      return;
    }
    if (element.type == DrawingElementType.line ||
        element.type == DrawingElementType.arrow ||
        element.type == DrawingElementType.freehand) {
      _paintStroke(canvas, element, opacity);
      return;
    }

    final rect = Rect.fromLTRB(
      element.left,
      element.top,
      element.right,
      element.bottom,
    );
    final path = Path();
    switch (element.type) {
      case DrawingElementType.rectangle:
        _roughPolygon(path, [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ], element);
        break;
      case DrawingElementType.ellipse:
        _roughEllipse(path, rect, element);
        break;
      case DrawingElementType.diamond:
        _roughPolygon(path, [
          Offset(rect.center.dx, rect.top),
          Offset(rect.right, rect.center.dy),
          Offset(rect.center.dx, rect.bottom),
          Offset(rect.left, rect.center.dy),
        ], element);
        break;
      case DrawingElementType.line:
      case DrawingElementType.arrow:
      case DrawingElementType.freehand:
      case DrawingElementType.text:
      case DrawingElementType.image:
        break;
    }
    path.close();
    if (element.fillColor != 0x00000000) {
      canvas.drawPath(path, Paint()..color = Color(element.fillColor).withValues(alpha: element.fillOpacity * opacity)..style = PaintingStyle.fill);
    }
    if (element.strokeAlignment == StrokeAlignment.center) {
      canvas.drawPath(path, _strokePaint(element, opacity));
    } else if (element.strokeAlignment == StrokeAlignment.inside) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        _strokePaint(element, opacity)..strokeWidth = element.strokeWidth * 2,
      );
      canvas.restore();
    } else {
      final layerBounds = path.getBounds().inflate(element.strokeWidth * 2);
      canvas.saveLayer(layerBounds, Paint());
      canvas.drawPath(
        path,
        _strokePaint(element, opacity)..strokeWidth = element.strokeWidth * 2,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.dstOut,
      );
      canvas.restore();
    }
  }

  void _roughPolygon(Path path, List<Offset> corners, DrawingElement element) {
    final random = math.Random(element.seed);
    for (var side = 0; side < corners.length; side++) {
      final start = corners[side];
      final end = corners[(side + 1) % corners.length];
      if (side == 0) path.moveTo(start.dx, start.dy);
      const segments = 6;
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        var x = start.dx + (end.dx - start.dx) * t;
        var y = start.dy + (end.dy - start.dy) * t;
        if (i < segments && element.roughness > 0) {
          final jitter = (random.nextDouble() * 2 - 1) * element.roughness;
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
  }

  void _roughEllipse(Path path, Rect rect, DrawingElement element) {
    final random = math.Random(element.seed);
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const count = 48;
    for (var i = 0; i <= count; i++) {
      final angle = math.pi * 2 * i / count;
      final jitter = (random.nextDouble() * 2 - 1) * element.roughness;
      final x = center.dx + (rx + jitter) * math.cos(angle);
      final y = center.dy + (ry + jitter) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
  }

  void _paintStroke(Canvas canvas, DrawingElement element, double opacity) {
    if (element.points.isEmpty) return;
    final path = Path();
    if ((element.type == DrawingElementType.line ||
            element.type == DrawingElementType.arrow) &&
        element.points.length == 2) {
      final start = element.points.first;
      final end = element.points.last;
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final length = math.sqrt(dx * dx + dy * dy);
      final random = math.Random(element.seed);
      const segments = 10;
      path.moveTo(start.x, start.y);
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        var x = start.x + dx * t;
        var y = start.y + dy * t;
        if (i < segments && length > 0 && element.roughness > 0) {
          final jitter = (random.nextDouble() * 2 - 1) * element.roughness;
          x += -dy / length * jitter;
          y += dx / length * jitter;
        }
        path.lineTo(x, y);
      }
    } else {
      path.moveTo(element.points.first.x, element.points.first.y);
      for (var i = 1; i < element.points.length; i++) {
        path.lineTo(element.points[i].x, element.points[i].y);
      }
    }
    final paint = _strokePaint(element, opacity);
    canvas.drawPath(path, paint);

    if (element.type == DrawingElementType.arrow && element.points.length >= 2) {
      final start = element.points[element.points.length - 2];
      final end = element.points.last;
      final angle = math.atan2(end.y - start.y, end.x - start.x);
      final headLength = math.max(10.0, element.strokeWidth * 4).toDouble();
      final wingA = Offset(
        end.x - headLength * math.cos(angle - math.pi / 6),
        end.y - headLength * math.sin(angle - math.pi / 6),
      );
      final wingB = Offset(
        end.x - headLength * math.cos(angle + math.pi / 6),
        end.y - headLength * math.sin(angle + math.pi / 6),
      );
      final arrowHead = Path()
        ..moveTo(wingA.dx, wingA.dy)
        ..lineTo(end.x, end.y)
        ..lineTo(wingB.dx, wingB.dy);
      canvas.drawPath(arrowHead, paint);
    }
  }

  Paint _strokePaint(DrawingElement element, double opacity) => Paint()
    ..color = Color(element.strokeColor).withValues(alpha: element.strokeOpacity * opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = element.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintSelection(Canvas canvas, SelectionBounds bounds) {
    final scale = transform.scale;
    final rect = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
    final outline = Paint()
      ..color = const Color(0xFF4C8DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;
    canvas.drawRect(rect, outline);

    if (!showResizeHandles) return;
    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = const Color(0xFF3578E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / scale;
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
      final handle = Rect.fromCenter(
        center: point,
        width: 7 / scale,
        height: 7 / scale,
      );
      canvas.drawRect(handle, fill);
      canvas.drawRect(handle, border);
    }
  }

  void _paintMarquee(Canvas canvas, SelectionBounds bounds) {
    final paint = Paint()
      ..color = const Color(0xFF4C8DFF)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF4C8DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / transform.scale;
    final rect = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
    canvas.drawRect(rect, paint..color = paint.color.withValues(alpha: 0.10));
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) =>
      oldDelegate.transform.scale != transform.scale ||
      oldDelegate.transform.translation != transform.translation ||
      oldDelegate.editingTextId != editingTextId ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.elements != elements ||
      oldDelegate.preview != preview ||
      oldDelegate.selection != selection ||
      oldDelegate.showResizeHandles != showResizeHandles ||
      oldDelegate.marquee != marquee ||
      oldDelegate.alignmentGuidesX != alignmentGuidesX ||
      oldDelegate.alignmentGuidesY != alignmentGuidesY;
}
