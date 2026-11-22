import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/document/document_asset.dart';
import '../../domain/elements/drawing_element.dart';
import 'canvas_tool.dart';

enum ElementAlignment {
  left,
  centerHorizontal,
  right,
  top,
  centerVertical,
  bottom
}

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

class SelectionBounds {
  const SelectionBounds(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}

class CanvasEditorController extends ChangeNotifier {
  DrawDocument _document = DrawDocument();
  final List<DrawDocument> _history = [DrawDocument()];
  int _historyIndex = 0;
  String? _lastHistoryMergeKey;
  DrawDocument? _gestureDocumentBefore;
  CanvasTool _activeTool = CanvasTool.select;
  DrawingElement? _drawingPreview;
  Point2? _drawingStart;
  String? _draftId;
  int _draftSeed = 0;
  int _idCounter = 0;

  final Set<String> _selectedIds = {};
  final List<DrawingElement> _clipboard = [];
  Point2? _gestureStart;
  Point2? _marqueeEnd;
  List<DrawingElement> _gestureOriginals = [];
  ResizeHandle? _activeResizeHandle;
  bool _isMoving = false;
  int _groupCounter = 0;
  bool _snapToGrid = true;
  bool _snapToGuides = true;
  List<double> _alignmentGuidesX = const [];
  List<double> _alignmentGuidesY = const [];

  DrawDocument get document => _document;
  bool get canUndo => _historyIndex > 0;
  bool get snapToGrid => _snapToGrid;
  bool get snapToGuides => _snapToGuides;
  List<double> get alignmentGuidesX => List.unmodifiable(_alignmentGuidesX);
  List<double> get alignmentGuidesY => List.unmodifiable(_alignmentGuidesY);
  bool get canGroupSelection => _selectedIds.length >= 2;
  bool get canUngroupSelection =>
      selectedElements.any((e) => e.extraData['flutterdrawGroupId'] is String);
  bool get canRedo => _historyIndex < _history.length - 1;
  CanvasTool get activeTool => _activeTool;
  DrawingElement? get drawingPreview => _drawingPreview;
  Set<String> get selectedElementIds => Set.unmodifiable(_selectedIds);
  bool get isMarqueeSelecting =>
      _gestureStart != null &&
      _marqueeEnd != null &&
      !_isMoving &&
      _activeResizeHandle == null &&
      _gestureOriginals.isEmpty;

  List<DrawingElement> get selectedElements => _document.elements
      .where((element) => _selectedIds.contains(element.id))
      .toList(growable: false);

  bool get canResizeSelection {
    final selected = selectedElements;
    if (selected.length != 1) return false;
    final type = selected.single.type;
    return type != DrawingElementType.line &&
        type != DrawingElementType.arrow &&
        type != DrawingElementType.freehand;
  }

  SelectionBounds? get selectionBounds {
    final selected = selectedElements;
    if (selected.isEmpty) return null;
    return SelectionBounds(
      selected.map((e) => e.left).reduce((a, b) => a < b ? a : b),
      selected.map((e) => e.top).reduce((a, b) => a < b ? a : b),
      selected.map((e) => e.right).reduce((a, b) => a > b ? a : b),
      selected.map((e) => e.bottom).reduce((a, b) => a > b ? a : b),
    );
  }

  SelectionBounds? get marqueeBounds {
    final start = _gestureStart;
    final end = _marqueeEnd;
    if (start == null || end == null || !isMarqueeSelecting) return null;
    return SelectionBounds(
      start.x < end.x ? start.x : end.x,
      start.y < end.y ? start.y : end.y,
      start.x > end.x ? start.x : end.x,
      start.y > end.y ? start.y : end.y,
    );
  }

  void loadDocument(DrawDocument document) {
    _document = document;
    _history
      ..clear()
      ..add(document);
    _historyIndex = 0;
    _lastHistoryMergeKey = null;
    _selectedIds.clear();
    _clipboard.clear();
    _idCounter = 0;
    _groupCounter = 0;
    for (final element in document.elements) {
      final idMatch = RegExp(r'^element-([0-9]+)').firstMatch(element.id);
      final idNumber = int.tryParse(idMatch?.group(1) ?? '');
      if (idNumber != null && idNumber > _idCounter) _idCounter = idNumber;
      final groupId = element.extraData['flutterdrawGroupId'];
      if (groupId is String) {
        final groupMatch = RegExp(r'^group-([0-9]+)$').firstMatch(groupId);
        final groupNumber = int.tryParse(groupMatch?.group(1) ?? '');
        if (groupNumber != null && groupNumber > _groupCounter)
          _groupCounter = groupNumber;
      }
    }
    _activeTool = CanvasTool.select;
    _clearGesture();
    notifyListeners();
  }

  void newDocument() => loadDocument(DrawDocument());

  void addText(Point2 position, String value, {double fontSize = 24}) {
    final before = _document;
    final content = value.trim();
    if (content.isEmpty) return;
    _idCounter++;
    final width =
        math.max(160.0, math.min(520.0, content.length * fontSize * 0.62));
    final lines = content.split('\n').length;
    final height = math.max(fontSize * 1.5, lines * fontSize * 1.45);
    final element = DrawingElement(
      id: 'element-$_idCounter',
      type: DrawingElementType.text,
      x: position.x,
      y: position.y,
      width: width,
      height: height,
      seed: _idCounter,
      text: content,
      fontSize: fontSize,
      strokeColor: 0xFF252525,
      roughness: 0,
    );
    _document = _document.addElement(element);
    _selectedIds
      ..clear()
      ..add(element.id);
    _recordHistory(before);
    notifyListeners();
  }

  void addImage(DocumentAsset asset, Point2 position,
      {double width = 320, double height = 240}) {
    final before = _document;
    _idCounter++;
    final element = DrawingElement(
      id: 'element-$_idCounter',
      type: DrawingElementType.image,
      x: position.x,
      y: position.y,
      width: width,
      height: height,
      seed: _idCounter,
      assetId: asset.id,
      roughness: 0,
      strokeOpacity: 1,
      fillOpacity: 1,
    );
    _document = _document.addAsset(asset).addElement(element);
    _selectedIds
      ..clear()
      ..add(element.id);
    _recordHistory(before);
    notifyListeners();
  }

  void updateSelectedText(String value) {
    final selected = selectedElements;
    if (selected.length != 1 || selected.single.type != DrawingElementType.text)
      return;
    final before = _document;
    final original = selected.single;
    final content = value;
    final height = math.max(original.fontSize * 1.5,
        content.split('\n').length * original.fontSize * 1.45);
    _document = _document.replaceElement(original.copyWith(
      text: content,
      height: height,
    ));
    _recordHistory(before, mergeKey: 'text-content');
    notifyListeners();
  }

  void updateSelectedProperties(
      {int? strokeColor,
      int? fillColor,
      double? strokeWidth,
      StrokeAlignment? strokeAlignment,
      double? opacity,
      double? strokeOpacity,
      double? fillOpacity,
      String? fontFamily,
      String? textAlign}) {
    final selected = selectedElements;
    if (selected.isEmpty) return;
    final before = _document;
    for (final element in selected) {
      _document = _document.replaceElement(element.copyWith(
        strokeColor: strokeColor,
        fillColor: fillColor,
        strokeWidth: strokeWidth,
        strokeAlignment: strokeAlignment,
        opacity: opacity,
        strokeOpacity: strokeOpacity,
        fillOpacity: fillOpacity,
        fontFamily: fontFamily,
        textAlign: textAlign,
      ));
    }
    final propertyKey = [
      if (strokeColor != null) 'strokeColor',
      if (fillColor != null) 'fillColor',
      if (strokeWidth != null) 'strokeWidth',
      if (strokeAlignment != null) 'strokeAlignment',
      if (opacity != null) 'opacity',
      if (strokeOpacity != null) 'strokeOpacity',
      if (fillOpacity != null) 'fillOpacity',
      if (fontFamily != null) 'fontFamily',
      if (textAlign != null) 'textAlign',
    ].join(',');
    final selectedKey = _selectedIds.toList()..sort();
    _recordHistory(before,
        mergeKey: 'element-properties:$propertyKey:$selectedKey');
    notifyListeners();
  }

  bool _lockImageAspectRatio = true;

  bool get lockImageAspectRatio => _lockImageAspectRatio;

  void setImageAspectRatioLocked(bool value) {
    if (_lockImageAspectRatio == value) return;
    _lockImageAspectRatio = value;
    notifyListeners();
  }

  void setSelectedImageSize({double? width, double? height}) {
    final selected = selectedElements;
    if (selected.length != 1 ||
        selected.single.type != DrawingElementType.image) return;
    final before = _document;
    final element = selected.single;
    final originalWidth = element.width.abs().clamp(0.001, double.infinity);
    final originalHeight = element.height.abs().clamp(0.001, double.infinity);
    final ratio = originalWidth / originalHeight;
    var nextWidth = width ?? element.width;
    var nextHeight = height ?? element.height;
    if (_lockImageAspectRatio) {
      if (width != null) {
        nextHeight = nextWidth / ratio;
      } else if (height != null) {
        nextWidth = nextHeight * ratio;
      }
    }
    nextWidth = nextWidth.clamp(1.0, 10000.0).toDouble();
    nextHeight = nextHeight.clamp(1.0, 10000.0).toDouble();
    _document = _document.replaceElement(element.copyWith(
      width: nextWidth,
      height: nextHeight,
    ));
    _recordHistory(before, mergeKey: 'image-size');
    notifyListeners();
  }

  void setSelectedTextBlockSize({double? width, double? height}) {
    final selected = selectedElements;
    if (selected.length != 1 || selected.single.type != DrawingElementType.text)
      return;
    final before = _document;
    final element = selected.single;
    _document = _document.replaceElement(element.copyWith(
      width:
          width == null ? element.width : width.clamp(40.0, 2000.0).toDouble(),
      height: height == null
          ? element.height
          : height.clamp(24.0, 2000.0).toDouble(),
    ));
    _recordHistory(before, mergeKey: 'text-block-size');
    notifyListeners();
  }

  DrawingElement? selectElementAt(Point2 point,
      {double tolerance = 8, bool preserveSelection = false}) {
    final hit = _hitTest(point, tolerance);
    if (hit == null) return null;
    if (preserveSelection && _selectedIds.contains(hit.id)) return hit;
    final groupId = hit.extraData['flutterdrawGroupId'];
    final ids = groupId is String
        ? _document.elements
            .where((e) => e.extraData['flutterdrawGroupId'] == groupId)
            .map((e) => e.id)
        : [hit.id];
    _selectedIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
    return hit;
  }

  void setSelectedTextFontSize(double value) {
    final selected = selectedElements;
    if (selected.length != 1 || selected.single.type != DrawingElementType.text)
      return;
    final before = _document;
    final original = selected.single;
    final fontSize = value.clamp(10.0, 96.0).toDouble();
    _document = _document.replaceElement(original.copyWith(
      fontSize: fontSize,
      height: math.max(
          fontSize * 1.5, original.text.split('\n').length * fontSize * 1.45),
    ));
    _recordHistory(before, mergeKey: 'text-font-size');
    notifyListeners();
  }

  void setActiveTool(CanvasTool tool) {
    if (_activeTool == tool) return;
    _rollbackSelectionGesture();
    _activeTool = tool;
    _clearGesture();
    notifyListeners();
  }

  void pointerDown(
    Point2 worldPosition, {
    double hitTolerance = 8,
    bool additiveSelection = false,
  }) {
    final drawingType = _drawingTypeForTool(_activeTool);
    if (drawingType != null) {
      _gestureDocumentBefore = _document;
      _idCounter++;
      _draftId = 'element-$_idCounter';
      _draftSeed = Object.hash(_idCounter, worldPosition.x, worldPosition.y);
      _drawingStart = worldPosition;
      _drawingPreview = DrawingElement(
        id: _draftId!,
        type: drawingType,
        x: worldPosition.x,
        y: worldPosition.y,
        width: 0,
        height: 0,
        seed: _draftSeed,
        points: drawingType == DrawingElementType.freehand
            ? [worldPosition]
            : const [],
      );
      notifyListeners();
      return;
    }

    if (_activeTool != CanvasTool.select) return;
    _gestureDocumentBefore = _document;

    final selectedBounds = selectionBounds;
    if (canResizeSelection && selectedBounds != null) {
      final selected = selectedElements.single;
      final handle =
          _hitResizeHandle(selectedBounds, worldPosition, hitTolerance);
      if (handle != null) {
        _gestureStart = worldPosition;
        _gestureOriginals = [selected];
        _activeResizeHandle = handle;
        _isMoving = false;
        notifyListeners();
        return;
      }
    }

    final hit = _hitTest(worldPosition, hitTolerance);
    if (hit != null) {
      final groupId = hit.extraData['flutterdrawGroupId'];
      final hitIds = groupId is String
          ? _document.elements
              .where((e) => e.extraData['flutterdrawGroupId'] == groupId)
              .map((e) => e.id)
              .toSet()
          : {hit.id};
      if (!additiveSelection && !_selectedIds.contains(hit.id)) {
        _selectedIds
          ..clear()
          ..addAll(hitIds);
      } else if (additiveSelection) {
        if (hitIds.every(_selectedIds.contains)) {
          _selectedIds.removeAll(hitIds);
        } else {
          _selectedIds.addAll(hitIds);
        }
      }
      if (_selectedIds.contains(hit.id)) {
        _gestureStart = worldPosition;
        _gestureOriginals = selectedElements;
        _isMoving = true;
      }
    } else {
      if (!additiveSelection) _selectedIds.clear();
      _gestureStart = worldPosition;
      _marqueeEnd = worldPosition;
      _gestureOriginals = [];
      _isMoving = false;
    }
    notifyListeners();
  }

  void pointerMove(Point2 worldPosition) {
    if (_drawingStart != null) {
      final preview = _drawingPreview;
      if (preview == null) return;
      if (preview.type == DrawingElementType.freehand) {
        _drawingPreview = preview.appendPoint(worldPosition);
      } else {
        _drawingPreview = _makeDraggedElement(
          preview.type,
          _drawingStart!,
          worldPosition,
        );
      }
      notifyListeners();
      return;
    }

    final start = _gestureStart;
    if (start == null) return;

    if (isMarqueeSelecting) {
      _marqueeEnd = worldPosition;
      notifyListeners();
      return;
    }

    final handle = _activeResizeHandle;
    if (handle != null && _gestureOriginals.length == 1) {
      _resizeElement(_gestureOriginals.single, handle, worldPosition);
      notifyListeners();
      return;
    }

    if (_isMoving && _gestureOriginals.isNotEmpty) {
      final delta = _snappedMoveDelta(
          worldPosition.x - start.x, worldPosition.y - start.y);
      for (final original in _gestureOriginals) {
        _document =
            _document.replaceElement(original.translated(delta.x, delta.y));
      }
      notifyListeners();
    }
  }

  void pointerUp(Point2 worldPosition) {
    if (_drawingStart != null) {
      final before = _gestureDocumentBefore;
      final preview = _drawingPreview;
      if (preview == null) return;
      DrawingElement completed;
      if (preview.type == DrawingElementType.freehand) {
        completed = preview.appendPoint(worldPosition);
      } else {
        completed = _makeDraggedElement(
          preview.type,
          _drawingStart!,
          worldPosition,
        );
      }
      _clearGesture();
      if (completed.isLargeEnough) {
        _document = _document.addElement(completed);
        _selectedIds
          ..clear()
          ..add(completed.id);
        if (before != null) _recordHistory(before);
      }
      notifyListeners();
      return;
    }

    if (isMarqueeSelecting) {
      _marqueeEnd = worldPosition;
      final bounds = marqueeBounds;
      if (bounds != null) {
        final matches = _document.elements
            .where((element) => _intersects(element, bounds))
            .map((element) => element.id);
        _selectedIds.addAll(matches);
      }
      _clearGesture();
      notifyListeners();
      return;
    }

    if (_gestureStart != null) {
      final before = _gestureDocumentBefore;
      final handle = _activeResizeHandle;
      if (handle != null && _gestureOriginals.length == 1) {
        if (worldPosition.x == _gestureStart!.x &&
            worldPosition.y == _gestureStart!.y) {
          _document = _document.replaceElement(_gestureOriginals.single);
        } else {
          _resizeElement(_gestureOriginals.single, handle, worldPosition);
        }
      } else if (_isMoving && _gestureOriginals.isNotEmpty) {
        final delta = _snappedMoveDelta(worldPosition.x - _gestureStart!.x,
            worldPosition.y - _gestureStart!.y);
        for (final original in _gestureOriginals) {
          _document = _document.replaceElement(delta.x == 0 && delta.y == 0
              ? original
              : original.translated(delta.x, delta.y));
        }
      }
      _clearGesture();
      if (before != null) _recordHistory(before);
      notifyListeners();
    }
  }

  void setSnapToGrid(bool enabled) {
    if (_snapToGrid == enabled) return;
    _snapToGrid = enabled;
    notifyListeners();
  }

  void setSnapToGuides(bool enabled) {
    if (_snapToGuides == enabled) return;
    _snapToGuides = enabled;
    if (!enabled) {
      _alignmentGuidesX = const [];
      _alignmentGuidesY = const [];
    }
    notifyListeners();
  }

  void groupSelection() {
    if (!canGroupSelection) return;
    final before = _document;
    final groupId = 'group-${++_groupCounter}';
    for (final element in selectedElements) {
      _document = _document.replaceElement(element.copyWith(
        extraData: {...element.extraData, 'flutterdrawGroupId': groupId},
      ));
    }
    _recordHistory(before);
    notifyListeners();
  }

  void ungroupSelection() {
    final grouped = selectedElements
        .where((e) => e.extraData['flutterdrawGroupId'] is String)
        .toList();
    if (grouped.isEmpty) return;
    final before = _document;
    for (final element in grouped) {
      final data = Map<String, Object?>.from(element.extraData)
        ..remove('flutterdrawGroupId');
      _document = _document.replaceElement(element.copyWith(extraData: data));
    }
    _recordHistory(before);
    notifyListeners();
  }

  void alignSelection(ElementAlignment alignment) {
    final selected = selectedElements;
    if (selected.length < 2) return;
    final bounds = selectionBounds!;
    final before = _document;
    for (final element in selected) {
      var dx = 0.0, dy = 0.0;
      switch (alignment) {
        case ElementAlignment.left:
          dx = bounds.left - element.left;
          break;
        case ElementAlignment.centerHorizontal:
          dx = (bounds.left + bounds.right) / 2 -
              (element.left + element.right) / 2;
          break;
        case ElementAlignment.right:
          dx = bounds.right - element.right;
          break;
        case ElementAlignment.top:
          dy = bounds.top - element.top;
          break;
        case ElementAlignment.centerVertical:
          dy = (bounds.top + bounds.bottom) / 2 -
              (element.top + element.bottom) / 2;
          break;
        case ElementAlignment.bottom:
          dy = bounds.bottom - element.bottom;
          break;
      }
      _document = _document.replaceElement(element.translated(dx, dy));
    }
    _recordHistory(before);
    notifyListeners();
  }

  void selectElementById(String id, {bool additive = false}) {
    DrawingElement? element;
    for (final candidate in _document.elements) {
      if (candidate.id == id) {
        element = candidate;
        break;
      }
    }
    if (element == null) return;
    final groupId = element.extraData['flutterdrawGroupId'];
    final ids = groupId is String
        ? _document.elements
            .where((e) => e.extraData['flutterdrawGroupId'] == groupId)
            .map((e) => e.id)
            .toSet()
        : {id};
    if (additive) {
      if (ids.every(_selectedIds.contains)) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    } else {
      _selectedIds
        ..clear()
        ..addAll(ids);
    }
    notifyListeners();
  }

  void reorderLayers(List<String> topToBottomIds) {
    final byId = {
      for (final element in _document.elements) element.id: element
    };
    final ordered = topToBottomIds.reversed
        .where(byId.containsKey)
        .map((id) => byId[id]!)
        .toList();
    if (ordered.length != _document.elements.length) return;
    final before = _document;
    _document = DrawDocument(
        elements: ordered,
        assets: _document.assets,
        extraData: _document.extraData);
    _recordHistory(before);
    notifyListeners();
  }

  void deleteSelection() {
    if (_selectedIds.isEmpty) return;
    final before = _document;
    _document = _document.removeElements(_selectedIds);
    _selectedIds.clear();
    _clearGesture();
    _recordHistory(before);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    _clearGesture();
    notifyListeners();
  }

  void copySelection() {
    _clipboard
      ..clear()
      ..addAll(selectedElements);
  }

  void paste() {
    if (_clipboard.isEmpty) return;
    final before = _document;
    final copies = <DrawingElement>[];
    final groupRemap = <String, String>{};
    for (final element in _clipboard) {
      _idCounter++;
      var copy = element.translated(20, 20, newId: 'element-$_idCounter');
      final originalGroup = element.extraData['flutterdrawGroupId'];
      if (originalGroup is String) {
        final newGroup = groupRemap.putIfAbsent(
            originalGroup, () => 'group-${++_groupCounter}');
        copy = copy.copyWith(
            extraData: {...copy.extraData, 'flutterdrawGroupId': newGroup});
      }
      copies.add(copy);
    }
    _document = DrawDocument(
        elements: [..._document.elements, ...copies],
        assets: _document.assets,
        extraData: _document.extraData);
    _selectedIds
      ..clear()
      ..addAll(copies.map((element) => element.id));
    _recordHistory(before);
    notifyListeners();
  }

  void duplicateSelection() {
    copySelection();
    paste();
  }

  void bringSelectionToFront() {
    if (_selectedIds.isEmpty) return;
    final before = _document;
    _document = _document.reorder(_selectedIds, toFront: true);
    _recordHistory(before);
    notifyListeners();
  }

  void sendSelectionToBack() {
    if (_selectedIds.isEmpty) return;
    final before = _document;
    _document = _document.reorder(_selectedIds, toFront: false);
    _recordHistory(before);
    notifyListeners();
  }

  void cancelGesture() {
    if (_drawingStart == null && _gestureStart == null) return;
    _rollbackSelectionGesture();
    _clearGesture();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    _restoreHistoryDocument();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    _restoreHistoryDocument();
  }

  void _restoreHistoryDocument() {
    _document = _history[_historyIndex];
    final validIds = _document.elements.map((element) => element.id).toSet();
    _selectedIds.removeWhere((id) => !validIds.contains(id));
    _clearGesture();
    _lastHistoryMergeKey = null;
    notifyListeners();
  }

  void _recordHistory(DrawDocument before, {String? mergeKey}) {
    if (_sameDocument(before, _document)) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    if (mergeKey != null &&
        mergeKey == _lastHistoryMergeKey &&
        _historyIndex > 0) {
      _history[_historyIndex] = _document;
    } else {
      _history.add(_document);
      _historyIndex = _history.length - 1;
      if (_history.length > 100) {
        _history.removeAt(0);
        _historyIndex--;
      }
    }
    _lastHistoryMergeKey = mergeKey;
  }

  bool _sameDocument(DrawDocument a, DrawDocument b) {
    if (a.elements.length != b.elements.length) return false;
    for (var i = 0; i < a.elements.length; i++) {
      if (!identical(a.elements[i], b.elements[i])) return false;
    }
    return true;
  }

  DrawingElementType? _drawingTypeForTool(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.rectangle:
        return DrawingElementType.rectangle;
      case CanvasTool.ellipse:
        return DrawingElementType.ellipse;
      case CanvasTool.diamond:
        return DrawingElementType.diamond;
      case CanvasTool.line:
        return DrawingElementType.line;
      case CanvasTool.arrow:
        return DrawingElementType.arrow;
      case CanvasTool.freehand:
        return DrawingElementType.freehand;
      case CanvasTool.text:
        return null;
      case CanvasTool.select:
      case CanvasTool.hand:
        return null;
    }
  }

  DrawingElement _makeDraggedElement(
    DrawingElementType type,
    Point2 start,
    Point2 end,
  ) {
    return DrawingElement.fromDrag(
      id: _draftId!,
      type: type,
      start: start,
      end: end,
      seed: _draftSeed,
    );
  }

  DrawingElement? _hitTest(Point2 point, double tolerance) {
    for (final element in _document.elements.reversed) {
      if (element.type == DrawingElementType.text) {
        if (point.x >= element.left - tolerance &&
            point.x <= element.right + tolerance &&
            point.y >= element.top - tolerance &&
            point.y <= element.bottom + tolerance) {
          return element;
        }
      } else if (element.type == DrawingElementType.line ||
          element.type == DrawingElementType.arrow ||
          element.type == DrawingElementType.freehand) {
        for (var i = 1; i < element.points.length; i++) {
          if (_distanceToSegment(
                  point, element.points[i - 1], element.points[i]) <=
              tolerance + element.strokeWidth) {
            return element;
          }
        }
      } else if (point.x >= element.left - tolerance &&
          point.x <= element.right + tolerance &&
          point.y >= element.top - tolerance &&
          point.y <= element.bottom + tolerance) {
        return element;
      }
    }
    return null;
  }

  double _distanceToSegment(Point2 p, Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt(math.pow(p.x - a.x, 2) + math.pow(p.y - a.y, 2));
    }
    final t =
        (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(0.0, 1.0);
    final x = a.x + t * dx;
    final y = a.y + t * dy;
    return math.sqrt(math.pow(p.x - x, 2) + math.pow(p.y - y, 2));
  }

  bool _intersects(DrawingElement element, SelectionBounds bounds) =>
      element.right >= bounds.left &&
      element.left <= bounds.right &&
      element.bottom >= bounds.top &&
      element.top <= bounds.bottom;

  ResizeHandle? _hitResizeHandle(
    SelectionBounds bounds,
    Point2 point,
    double tolerance,
  ) {
    final cx = (bounds.left + bounds.right) / 2;
    final cy = (bounds.top + bounds.bottom) / 2;
    final handles = <ResizeHandle, Point2>{
      ResizeHandle.topLeft: Point2(bounds.left, bounds.top),
      ResizeHandle.topCenter: Point2(cx, bounds.top),
      ResizeHandle.topRight: Point2(bounds.right, bounds.top),
      ResizeHandle.middleRight: Point2(bounds.right, cy),
      ResizeHandle.bottomRight: Point2(bounds.right, bounds.bottom),
      ResizeHandle.bottomCenter: Point2(cx, bounds.bottom),
      ResizeHandle.bottomLeft: Point2(bounds.left, bounds.bottom),
      ResizeHandle.middleLeft: Point2(bounds.left, cy),
    };
    for (final entry in handles.entries) {
      final dx = point.x - entry.value.x;
      final dy = point.y - entry.value.y;
      if (dx * dx + dy * dy <= tolerance * tolerance) return entry.key;
    }
    return null;
  }

  void _resizeElement(
    DrawingElement original,
    ResizeHandle handle,
    Point2 pointer,
  ) {
    var left = original.left;
    var top = original.top;
    var right = original.right;
    var bottom = original.bottom;
    switch (handle) {
      case ResizeHandle.topLeft:
        left = pointer.x;
        top = pointer.y;
        break;
      case ResizeHandle.topCenter:
        top = pointer.y;
        break;
      case ResizeHandle.topRight:
        right = pointer.x;
        top = pointer.y;
        break;
      case ResizeHandle.middleRight:
        right = pointer.x;
        break;
      case ResizeHandle.bottomRight:
        right = pointer.x;
        bottom = pointer.y;
        break;
      case ResizeHandle.bottomCenter:
        bottom = pointer.y;
        break;
      case ResizeHandle.bottomLeft:
        left = pointer.x;
        bottom = pointer.y;
        break;
      case ResizeHandle.middleLeft:
        left = pointer.x;
        break;
    }
    if (original.type == DrawingElementType.image && _lockImageAspectRatio) {
      const minimumSize = 1.0;
      final originalWidth =
          original.width.abs().clamp(minimumSize, double.infinity);
      final originalHeight =
          original.height.abs().clamp(minimumSize, double.infinity);
      final aspectRatio = originalWidth / originalHeight;
      final rawWidth = (right - left).abs();
      final rawHeight = (bottom - top).abs();
      final isHorizontalEdge = handle == ResizeHandle.middleLeft ||
          handle == ResizeHandle.middleRight;
      final isVerticalEdge = handle == ResizeHandle.topCenter ||
          handle == ResizeHandle.bottomCenter;
      final scale = isHorizontalEdge
          ? rawWidth / originalWidth
          : isVerticalEdge
              ? rawHeight / originalHeight
              : math.max(
                  rawWidth / originalWidth,
                  rawHeight / originalHeight,
                );
      final width = (originalWidth * scale).clamp(minimumSize, 10000.0);
      final height = (width / aspectRatio).clamp(minimumSize, 10000.0);

      if (isVerticalEdge) {
        final centerX = (original.left + original.right) / 2;
        left = centerX - width / 2;
        right = centerX + width / 2;
      } else if (handle == ResizeHandle.middleLeft ||
          handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.bottomLeft) {
        left = original.right - width;
        right = original.right;
      } else {
        left = original.left;
        right = original.left + width;
      }

      if (isHorizontalEdge) {
        final centerY = (original.top + original.bottom) / 2;
        top = centerY - height / 2;
        bottom = centerY + height / 2;
      } else if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topCenter ||
          handle == ResizeHandle.topRight) {
        top = original.bottom - height;
        bottom = original.bottom;
      } else {
        top = original.top;
        bottom = original.top + height;
      }
    }

    _document = _document.replaceElement(original.copyWith(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    ));
  }

  Point2 _snappedMoveDelta(double dx, double dy) {
    _alignmentGuidesX = const [];
    _alignmentGuidesY = const [];
    if (!_snapToGrid && !_snapToGuides) return Point2(dx, dy);
    final originals = _gestureOriginals;
    if (originals.isEmpty) return Point2(dx, dy);
    final left =
        originals.map((e) => e.left).reduce((a, b) => a < b ? a : b) + dx;
    final top =
        originals.map((e) => e.top).reduce((a, b) => a < b ? a : b) + dy;
    final right =
        originals.map((e) => e.right).reduce((a, b) => a > b ? a : b) + dx;
    final bottom =
        originals.map((e) => e.bottom).reduce((a, b) => a > b ? a : b) + dy;
    final centerX = (left + right) / 2, centerY = (top + bottom) / 2;
    const grid = 24.0, tolerance = 8.0;
    var adjustX = 0.0, adjustY = 0.0;
    if (_snapToGrid) {
      final gx = (left / grid).round() * grid - left;
      final gy = (top / grid).round() * grid - top;
      if (gx.abs() <= tolerance) adjustX = gx;
      if (gy.abs() <= tolerance) adjustY = gy;
    }
    if (_snapToGuides) {
      double? bestX, bestY, guideX, guideY;
      for (final other
          in _document.elements.where((e) => !_selectedIds.contains(e.id))) {
        final xs = [other.left, (other.left + other.right) / 2, other.right];
        final ys = [other.top, (other.top + other.bottom) / 2, other.bottom];
        for (final own in [left, centerX, right]) {
          for (final target in xs) {
            final difference = target - own;
            if (difference.abs() <= tolerance &&
                (bestX == null || difference.abs() < bestX.abs())) {
              bestX = difference;
              guideX = target;
            }
          }
        }
        for (final own in [top, centerY, bottom]) {
          for (final target in ys) {
            final difference = target - own;
            if (difference.abs() <= tolerance &&
                (bestY == null || difference.abs() < bestY.abs())) {
              bestY = difference;
              guideY = target;
            }
          }
        }
      }
      if (bestX != null) {
        adjustX = bestX;
        _alignmentGuidesX = [guideX!];
      }
      if (bestY != null) {
        adjustY = bestY;
        _alignmentGuidesY = [guideY!];
      }
    }
    return Point2(dx + adjustX, dy + adjustY);
  }

  void _rollbackSelectionGesture() {
    for (final original in _gestureOriginals) {
      _document = _document.replaceElement(original);
    }
  }

  void _clearGesture() {
    _drawingStart = null;
    _drawingPreview = null;
    _draftId = null;
    _gestureStart = null;
    _marqueeEnd = null;
    _gestureOriginals = [];
    _activeResizeHandle = null;
    _isMoving = false;
    _gestureDocumentBefore = null;
    _alignmentGuidesX = const [];
    _alignmentGuidesY = const [];
  }
}
