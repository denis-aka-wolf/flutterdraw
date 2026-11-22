import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/application/canvas/canvas_editor_controller.dart';

void main() {
  test('canvas editor starts with an empty document', () {
    final controller = CanvasEditorController();
    expect(controller.document.elements, isEmpty);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    controller.dispose();
  });
}
