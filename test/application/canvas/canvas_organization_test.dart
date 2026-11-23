import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';

DrawingElement rect(
        String id, double x, double y, double width, double height) =>
    DrawingElement(
        id: id,
        type: DrawingElementType.rectangle,
        x: x,
        y: y,
        width: width,
        height: height,
        seed: id.hashCode);

void main() {
  group('Canvas organization tools', () {
    test('groups selected elements and selects the whole group', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('a', 0, 0, 20, 20),
          rect('b', 40, 40, 20, 20),
        ]));
      controller.selectElementById('a');
      controller.selectElementById('b', additive: true);
      controller.groupSelection();
      expect(
          controller.document.elements
              .map((e) => e.extraData['flutterdrawGroupId'])
              .toSet()
              .length,
          1);
      controller.selectElementById('a');
      expect(controller.selectedElementIds, {'a', 'b'});
      controller.ungroupSelection();
      expect(controller.canUngroupSelection, isFalse);
      controller.undo();
      expect(controller.canUngroupSelection, isTrue);
      controller.dispose();
    });

    test('pasting a group creates a separate group identity', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('a', 0, 0, 20, 20),
          rect('b', 40, 40, 20, 20),
        ]));
      controller.selectElementById('a');
      controller.selectElementById('b', additive: true);
      controller.groupSelection();
      controller.copySelection();
      controller.paste();
      final groups = controller.document.elements
          .map((e) => e.extraData['flutterdrawGroupId'])
          .toSet();
      expect(groups.length, 2);
      controller.dispose();
    });

    test('pasting a group creates a separate group identity', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('a', 0, 0, 20, 20),
          rect('b', 40, 40, 20, 20),
        ]));
      controller.selectElementById('a');
      controller.selectElementById('b', additive: true);
      controller.groupSelection();
      controller.copySelection();
      controller.paste();
      final groups = controller.document.elements
          .map((e) => e.extraData['flutterdrawGroupId'])
          .toSet();
      expect(groups.length, 2);
      controller.dispose();
    });

    test('aligns selected elements to their shared left edge', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('a', 10, 10, 20, 20),
          rect('b', 60, 50, 30, 20),
        ]));
      controller.selectElementById('a');
      controller.selectElementById('b', additive: true);
      controller.alignSelection(ElementAlignment.left);
      expect(controller.document.elements[0].left,
          controller.document.elements[1].left);
      controller.undo();
      expect(controller.document.elements[1].left, 60);
      controller.dispose();
    });

    test('reorders layers from top to bottom', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('bottom', 0, 0, 10, 10),
          rect('middle', 20, 0, 10, 10),
          rect('top', 40, 0, 10, 10),
        ]));
      controller.reorderLayers(['middle', 'top', 'bottom']);
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['bottom', 'top', 'middle']);
      controller.dispose();
    });

    test('moves selection above the nearest overlapping object', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('selected', 0, 0, 30, 30),
          rect('unrelated', 100, 100, 20, 20),
          rect('overlap-near', 10, 10, 20, 20),
          rect('overlap-far', 5, 5, 20, 20),
        ]));
      controller.selectElementById('selected');
      controller.moveSelectionUp();
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['unrelated', 'overlap-near', 'selected', 'overlap-far']);
      controller.undo();
      expect(controller.document.elements.first.id, 'selected');
      controller.dispose();
    });

    test('moves selection below the nearest overlapping object', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('overlap-far', 5, 5, 20, 20),
          rect('overlap-near', 10, 10, 20, 20),
          rect('unrelated', 100, 100, 20, 20),
          rect('selected', 0, 0, 30, 30),
        ]));
      controller.selectElementById('selected');
      controller.moveSelectionDown();
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['overlap-far', 'selected', 'overlap-near', 'unrelated']);
      controller.dispose();
    });

    test('moves one layer in global mode even without intersection', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('selected', 0, 0, 10, 10),
          rect('unrelated', 100, 100, 10, 10),
        ]));
      controller.setRelativeLayerMovement(false);
      controller.selectElementById('selected');
      controller.moveSelectionUp();
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['unrelated', 'selected']);
      controller.dispose();
    });

    test('relative layer movement does nothing without an overlap', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('selected', 0, 0, 10, 10),
          rect('unrelated', 100, 100, 10, 10),
        ]));
      controller.selectElementById('selected');
      controller.moveSelectionUp();
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['selected', 'unrelated']);
      expect(controller.canUndo, isFalse);
      controller.dispose();
    });

    test('moves a multi-selection as one block', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('selected-a', 0, 0, 20, 20),
          rect('selected-b', 5, 5, 20, 20),
          rect('overlap', 10, 10, 20, 20),
        ]));
      controller.selectElementById('selected-a');
      controller.selectElementById('selected-b', additive: true);
      controller.moveSelectionUp();
      expect(controller.document.elements.map((e) => e.id).toList(),
          ['overlap', 'selected-a', 'selected-b']);
      controller.dispose();
    });

    test('snaps a moving object to another object and exposes guides', () {
      final controller = CanvasEditorController()
        ..loadDocument(DrawDocument(elements: [
          rect('moving', 0, 0, 20, 20),
          rect('target', 100, 100, 20, 20),
        ]));
      controller.setActiveTool(CanvasTool.select);
      controller.pointerDown(const Point2(10, 10));
      controller.pointerMove(const Point2(89, 89));
      expect(controller.alignmentGuidesX, contains(100));
      expect(controller.alignmentGuidesY, contains(100));
      controller.pointerUp(const Point2(89, 89));
      expect(controller.document.elements.first.x, 80);
      expect(controller.document.elements.first.y, 80);
      controller.dispose();
    });

    test('allows snapping modes to be disabled', () {
      final controller = CanvasEditorController();
      controller.setSnapToGrid(false);
      controller.setSnapToGuides(false);
      expect(controller.snapToGrid, isFalse);
      expect(controller.snapToGuides, isFalse);
      controller.dispose();
    });
  });
}
