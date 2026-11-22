import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';
import 'package:flutterdraw/infrastructure/serialization/excalidraw_codec.dart';

void main() {
  const codec = ExcalidrawCodec();

  group('ExcalidrawCodec', () {
    test('imports shapes, freehand, text and group membership', () {
      const source = '''
      {
        "type":"excalidraw","version":2,
        "elements":[
          {"id":"rect-1","type":"rectangle","x":10,"y":20,"width":100,"height":60,
           "strokeColor":"#123456","backgroundColor":"#abcdef","strokeWidth":3,
           "roughness":1,"opacity":75,"seed":42,"groupIds":["group-1"],"points":[]},
          {"id":"free-1","type":"freedraw","x":100,"y":200,"width":30,"height":20,
           "points":[[0,0],[10,20],[30,5]],"strokeColor":"#000000",
           "backgroundColor":"transparent","strokeWidth":2,"roughness":0,"opacity":100,"seed":7},
          {"id":"text-1","type":"text","x":5,"y":6,"width":160,"height":50,
           "text":"Hello","fontSize":28,"fontFamily":2,"textAlign":"center",
           "strokeColor":"#ff0000","backgroundColor":"transparent","opacity":100,"seed":9}
        ],
        "appState":{"viewBackgroundColor":"#fefefe"},"files":{}
      }
      ''';
      final document = codec.decode(source);
      expect(document.elements, hasLength(3));
      expect(document.elements[0].strokeColor, 0xFF123456);
      expect(document.elements[0].fillColor, 0xFFABCDEF);
      expect(document.elements[0].opacity, 0.75);
      expect(document.elements[0].extraData['flutterdrawGroupId'], 'group-1');
      expect(document.elements[1].points, const [
        Point2(100, 200), Point2(110, 220), Point2(130, 205),
      ]);
      expect(document.elements[2].text, 'Hello');
      expect(document.elements[2].fontFamily, 'Arial');
      expect(document.elements[2].textAlign, 'center');
    });

    test('retains unknown fields and unsupported elements', () {
      const source = '''
      {
        "type":"excalidraw","version":2,"source":"external-tool",
        "customRoot":{"kept":true},
        "elements":[
          {"id":"rect","type":"rectangle","x":1,"y":2,"width":30,"height":40,
           "strokeColor":"#112233","backgroundColor":"transparent","strokeWidth":2,
           "roughness":1,"opacity":100,"seed":1,"points":[],"customElementField":"preserve"},
          {"id":"image-1","type":"image","fileId":"asset-1","x":0,"y":0}
        ],
        "appState":{"viewBackgroundColor":"#fafafa"},
        "files":{"asset-1":{"mimeType":"image/png"}}
      }
      ''';
      final imported = codec.decode(source);
      final json = jsonDecode(codec.encode(imported, pretty: false)) as Map<String, dynamic>;
      final elements = json['elements'] as List;
      expect(json['customRoot'], {'kept': true});
      expect(json['source'], 'external-tool');
      expect(elements, hasLength(2));
      expect(elements[0]['customElementField'], 'preserve');
      expect(elements[1]['fileId'], 'asset-1');
      expect(json['files']['asset-1']['mimeType'], 'image/png');
    });

    test('exports native elements to Excalidraw JSON', () {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'arrow-1', type: DrawingElementType.arrow,
          x: 10, y: 20, width: 40, height: 30, seed: 5,
          points: const [Point2(10, 20), Point2(50, 50)],
          strokeColor: 0xFF2563EB,
          strokeAlignment: StrokeAlignment.inside,
        ),
      ]);
      final json = jsonDecode(codec.encode(document, pretty: false)) as Map<String, dynamic>;
      final element = (json['elements'] as List).single as Map<String, dynamic>;
      expect(json['type'], 'excalidraw');
      expect(element['type'], 'arrow');
      expect(element['points'], [[0, 0], [40, 30]]);
      expect(element['strokeColor'], '#2563eb');
      expect(element['flutterdrawStrokeAlignment'], 'inside');
    });

    test('rejects another JSON format', () {
      expect(() => codec.decode('{"type":"other","elements":[]}'), throwsFormatException);
    });
  });
}
