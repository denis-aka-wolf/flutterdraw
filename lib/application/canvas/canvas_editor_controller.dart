import 'package:flutter/foundation.dart';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/elements/rectangle_element.dart';
import 'canvas_tool.dart';

enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  middleLeft,
}

class CanvasEditorController extends ChangeNotifier {
  DrawDocument _document = DrawDocument();
  CanvasTool _activeTool = CanvasTool.select;
  RectangleElement? _rectanglePreview;
  Point2? _rectangleStart;
  String? _draftId;
  int _draftSeed = 0;
  int _idCounter = 0;

  String? _selectedElementId;
  Point2? _gestureStart;
  RectangleElement? _gestureOriginal;
  ResizeHandle? _activeResizeHandle;
  bool _isMoving = false;

  DrawDocument get document => _document;
  CanvasTool get activeTool => _activeTool;
  RectangleElement? get rectanglePreview => _rectanglePreview;
  String? get selectedElementId => _selectedElementId;

  RectangleElement? get selectedRectangle {
    final id = _selectedElementId;
    if (id == null) return null;
    for (final rectangle in _document.rectangles) {
      if (rectangle.id == id) return rectangle;
    }
    return null;
  }

  void setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    _clearGesture();
    notifyListeners();
  }

  void pointerDown(Point2 worldPosition, {double hitTolerance = 8}) {
    if (_activeTool == CanvasTool.rectangle) {
      _idCounter++;
      _draftId = 'rectangle-$_idCounter';
      _draftSeed = Object.hash(_idCounter, worldPosition.x, worldPosition.y);
      _rectangleStart = worldPosition;
      _rectanglePreview = _makeRectangle(worldPosition, worldPosition);
      notifyListeners();
      return;
    }

    if (_activeTool != CanvasTool.select) return;

    final selected = selectedRectangle;
    if (selected != null) {
      final handle = _hitResizeHandle(selected, worldPosition, hitTolerance);
      if (handle != null) {
        _gestureStart = worldPosition;
        _gestureOriginal = selected;
        _activeResizeHandle = handle;
        _isMoving = false;
        notifyListeners();
        return;
      }
    }

    final hit = _hitTest(worldPosition, hitTolerance);
    _selectedElementId = hit?.id;
    _gestureStart = hit == null ? null : worldPosition;
    _gestureOriginal = hit;
    _activeResizeHandle = null;
    _isMoving = hit != null;
    notifyListeners();
  }

  void pointerMove(Point2 worldPosition) {
    if (_activeTool == CanvasTool.rectangle) {
      final start = _rectangleStart;
      if (start == null) return;
      _rectanglePreview = _makeRectangle(start, worldPosition);
      notifyListeners();
      return;
    }

    final start = _gestureStart;
    final original = _gestureOriginal;
    if (_activeTool != CanvasTool.select || start == null || original == null) {
      return;
    }

    final delta = worldPosition - start;
    final handle = _activeResizeHandle;
    if (handle != null) {
      _resizeRectangle(original, handle, worldPosition);
    } else if (_isMoving) {
      _document = _document.replaceRectangle(
        original.copyWith(x: original.x + delta.x, y: original.y + delta.y),
      );
    }
    notifyListeners();
  }

  void pointerUp(Point2 worldPosition) {
    if (_activeTool == CanvasTool.rectangle) {
      final start = _rectangleStart;
      if (start == null) return;
      final rectangle = _makeRectangle(start, worldPosition);
      _clearGesture();
      if (rectangle.isLargeEnough) {
        _document = _document.addRectangle(rectangle);
        _selectedElementId = rectangle.id;
      }
      notifyListeners();
      return;
    }

    if (_gestureStart != null) {
      final original = _gestureOriginal;
      final handle = _activeResizeHandle;
      if (original != null && _isMoving && handle == null) {
        final delta = worldPosition - _gestureStart!;
        _document = _document.replaceRectangle(
          original.copyWith(x: original.x + delta.x, y: original.y + delta.y),
        );
      } else if (original != null && handle != null) {
        _resizeRectangle(original, handle, worldPosition);
      }
      _clearSelectionGesture();
      notifyListeners();
    }
  }

  void deleteSelection() {
    final id = _selectedElementId;
    if (id == null) return;
    _document = _document.removeElement(id);
    _selectedElementId = null;
    _clearSelectionGesture();
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedElementId == null) return;
    _selectedElementId = null;
    _clearSelectionGesture();
    notifyListeners();
  }

  void deleteElement(String id) {
    final next = _document.removeElement(id);
    if (next.rectangles.length == _document.rectangles.length) return;
    _document = next;
    if (_selectedElementId == id) _selectedElementId = null;
    notifyListeners();
  }

  void cancelGesture() {
    if (_rectangleStart == null &&
        _rectanglePreview == null &&
        _gestureStart == null) {
      return;
    }

    final original = _gestureOriginal;
    if (original != null && (_isMoving || _activeResizeHandle != null)) {
      _document = _document.replaceRectangle(original);
    }
    _clearGesture();
    notifyListeners();
  }

  RectangleElement? _hitTest(Point2 point, double tolerance) {
    for (final rectangle in _document.rectangles.reversed) {
      final left = rectangle.x - tolerance;
      final top = rectangle.y - tolerance;
      final right = rectangle.x + rectangle.width + tolerance;
      final bottom = rectangle.y + rectangle.height + tolerance;
      if (point.x >= left &&
          point.x <= right &&
          point.y >= top &&
          point.y <= bottom) {
        return rectangle;
      }
    }
    return null;
  }

  ResizeHandle? _hitResizeHandle(
    RectangleElement rectangle,
    Point2 point,
    double tolerance,
  ) {
    final left = rectangle.x;
    final centerX = rectangle.x + rectangle.width / 2;
    final right = rectangle.x + rectangle.width;
    final top = rectangle.y;
    final centerY = rectangle.y + rectangle.height / 2;
    final bottom = rectangle.y + rectangle.height;

    final handles = <ResizeHandle, Point2>{
      ResizeHandle.topLeft: Point2(left, top),
      ResizeHandle.topCenter: Point2(centerX, top),
      ResizeHandle.topRight: Point2(right, top),
      ResizeHandle.middleRight: Point2(right, centerY),
      ResizeHandle.bottomRight: Point2(right, bottom),
      ResizeHandle.bottomCenter: Point2(centerX, bottom),
      ResizeHandle.bottomLeft: Point2(left, bottom),
      ResizeHandle.middleLeft: Point2(left, centerY),
    };

    for (final entry in handles.entries) {
      final dx = point.x - entry.value.x;
      final dy = point.y - entry.value.y;
      if (dx * dx + dy * dy <= tolerance * tolerance) return entry.key;
    }
    return null;
  }

  void _resizeRectangle(
    RectangleElement original,
    ResizeHandle handle,
    Point2 pointer,
  ) {
    var left = original.x;
    var top = original.y;
    var right = original.x + original.width;
    var bottom = original.y + original.height;

    switch (handle) {
      case ResizeHandle.topLeft:
        left = pointer.x;
        top = pointer.y;
      case ResizeHandle.topCenter:
        top = pointer.y;
      case ResizeHandle.topRight:
        right = pointer.x;
        top = pointer.y;
      case ResizeHandle.middleRight:
        right = pointer.x;
      case ResizeHandle.bottomRight:
        right = pointer.x;
        bottom = pointer.y;
      case ResizeHandle.bottomCenter:
        bottom = pointer.y;
      case ResizeHandle.bottomLeft:
        left = pointer.x;
        bottom = pointer.y;
      case ResizeHandle.middleLeft:
        left = pointer.x;
    }

    final resized = RectangleElement.fromPoints(
      id: original.id,
      start: Point2(left, top),
      end: Point2(right, bottom),
      seed: original.seed,
    ).copyWith(
      strokeColor: original.strokeColor,
      strokeWidth: original.strokeWidth,
      roughness: original.roughness,
    );
    _document = _document.replaceRectangle(resized);
  }

  RectangleElement _makeRectangle(Point2 start, Point2 end) {
    return RectangleElement.fromPoints(
      id: _draftId!,
      start: start,
      end: end,
      seed: _draftSeed,
    );
  }

  void _clearGesture() {
    _rectangleStart = null;
    _rectanglePreview = null;
    _draftId = null;
    _clearSelectionGesture();
  }

  void _clearSelectionGesture() {
    _gestureStart = null;
    _gestureOriginal = null;
    _activeResizeHandle = null;
    _isMoving = false;
  }
}
