import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';

void main() {
  group('CanvasEditorController selection and editing', () {
    CanvasEditorController makeControllerWithRectangle() {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(10, 20));
      controller.pointerUp(const Point2(110, 120));
      controller.setActiveTool(CanvasTool.select);
      return controller;
    }

    test('selects and moves an element', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(50, 60));
      controller.pointerMove(const Point2(70, 90));
      controller.pointerUp(const Point2(70, 90));

      final rectangle = controller.selectedElements.single;
      expect(rectangle.x, 30);
      expect(rectangle.y, 50);
      expect(rectangle.width, 100);
      expect(rectangle.height, 100);
      controller.dispose();
    });

    test('resizes a selected rectangle from its bottom-right handle', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(110, 120));
      controller.pointerMove(const Point2(150, 170));
      controller.pointerUp(const Point2(150, 170));

      final rectangle = controller.selectedElements.single;
      expect(rectangle.width, 140);
      expect(rectangle.height, 150);
      controller.dispose();
    });

    test('marquee selects multiple elements', () {
      final controller = makeControllerWithRectangle();
      controller.setActiveTool(CanvasTool.ellipse);
      controller.pointerDown(const Point2(140, 20));
      controller.pointerUp(const Point2(180, 60));
      controller.setActiveTool(CanvasTool.select);

      controller.pointerDown(const Point2(0, 0));
      controller.pointerMove(const Point2(200, 140));
      controller.pointerUp(const Point2(200, 140));

      expect(controller.selectedElementIds.length, 2);
      controller.dispose();
    });

    test('shift-style marquee adds to the existing selection', () {
      final controller = makeControllerWithRectangle();
      controller.setActiveTool(CanvasTool.ellipse);
      controller.pointerDown(const Point2(140, 20));
      controller.pointerUp(const Point2(180, 60));
      controller.setActiveTool(CanvasTool.select);

      controller.pointerDown(
        const Point2(130, 10),
        additiveSelection: true,
      );
      controller.pointerMove(const Point2(190, 70));
      controller.pointerUp(const Point2(190, 70));

      expect(controller.selectedElementIds.length, 2);
      controller.dispose();
    });

    test('copies and pastes selected elements with new ids', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));
      controller.copySelection();
      controller.paste();

      expect(controller.document.elements.length, 2);
      expect(controller.selectedElements.single.id, isNot('element-1'));
      expect(controller.selectedElements.single.x, 30);
      expect(controller.selectedElements.single.y, 40);
      controller.dispose();
    });

    test('duplicates selection', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));
      controller.duplicateSelection();

      expect(controller.document.elements.length, 2);
      expect(controller.selectedElements.single.x, 30);
      controller.dispose();
    });

    test('moves selected elements to front and back', () {
      final controller = makeControllerWithRectangle();
      controller.setActiveTool(CanvasTool.ellipse);
      controller.pointerDown(const Point2(140, 20));
      controller.pointerUp(const Point2(180, 60));
      controller.setActiveTool(CanvasTool.select);

      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));
      controller.bringSelectionToFront();
      expect(controller.document.elements.last.id,
          controller.selectedElements.single.id);
      controller.sendSelectionToBack();
      expect(controller.document.elements.first.id,
          controller.selectedElements.single.id);
      controller.dispose();
    });

    test('cancelling a move restores original geometry', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(50, 60));
      controller.pointerMove(const Point2(80, 90));
      controller.cancelGesture();

      final rectangle = controller.document.elements.single;
      expect(rectangle.x, 10);
      expect(rectangle.y, 20);
      controller.dispose();
    });

    test('deletes all selected elements', () {
      final controller = makeControllerWithRectangle();
      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));
      controller.deleteSelection();

      expect(controller.document.elements, isEmpty);
      expect(controller.selectedElementIds, isEmpty);
      controller.dispose();
    });
  });
}
