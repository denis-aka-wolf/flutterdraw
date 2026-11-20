import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';
import 'package:flutterdraw/infrastructure/serialization/draw_document_codec.dart';

void main() {
  const codec = DrawDocumentCodec();

  group('DrawDocumentCodec', () {
    test('round-trips document elements and their geometry', () {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'rect-1',
          type: DrawingElementType.rectangle,
          x: 12.5,
          y: -8,
          width: 140,
          height: 70,
          seed: 12345,
          strokeColor: 0xFF123456,
          strokeWidth: 3.5,
          roughness: 0.75,
        ),
        DrawingElement(
          id: 'line-1',
          type: DrawingElementType.line,
          x: 0,
          y: 0,
          width: 40,
          height: 20,
          seed: 99,
          points: const [Point2(0, 0), Point2(40, 20)],
        ),
      ]);

      final restored = codec.decode(codec.encode(document));

      expect(restored.elements, hasLength(2));
      expect(restored.elements[0].id, 'rect-1');
      expect(restored.elements[0].type, DrawingElementType.rectangle);
      expect(restored.elements[0].x, 12.5);
      expect(restored.elements[0].width, 140);
      expect(restored.elements[0].strokeColor, 0xFF123456);
      expect(restored.elements[0].roughness, 0.75);
      expect(restored.elements[1].points, const [
        Point2(0, 0),
        Point2(40, 20),
      ]);
    });

    test('preserves unknown document and element fields', () {
      const source = '''
      {
        "type": "flutterdraw",
        "version": 1,
        "documentExtension": {"authoringTool": "external"},
        "elements": [{
          "id": "shape-1",
          "type": "rectangle",
          "x": 1,
          "y": 2,
          "width": 30,
          "height": 40,
          "seed": 7,
          "points": [],
          "strokeColor": 4280624428,
          "strokeWidth": 2,
          "roughness": 1,
          "futureProperty": {"enabled": true}
        }]
      }
      ''';

      final restored = codec.decode(source);
      final encoded = codec.encode(restored, pretty: false);
      final decoded = codec.decode(encoded);

      expect(decoded.extraData['documentExtension'], {
        'authoringTool': 'external',
      });
      expect(
        decoded.elements.single.extraData['futureProperty'],
        {'enabled': true},
      );
    });

    test('rejects a document with an unsupported future version', () {
      expect(
        () => codec.decode('{"type":"flutterdraw","version":99,"elements":[]}'),
        throwsFormatException,
      );
    });

    test('rejects a different file format', () {
      expect(
        () => codec.decode('{"type":"other","version":1,"elements":[]}'),
        throwsFormatException,
      );
    });

    test('rejects malformed element geometry', () {
      const source = '''
      {
        "type": "flutterdraw",
        "version": 1,
        "elements": [{
          "id": "broken",
          "type": "rectangle",
          "x": "not-a-number",
          "y": 0,
          "width": 10,
          "height": 10,
          "seed": 1,
          "points": []
        }]
      }
      ''';

      expect(() => codec.decode(source), throwsFormatException);
    });
  });
}
