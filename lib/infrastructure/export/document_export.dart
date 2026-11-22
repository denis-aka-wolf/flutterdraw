import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      left = math.min(left, element.left);
      top = math.min(top, element.top);
      right = math.max(right, element.right);
      bottom = math.max(bottom, element.bottom);
      for (final point in element.points) {
        left = math.min(left, point.x);
        top = math.min(top, point.y);
        right = math.max(right, point.x);
        bottom = math.max(bottom, point.y);
      }
    }
    final stroke = document.elements.fold<double>(
      1, (value, element) => math.max(value, element.strokeWidth),
    );
    return Rect.fromLTRB(left, top, right, bottom).inflate(stroke + padding);
  }

  static Future<Uint8List> png(DrawDocument document, {double pixelRatio = 2}) async {
    final area = bounds(document);
    final width = math.max(1, (area.width * pixelRatio).ceil());
    final height = math.max(1, (area.height * pixelRatio).ceil());
    if (width > 16000 || height > 16000 || width * height > 100000000) {
      throw const FormatException('Изображение слишком большое для экспорта.');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.translate(-area.left, -area.top);
    for (final element in document.elements) {
      _paintElement(canvas, element);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Не удалось сформировать PNG.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static String svg(DrawDocument document) {
    final area = bounds(document);
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" width="${area.width}" height="${area.height}" viewBox="${area.left} ${area.top} ${area.width} ${area.height}">',
    );
    for (final e in document.elements) {
      final stroke = _hex(e.strokeColor);
      final fill = e.fillColor == 0 ? 'none' : _hex(e.fillColor);
      final common = 'stroke="$stroke" stroke-width="${e.strokeWidth}" stroke-linecap="round" stroke-linejoin="round" opacity="${e.opacity}"';
      switch (e.type) {
        case DrawingElementType.rectangle:
          out.write('<rect x="${e.left}" y="${e.top}" width="${e.width.abs()}" height="${e.height.abs()}" fill="$fill" $common/>');
        case DrawingElementType.ellipse:
          out.write('<ellipse cx="${(e.left + e.right) / 2}" cy="${(e.top + e.bottom) / 2}" rx="${e.width.abs() / 2}" ry="${e.height.abs() / 2}" fill="$fill" $common/>');
        case DrawingElementType.diamond:
          out.write('<path d="M ${(e.left + e.right) / 2} ${e.top} L ${e.right} ${(e.top + e.bottom) / 2} L ${(e.left + e.right) / 2} ${e.bottom} L ${e.left} ${(e.top + e.bottom) / 2} Z" fill="$fill" $common/>');
        case DrawingElementType.line:
        case DrawingElementType.arrow:
        case DrawingElementType.freehand:
          if (e.points.isNotEmpty) {
            final d = e.points.asMap().entries.map((entry) =>
              '${entry.key == 0 ? 'M' : 'L'} ${entry.value.x} ${entry.value.y}').join(' ');
            out.write('<path d="$d" fill="none" $common/>');
            if (e.type == DrawingElementType.arrow && e.points.length >= 2) {
              final a = e.points[e.points.length - 2];
              final b = e.points.last;
              final angle = math.atan2(b.y - a.y, b.x - a.x);
              final length = math.max(10.0, e.strokeWidth * 4);
              final ax = b.x - length * math.cos(angle - math.pi / 6);
              final ay = b.y - length * math.sin(angle - math.pi / 6);
              final bx = b.x - length * math.cos(angle + math.pi / 6);
              final by = b.y - length * math.sin(angle + math.pi / 6);
              out.write('<path d="M $ax $ay L ${b.x} ${b.y} L $bx $by" fill="none" $common/>');
            }
          }
        case DrawingElementType.text:
          final lines = e.text.split('\n');
          final anchor = e.textAlign == 'center' ? 'middle' : e.textAlign == 'right' ? 'end' : 'start';
          final x = e.textAlign == 'center' ? e.x + e.width / 2 : e.textAlign == 'right' ? e.x + e.width : e.x;
          out.write('<text x="$x" y="${e.y + e.fontSize}" fill="$stroke" font-family="${_xml(e.fontFamily)}" font-size="${e.fontSize}" text-anchor="$anchor" opacity="${e.opacity}">');
          for (var i = 0; i < lines.length; i++) {
            out.write('<tspan x="$x" dy="${i == 0 ? 0 : e.fontSize * 1.2}">${_xml(lines[i])}</tspan>');
          }
          out.write('</text>');
      }
    }
    out.write('</svg>');
    return out.toString();
  }

  static void _paintElement(Canvas canvas, DrawingElement e) {
    final stroke = Paint()
      ..color = Color(e.strokeColor).withValues(alpha: e.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = e.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (e.type == DrawingElementType.text) {
      final painter = TextPainter(
        text: TextSpan(text: e.text, style: TextStyle(
          color: Color(e.strokeColor).withValues(alpha: e.opacity),
          fontSize: e.fontSize, fontFamily: e.fontFamily, height: 1.2,
        )),
        textDirection: TextDirection.ltr,
        textAlign: e.textAlign == 'center' ? TextAlign.center :
          e.textAlign == 'right' ? TextAlign.right : TextAlign.left,
      )..layout(maxWidth: math.max(40, e.width));
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(e.x, e.y, e.width, e.height));
      painter.paint(canvas, Offset(e.x, e.y));
      canvas.restore();
      return;
    }
    if (e.type == DrawingElementType.line || e.type == DrawingElementType.arrow ||
        e.type == DrawingElementType.freehand) {
      if (e.points.isEmpty) return;
      final path = Path()..moveTo(e.points.first.x, e.points.first.y);
      for (final p in e.points.skip(1)) { path.lineTo(p.x, p.y); }
      canvas.drawPath(path, stroke);
      if (e.type == DrawingElementType.arrow && e.points.length >= 2) {
        final a = e.points[e.points.length - 2], b = e.points.last;
        final angle = math.atan2(b.y - a.y, b.x - a.x);
        final length = math.max(10.0, e.strokeWidth * 4);
        final head = Path()
          ..moveTo(b.x - length * math.cos(angle - math.pi / 6), b.y - length * math.sin(angle - math.pi / 6))
          ..lineTo(b.x, b.y)
          ..lineTo(b.x - length * math.cos(angle + math.pi / 6), b.y - length * math.sin(angle + math.pi / 6));
        canvas.drawPath(head, stroke);
      }
      return;
    }
    final rect = Rect.fromLTRB(e.left, e.top, e.right, e.bottom);
    final path = Path();
    switch (e.type) {
      case DrawingElementType.rectangle: path.addRect(rect);
      case DrawingElementType.ellipse: path.addOval(rect);
      case DrawingElementType.diamond:
        path.moveTo(rect.center.dx, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.center.dx, rect.bottom);
        path.lineTo(rect.left, rect.center.dy);
        path.close();
      default: return;
    }
    if (e.fillColor != 0) {
      canvas.drawPath(path, Paint()
        ..color = Color(e.fillColor).withValues(alpha: e.opacity)
        ..style = PaintingStyle.fill);
    }
    canvas.drawPath(path, stroke);
  }

  static String _hex(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  static String _xml(String value) => value
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
