import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';

void main() {
  group('CanvasEditorController selection', () {
    CanvasEditorController makeControllerWithRectangle() {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(10, 20));
      controller.pointerUp(const Point2(110, 120));
      controller.setActiveTool(CanvasTool.select);
      return controller;
    }

    test('selects a rectangle by clicking inside it', () {
      final controller = makeControllerWithRectangle();

      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));

      expect(controller.selectedElementId, 'rectangle-1');
      controller.dispose();
    });

    test('moves a selected rectangle without changing its size', () {
      final controller = makeControllerWithRectangle();

      controller.pointerDown(const Point2(50, 60));
      controller.pointerMove(const Point2(70, 90));
      controller.pointerUp(const Point2(70, 90));

      final rectangle = controller.selectedRectangle!;
      expect(rectangle.x, 30);
      expect(rectangle.y, 50);
      expect(rectangle.width, 100);
      expect(rectangle.height, 100);
      controller.dispose();
    });

    test('resizes a rectangle from its bottom-right handle', () {
      final controller = makeControllerWithRectangle();

      controller.pointerDown(const Point2(110, 120));
      controller.pointerMove(const Point2(150, 170));
      controller.pointerUp(const Point2(150, 170));

      final rectangle = controller.selectedRectangle!;
      expect(rectangle.x, 10);
      expect(rectangle.y, 20);
      expect(rectangle.width, 140);
      expect(rectangle.height, 150);
      controller.dispose();
    });


    test('cancelling a move restores the original geometry', () {
      final controller = makeControllerWithRectangle();

      controller.pointerDown(const Point2(50, 60));
      controller.pointerMove(const Point2(80, 90));
      controller.cancelGesture();

      final rectangle = controller.document.rectangles.single;
      expect(rectangle.x, 10);
      expect(rectangle.y, 20);
      expect(rectangle.width, 100);
      expect(rectangle.height, 100);
      controller.dispose();
    });

    test('delete removes the selected rectangle', () {
      final controller = makeControllerWithRectangle();

      controller.pointerDown(const Point2(50, 60));
      controller.pointerUp(const Point2(50, 60));
      controller.deleteSelection();

      expect(controller.document.rectangles, isEmpty);
      expect(controller.selectedElementId, isNull);
      controller.dispose();
    });
  });
}
