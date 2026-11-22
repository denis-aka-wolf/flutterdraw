import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/document/document_asset.dart';
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
      expect(document.elements[0].strokeOpacity, 0.75);
      expect(document.elements[0].fillOpacity, 0.75);
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
          strokeOpacity: 0.35,
          fillOpacity: 0.8,
        ),
      ]);
      final json = jsonDecode(codec.encode(document, pretty: false)) as Map<String, dynamic>;
      final element = (json['elements'] as List).single as Map<String, dynamic>;
      expect(json['type'], 'excalidraw');
      expect(element['type'], 'arrow');
      expect(element['points'], [[0, 0], [40, 30]]);
      expect(element['strokeColor'], '#2563eb');
      expect(element['flutterdrawStrokeAlignment'], 'inside');
      expect(element['flutterdrawStrokeOpacity'], 35);
      expect(element['flutterdrawFillOpacity'], 80);
    });

    test('imports and exports embedded Excalidraw file data', () {
      const source = '''
      {
        "type":"excalidraw","version":2,
        "elements":[],
        "files":{
          "asset-1":{
            "id":"asset-1",
            "mimeType":"image/png",
            "dataURL":"data:image/png;base64,AAEC/w==",
            "created":123
          }
        }
      }
      ''';

      final imported = codec.decode(source);
      final asset = imported.assets['asset-1']!;
      expect(asset.mimeType, 'image/png');
      expect(asset.bytes, [0, 1, 2, 255]);
      expect(asset.extraData['created'], 123);

      final exported = jsonDecode(codec.encode(imported, pretty: false)) as Map<String, dynamic>;
      expect(exported['files']['asset-1']['dataURL'], 'data:image/png;base64,AAEC/w==');
    });

    test('exports native embedded assets to Excalidraw file records', () {
      final document = DrawDocument(assets: {
        'asset-native': DocumentAsset(
          id: 'asset-native',
          mimeType: 'image/jpeg',
          bytes: [4, 5, 6],
        ),
      });

      final exported = jsonDecode(codec.encode(document, pretty: false)) as Map<String, dynamic>;
      expect(exported['files']['asset-native']['mimeType'], 'image/jpeg');
      expect(exported['files']['asset-native']['dataURL'], 'data:image/jpeg;base64,BAUG');
    });

    test('round-trips an image element and its embedded file', () {
      final document = DrawDocument(
        elements: [
          DrawingElement(
            id: 'image-1',
            type: DrawingElementType.image,
            x: 10,
            y: 20,
            width: 300,
            height: 200,
            seed: 7,
            assetId: 'asset-1',
          ),
        ],
        assets: {
          'asset-1': DocumentAsset(
            id: 'asset-1',
            mimeType: 'image/png',
            bytes: [0, 1, 2, 255],
          ),
        },
      );

      final encoded = jsonDecode(codec.encode(document, pretty: false)) as Map<String, dynamic>;
      final element = (encoded['elements'] as List).single as Map<String, dynamic>;
      expect(element['type'], 'image');
      expect(element['fileId'], 'asset-1');
      expect(encoded['files']['asset-1']['dataURL'], 'data:image/png;base64,AAEC/w==');

      final restored = codec.decode(jsonEncode(encoded));
      expect(restored.elements.single.type, DrawingElementType.image);
      expect(restored.elements.single.assetId, 'asset-1');
      expect(restored.assets['asset-1']!.bytes, [0, 1, 2, 255]);
    });

    test('rejects another JSON format', () {
      expect(() => codec.decode('{"type":"other","elements":[]}'), throwsFormatException);
    });
  });
}
