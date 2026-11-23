import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/document/draw_document.dart';
import 'package:flutterdraw/domain/elements/drawing_element.dart';
import 'package:flutterdraw/infrastructure/export/document_export.dart';

void main() {
  group('DocumentExport', () {
    test('calculates bounds from all elements, including negative coordinates',
        () {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'a',
          type: DrawingElementType.rectangle,
          x: -40,
          y: 20,
          width: 80,
          height: 30,
          seed: 1,
        ),
        DrawingElement(
          id: 'b',
          type: DrawingElementType.line,
          x: 300,
          y: -100,
          width: 60,
          height: 20,
          seed: 2,
          points: const [Point2(300, -100), Point2(360, -80)],
        ),
      ]);

      final bounds = DocumentExport.bounds(document);

      expect(bounds.left, lessThan(-40));
      expect(bounds.top, lessThan(-100));
      expect(bounds.right, greaterThan(360));
      expect(bounds.bottom, greaterThan(50));
    });

    test('returns a valid minimal canvas for an empty document', () {
      expect(DocumentExport.bounds(DrawDocument()),
          const Rect.fromLTWH(0, 0, 1, 1));
    });

    test('keeps only elements fully contained in the selected bounds', () {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'selected',
          type: DrawingElementType.rectangle,
          x: 10,
          y: 10,
          width: 80,
          height: 60,
          seed: 1,
        ),
        DrawingElement(
          id: 'inside',
          type: DrawingElementType.ellipse,
          x: 20,
          y: 20,
          width: 15,
          height: 15,
          seed: 2,
        ),
        DrawingElement(
          id: 'partial',
          type: DrawingElementType.rectangle,
          x: 85,
          y: 30,
          width: 20,
          height: 20,
          seed: 3,
        ),
        DrawingElement(
          id: 'outside',
          type: DrawingElementType.rectangle,
          x: 150,
          y: 150,
          width: 20,
          height: 20,
          seed: 4,
        ),
      ]);

      final cropped = DocumentExport.withinBounds(
        document,
        const Rect.fromLTWH(10, 10, 80, 60),
      );

      expect(cropped.elements.map((element) => element.id),
          ['selected', 'inside']);
    });

    test('exports a PNG image with a valid signature', () async {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'rect',
          type: DrawingElementType.rectangle,
          x: 0,
          y: 0,
          width: 40,
          height: 30,
          seed: 1,
        ),
      ]);

      final bytes = await DocumentExport.png(document, pixelRatio: 1);

      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('exports SVG geometry, styling and escaped text', () {
      final document = DrawDocument(elements: [
        DrawingElement(
          id: 'rect',
          type: DrawingElementType.rectangle,
          x: 10,
          y: 20,
          width: 100,
          height: 60,
          seed: 7,
          strokeColor: 0xFF123456,
          fillColor: 0xFFABCDEF,
          strokeWidth: 3,
          strokeOpacity: 0.25,
          fillOpacity: 0.75,
        ),
        DrawingElement(
          id: 'text',
          type: DrawingElementType.text,
          x: 20,
          y: 30,
          width: 200,
          height: 50,
          seed: 8,
          text: 'A < B & C',
          fontFamily: 'Georgia',
          fontSize: 24,
        ),
      ]);

      final svg = DocumentExport.svg(document);

      expect(svg, contains('<svg'));
      expect(svg, contains('<rect'));
      expect(svg, contains('fill="#abcdef"'));
      expect(svg, contains('stroke="#123456"'));
      expect(svg, contains('fill-opacity="0.75"'));
      expect(svg, contains('stroke-opacity="0.25"'));
      expect(svg, contains('A &lt; B &amp; C'));
      expect(svg, contains('font-family="Georgia"'));
      expect(svg, endsWith('</svg>'));
    });
  });
}
