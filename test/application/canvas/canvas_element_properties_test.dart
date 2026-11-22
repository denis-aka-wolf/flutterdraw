import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';

void main() {
  group('Canvas element properties', () {
    test('updates text style, alignment, opacity and block dimensions', () {
      final controller = CanvasEditorController();
      controller.addText(const Point2(20, 30), 'FlutterDraw');
      controller.updateSelectedProperties(
        strokeColor: 0xFF2563EB,
        opacity: 0.45,
        fontFamily: 'Georgia',
        textAlign: 'center',
      );
      controller.setSelectedTextFontSize(32);
      controller.setSelectedTextBlockSize(width: 280, height: 110);

      final text = controller.selectedElements.single;
      expect(text.type, DrawingElementType.text);
      expect(text.strokeColor, 0xFF2563EB);
      expect(text.opacity, 0.45);
      expect(text.fontFamily, 'Georgia');
      expect(text.textAlign, 'center');
      expect(text.fontSize, 32);
      expect(text.width, 280);
      expect(text.height, 110);
      controller.dispose();
    });

    test('updates shape fill, outline, line width and opacity', () {
      final controller = CanvasEditorController()
        ..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(10, 10));
      controller.pointerUp(const Point2(100, 80));
      controller.updateSelectedProperties(
        strokeColor: 0xFFDC2626,
        fillColor: 0xFF16A34A,
        strokeWidth: 5,
        strokeOpacity: 0.35,
        fillOpacity: 0.7,
      );

      final shape = controller.selectedElements.single;
      expect(shape.strokeColor, 0xFFDC2626);
      expect(shape.fillColor, 0xFF16A34A);
      expect(shape.strokeWidth, 5);
      expect(shape.strokeOpacity, 0.35);
      expect(shape.fillOpacity, 0.7);
      controller.dispose();
    });
  });
}
