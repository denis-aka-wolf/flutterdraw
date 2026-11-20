import 'package:flutter/foundation.dart';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/elements/rectangle_element.dart';
import 'canvas_tool.dart';

/// Coordinates document edits and the transient preview of the active tool.
class CanvasEditorController extends ChangeNotifier {
  DrawDocument _document = DrawDocument();
  CanvasTool _activeTool = CanvasTool.select;
  RectangleElement? _rectanglePreview;
  Point2? _rectangleStart;
  String? _draftId;
  int _draftSeed = 0;
  int _idCounter = 0;

  DrawDocument get document => _document;
  CanvasTool get activeTool => _activeTool;
  RectangleElement? get rectanglePreview => _rectanglePreview;

  void setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    _clearGesture();
    notifyListeners();
  }

  void pointerDown(Point2 worldPosition) {
    if (_activeTool != CanvasTool.rectangle) return;

    _idCounter++;
    _draftId = 'rectangle-$_idCounter';
    _draftSeed = Object.hash(
      _idCounter,
      worldPosition.x,
      worldPosition.y,
    );
    _rectangleStart = worldPosition;
    _rectanglePreview = _makeRectangle(worldPosition, worldPosition);
    notifyListeners();
  }

  void pointerMove(Point2 worldPosition) {
    final start = _rectangleStart;
    if (start == null || _activeTool != CanvasTool.rectangle) return;

    _rectanglePreview = _makeRectangle(start, worldPosition);
    notifyListeners();
  }

  void pointerUp(Point2 worldPosition) {
    final start = _rectangleStart;
    if (start == null || _activeTool != CanvasTool.rectangle) return;

    final rectangle = _makeRectangle(start, worldPosition);
    _clearGesture();

    if (rectangle.isLargeEnough) {
      _document = _document.addRectangle(rectangle);
    }
    notifyListeners();
  }

  void cancelGesture() {
    if (_rectangleStart == null && _rectanglePreview == null) return;
    _clearGesture();
    notifyListeners();
  }

  void deleteElement(String id) {
    final next = _document.removeElement(id);
    if (next.rectangles.length == _document.rectangles.length) return;
    _document = next;
    notifyListeners();
  }

  void _clearGesture() {
    _rectangleStart = null;
    _rectanglePreview = null;
    _draftId = null;
  }

  RectangleElement _makeRectangle(Point2 start, Point2 end) {
    return RectangleElement.fromPoints(
      id: _draftId!,
      start: start,
      end: end,
      seed: _draftSeed,
    );
  }
}
