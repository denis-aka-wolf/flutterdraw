import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';
import 'package:flutterdraw/application/canvas/canvas_tool.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';

void main() {
  group('Canvas document history', () {
    test('undoes and redoes a completed drawing gesture as one action', () {
      final controller = CanvasEditorController()..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(10, 10));
      controller.pointerMove(const Point2(100, 80));
      controller.pointerUp(const Point2(100, 80));
      expect(controller.document.elements, hasLength(1));
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect(controller.document.elements, isEmpty);
      expect(controller.canRedo, isTrue);
      controller.redo();
      expect(controller.document.elements, hasLength(1));
      controller.dispose();
    });

    test('groups moving a selected element into one history entry', () {
      final controller = CanvasEditorController()..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(10, 10));
      controller.pointerUp(const Point2(100, 80));
      final original = controller.document.elements.single;
      controller.setActiveTool(CanvasTool.select);
      controller.pointerDown(Point2(original.x + 10, original.y + 10));
      controller.pointerMove(Point2(original.x + 40, original.y + 35));
      controller.pointerUp(Point2(original.x + 40, original.y + 35));
      expect(controller.document.elements.single.x, original.x + 30);
      controller.undo();
      expect(controller.document.elements.single.x, original.x);
      controller.redo();
      expect(controller.document.elements.single.x, original.x + 30);
      controller.dispose();
    });

    test('coalesces repeated text and property edits', () {
      final controller = CanvasEditorController();
      controller.addText(const Point2(0, 0), 'Start');
      controller.updateSelectedText('S');
      controller.updateSelectedText('Sta');
      controller.updateSelectedText('Start again');
      controller.undo();
      expect(controller.selectedElements.single.text, 'Start');
      controller.redo();
      expect(controller.selectedElements.single.text, 'Start again');
      controller.updateSelectedProperties(opacity: 0.8);
      controller.updateSelectedProperties(opacity: 0.6);
      controller.undo();
      expect(controller.selectedElements.single.opacity, 1);
      controller.dispose();
    });

    test('new edits discard the redo branch', () {
      final controller = CanvasEditorController();
      controller.addText(const Point2(0, 0), 'First');
      controller.undo();
      expect(controller.canRedo, isTrue);
      controller.addText(const Point2(20, 20), 'Second');
      expect(controller.canRedo, isFalse);
      expect(controller.document.elements.single.text, 'Second');
      controller.dispose();
    });

    test('loading a document resets history and advances generated ids', () {
      final controller = CanvasEditorController();
      controller.addText(const Point2(0, 0), 'Temporary');
      controller.loadDocument(DrawDocument(elements: [
        DrawingElement(
          id: 'element-12',
          type: DrawingElementType.rectangle,
          x: 0, y: 0, width: 40, height: 30, seed: 12,
        ),
      ]));
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      controller.addText(const Point2(50, 50), 'New');
      expect(controller.document.elements.last.id, 'element-13');
      controller.undo();
      expect(controller.document.elements, hasLength(1));
      controller.dispose();
    });

    test('cancelled gestures do not enter history', () {
      final controller = CanvasEditorController()..setActiveTool(CanvasTool.rectangle);
      controller.pointerDown(const Point2(0, 0));
      controller.pointerMove(const Point2(50, 50));
      controller.cancelGesture();
      expect(controller.document.elements, isEmpty);
      expect(controller.canUndo, isFalse);
      controller.dispose();
    });
  });
}
