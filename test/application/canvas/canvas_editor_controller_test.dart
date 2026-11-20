import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';

void main() {
  group('CanvasEditorController', () {
    test('commits a rectangle after a drag', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);

      controller.pointerDown(const Point2(100, 120));
      controller.pointerMove(const Point2(40, 60));

      expect(controller.document.rectangles, isEmpty);
      expect(controller.rectanglePreview, isNotNull);

      controller.pointerUp(const Point2(40, 60));

      expect(controller.rectanglePreview, isNull);
      expect(controller.document.rectangles, hasLength(1));
      expect(controller.document.rectangles.single.x, 40);
      expect(controller.document.rectangles.single.y, 60);
      expect(controller.document.rectangles.single.width, 60);
      expect(controller.document.rectangles.single.height, 60);
      controller.dispose();
    });

    test('does not commit a click-sized rectangle', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);

      controller.pointerDown(const Point2(10, 10));
      controller.pointerUp(const Point2(11, 11));

      expect(controller.document.rectangles, isEmpty);
      controller.dispose();
    });

    test('changing tools cancels an in-progress gesture', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);

      controller.pointerDown(const Point2(0, 0));
      controller.setActiveTool(CanvasTool.select);

      expect(controller.rectanglePreview, isNull);
      controller.pointerUp(const Point2(50, 50));
      expect(controller.document.rectangles, isEmpty);
      controller.dispose();
    });
  });
}
