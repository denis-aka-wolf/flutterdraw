import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../domain/document/draw_document.dart';
import '../../domain/elements/drawing_element.dart';

class DocumentExport {
  const DocumentExport._();

  static const double padding = 24;

  static Rect bounds(DrawDocument document) {
    if (document.elements.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final element in document.elements) {
      left = math.min(left, element.left).toDouble();
      top = math.min(top, element.top).toDouble();
      right = math.max(right, element.right).toDouble();
      bottom = math.max(bottom, element.bottom).toDouble();
      for (final point in element.points) {
        left = math.min(left, point.x).toDouble();
        top = math.min(top, point.y).toDouble();
        right = math.max(right, point.x).toDouble();
        bottom = math.max(bottom, point.y).toDouble();
      }
    }
    final stroke = document.elements.fold<double>(
      1,
      (value, element) => math.max(value, element.strokeWidth).toDouble(),
    );
    return Rect.fromLTRB(left, top, right, bottom).inflate(stroke + padding);
  }

  static Future<Uint8List> png(DrawDocument document,
      {double pixelRatio = 2}) async {
    final area = bounds(document);
    final width = math.max(1, (area.width * pixelRatio).ceil()).toInt();
    final height = math.max(1, (area.height * pixelRatio).ceil()).toInt();
    if (width > 16000 || height > 16000 || width * height > 100000000) {
      throw const FormatException('Изображение слишком большое для экспорта.');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.translate(-area.left, -area.top);
    final decodedAssets = <String, ui.Image>{};
    ui.Picture? picture;
    ui.Image? renderedImage;
    try {
      for (final element in document.elements) {
        if (element.type != DrawingElementType.image ||
            element.assetId == null ||
            decodedAssets.containsKey(element.assetId)) {
          continue;
        }
        final asset = document.assets[element.assetId];
        if (asset == null) continue;
        final codec =
            await ui.instantiateImageCodec(Uint8List.fromList(asset.bytes));
        try {
          final frame = await codec.getNextFrame();
          decodedAssets[element.assetId!] = frame.image;
        } finally {
          codec.dispose();
        }
      }
      for (final element in document.elements) {
        _paintElement(
          canvas,
          element,
          image:
              element.assetId == null ? null : decodedAssets[element.assetId],
        );
      }
      picture = recorder.endRecording();
      renderedImage = await picture.toImage(width, height);
      final data =
          await renderedImage.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Не удалось сформировать PNG.');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      renderedImage?.dispose();
      picture?.dispose();
      for (final image in decodedAssets.values) {
        image.dispose();
      }
    }
  }

  static String svg(DrawDocument document) {
    final area = bounds(document);
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" width="${area.width}" height="${area.height}" viewBox="${area.left} ${area.top} ${area.width} ${area.height}">',
    );
    for (final e in document.elements) {
      final stroke = _hex(e.strokeColor);
      final fill = e.fillColor == 0 ? 'none' : _hex(e.fillColor);
      final common =
          'stroke="$stroke" stroke-width="${e.strokeWidth}" stroke-linecap="round" stroke-linejoin="round" stroke-opacity="${e.strokeOpacity}"';
      switch (e.type) {
        case DrawingElementType.rectangle:
          out.write(
              '<rect x="${e.left}" y="${e.top}" width="${e.width.abs()}" height="${e.height.abs()}" fill="$fill" fill-opacity="${e.fillOpacity}" $common/>');
        case DrawingElementType.ellipse:
          out.write(
              '<ellipse cx="${(e.left + e.right) / 2}" cy="${(e.top + e.bottom) / 2}" rx="${e.width.abs() / 2}" ry="${e.height.abs() / 2}" fill="$fill" fill-opacity="${e.fillOpacity}" $common/>');
        case DrawingElementType.diamond:
          out.write(
              '<path d="M ${(e.left + e.right) / 2} ${e.top} L ${e.right} ${(e.top + e.bottom) / 2} L ${(e.left + e.right) / 2} ${e.bottom} L ${e.left} ${(e.top + e.bottom) / 2} Z" fill="$fill" fill-opacity="${e.fillOpacity}" $common/>');
        case DrawingElementType.line:
        case DrawingElementType.arrow:
        case DrawingElementType.freehand:
          if (e.points.isNotEmpty) {
            final d = e.points
                .asMap()
                .entries
                .map((entry) =>
                    '${entry.key == 0 ? 'M' : 'L'} ${entry.value.x} ${entry.value.y}')
                .join(' ');
            out.write('<path d="$d" fill="none" $common/>');
            if (e.type == DrawingElementType.arrow && e.points.length >= 2) {
              final a = e.points[e.points.length - 2];
              final b = e.points.last;
              final angle = math.atan2(b.y - a.y, b.x - a.x);
              final length = math.max(10.0, e.strokeWidth * 4).toDouble();
              final ax = b.x - length * math.cos(angle - math.pi / 6);
              final ay = b.y - length * math.sin(angle - math.pi / 6);
              final bx = b.x - length * math.cos(angle + math.pi / 6);
              final by = b.y - length * math.sin(angle + math.pi / 6);
              out.write(
                  '<path d="M $ax $ay L ${b.x} ${b.y} L $bx $by" fill="none" $common/>');
            }
          }
        case DrawingElementType.image:
          final asset = e.assetId == null ? null : document.assets[e.assetId];
          if (asset != null) {
            final data = base64Encode(asset.bytes);
            out.write(
                '<image href="data:${asset.mimeType};base64,$data" x="${e.x}" y="${e.y}" width="${e.width}" height="${e.height}" opacity="${e.fillOpacity}"/>');
          }
        case DrawingElementType.text:
          final lines = e.text.split('\n');
          final anchor = e.textAlign == 'center'
              ? 'middle'
              : e.textAlign == 'right'
                  ? 'end'
                  : 'start';
          final x = e.textAlign == 'center'
              ? e.x + e.width / 2
              : e.textAlign == 'right'
                  ? e.x + e.width
                  : e.x;
          out.write(
              '<text x="$x" y="${e.y + e.fontSize}" fill="$stroke" font-family="${_xml(e.fontFamily)}" font-size="${e.fontSize}" text-anchor="$anchor" opacity="${e.strokeOpacity}">');
          for (var i = 0; i < lines.length; i++) {
            out.write(
                '<tspan x="$x" dy="${i == 0 ? 0 : e.fontSize * 1.2}">${_xml(lines[i])}</tspan>');
          }
          out.write('</text>');
      }
    }
    out.write('</svg>');
    return out.toString();
  }

  static void _paintElement(Canvas canvas, DrawingElement e,
      {ui.Image? image}) {
    if (e.type == DrawingElementType.image) {
      if (image != null) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(e.x, e.y, e.width, e.height),
          Paint()..color = Color(0xFFFFFFFF).withValues(alpha: e.fillOpacity),
        );
      }
      return;
    }
    final stroke = Paint()
      ..color = Color(e.strokeColor).withValues(alpha: e.strokeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = e.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (e.type == DrawingElementType.text) {
      final painter = TextPainter(
        text: TextSpan(
            text: e.text,
            style: TextStyle(
              color: Color(e.strokeColor).withValues(alpha: e.strokeOpacity),
              fontSize: e.fontSize,
              fontFamily: e.fontFamily,
              height: 1.2,
            )),
        textDirection: TextDirection.ltr,
        textAlign: e.textAlign == 'center'
            ? TextAlign.center
            : e.textAlign == 'right'
                ? TextAlign.right
                : TextAlign.left,
      )..layout(maxWidth: math.max(40.0, e.width));
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(e.x, e.y, e.width, e.height));
      painter.paint(canvas, Offset(e.x, e.y));
      canvas.restore();
      return;
    }
    if (e.type == DrawingElementType.line ||
        e.type == DrawingElementType.arrow ||
        e.type == DrawingElementType.freehand) {
      _paintStroke(canvas, e, stroke);
      return;
    }
    final rect = Rect.fromLTRB(e.left, e.top, e.right, e.bottom);
    final path = Path();
    switch (e.type) {
      case DrawingElementType.rectangle:
        _roughPolygon(
            path,
            [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft],
            e);
        path.close();
      case DrawingElementType.ellipse:
        _roughEllipse(path, rect, e);
      case DrawingElementType.diamond:
        _roughPolygon(
            path,
            [
              rect.topCenter,
              rect.centerRight,
              rect.bottomCenter,
              rect.centerLeft,
            ],
            e);
        path.close();
      default:
        return;
    }
    if (e.fillColor != 0) {
      canvas.drawPath(
          path,
          Paint()
            ..color = Color(e.fillColor).withValues(alpha: e.fillOpacity)
            ..style = PaintingStyle.fill);
    }
    canvas.drawPath(path, stroke);
  }

  static void _roughPolygon(Path path, List<Offset> corners, DrawingElement e) {
    final random = math.Random(e.seed);
    for (var side = 0; side < corners.length; side++) {
      final start = corners[side];
      final end = corners[(side + 1) % corners.length];
      if (side == 0) path.moveTo(start.dx, start.dy);
      const segments = 6;
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        var x = start.dx + (end.dx - start.dx) * t;
        var y = start.dy + (end.dy - start.dy) * t;
        if (i < segments && e.roughness > 0) {
          final jitter = (random.nextDouble() * 2 - 1) * e.roughness;
          final dx = end.dx - start.dx;
          final dy = end.dy - start.dy;
          final length = math.sqrt(dx * dx + dy * dy);
          if (length > 0) {
            x += -dy / length * jitter;
            y += dx / length * jitter;
          }
        }
        path.lineTo(x, y);
      }
    }
  }

  static void _roughEllipse(Path path, Rect rect, DrawingElement e) {
    final random = math.Random(e.seed);
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const count = 48;
    for (var i = 0; i <= count; i++) {
      final angle = math.pi * 2 * i / count;
      final jitter = (random.nextDouble() * 2 - 1) * e.roughness;
      final x = center.dx + (rx + jitter) * math.cos(angle);
      final y = center.dy + (ry + jitter) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
  }

  static void _paintStroke(Canvas canvas, DrawingElement e, Paint paint) {
    if (e.points.isEmpty) return;
    final path = Path();
    if ((e.type == DrawingElementType.line ||
            e.type == DrawingElementType.arrow) &&
        e.points.length == 2) {
      final start = e.points.first;
      final end = e.points.last;
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final length = math.sqrt(dx * dx + dy * dy);
      final random = math.Random(e.seed);
      const segments = 10;
      path.moveTo(start.x, start.y);
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        var x = start.x + dx * t;
        var y = start.y + dy * t;
        if (i < segments && length > 0 && e.roughness > 0) {
          final jitter = (random.nextDouble() * 2 - 1) * e.roughness;
          x += -dy / length * jitter;
          y += dx / length * jitter;
        }
        path.lineTo(x, y);
      }
    } else {
      path.moveTo(e.points.first.x, e.points.first.y);
      for (var i = 1; i < e.points.length; i++) {
        path.lineTo(e.points[i].x, e.points[i].y);
      }
    }
    canvas.drawPath(path, paint);
    if (e.type == DrawingElementType.arrow && e.points.length >= 2) {
      final start = e.points[e.points.length - 2];
      final end = e.points.last;
      final angle = math.atan2(end.y - start.y, end.x - start.x);
      final length = math.max(10.0, e.strokeWidth * 4).toDouble();
      final head = Path()
        ..moveTo(end.x - length * math.cos(angle - math.pi / 6),
            end.y - length * math.sin(angle - math.pi / 6))
        ..lineTo(end.x, end.y)
        ..lineTo(end.x - length * math.cos(angle + math.pi / 6),
            end.y - length * math.sin(angle + math.pi / 6));
      canvas.drawPath(head, paint);
    }
  }

  static String _hex(int color) =>
      '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
