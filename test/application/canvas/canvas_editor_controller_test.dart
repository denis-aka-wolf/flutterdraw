import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';

void main() {
  group('CanvasEditorController drawing tools', () {
    for (final entry in <(CanvasTool, DrawingElementType)>[
      (CanvasTool.rectangle, DrawingElementType.rectangle),
      (CanvasTool.ellipse, DrawingElementType.ellipse),
      (CanvasTool.diamond, DrawingElementType.diamond),
      (CanvasTool.line, DrawingElementType.line),
      (CanvasTool.arrow, DrawingElementType.arrow),
    ]) {
      test('draws ${entry.$2.name}', () {
        final controller = CanvasEditorController()..setActiveTool(entry.$1);
        controller.pointerDown(const Point2(100, 120));
        controller.pointerMove(const Point2(40, 60));

        expect(controller.document.elements, isEmpty);
        expect(controller.drawingPreview, isNotNull);

        controller.pointerUp(const Point2(40, 60));
        expect(controller.document.elements, hasLength(1));
        expect(controller.document.elements.single.type, entry.$2);
        expect(controller.document.elements.single.left, 40);
        expect(controller.document.elements.single.top, 60);
        controller.dispose();
      });
    }

    test('records a freehand stroke as sampled points', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.freehand);
      controller.pointerDown(const Point2(10, 10));
      controller.pointerMove(const Point2(20, 15));
      controller.pointerMove(const Point2(30, 25));
      controller.pointerUp(const Point2(40, 30));

      final stroke = controller.document.elements.single;
      expect(stroke.type, DrawingElementType.freehand);
      expect(stroke.points.length, 4);
      controller.dispose();
    });

    test('changing tools cancels an in-progress drawing', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.ellipse);
      controller.pointerDown(const Point2(0, 0));
      controller.setActiveTool(CanvasTool.select);
      expect(controller.drawingPreview, isNull);
      controller.pointerUp(const Point2(50, 50));
      expect(controller.document.elements, isEmpty);
      controller.dispose();
    });
  });
}
