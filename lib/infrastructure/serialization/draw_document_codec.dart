import 'dart:convert';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/elements/drawing_element.dart';

/// Versioned JSON codec for FlutterDraw's native document format.
class DrawDocumentCodec {
  const DrawDocumentCodec();

  static const int currentVersion = 1;
  static const String formatType = 'flutterdraw';

  String encode(DrawDocument document, {bool pretty = true}) {
    final data = <String, Object?>{
      ...document.extraData,
      'type': formatType,
      'version': currentVersion,
      'elements': document.elements.map(_encodeElement).toList(),
    };
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  DrawDocument decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Корень документа должен быть JSON-объектом.');
    }

    if (decoded['type'] != formatType) {
      throw const FormatException('Файл не является документом FlutterDraw.');
    }

    final version = _requiredInt(decoded, 'version');
    if (version > currentVersion) {
      throw FormatException(
        'Версия документа $version новее поддерживаемой $currentVersion.',
      );
    }
    if (version < 1) {
      throw FormatException('Неподдерживаемая версия документа: $version.');
    }

    final rawElements = decoded['elements'];
    if (rawElements is! List) {
      throw const FormatException('Поле elements должно быть массивом.');
    }

    final elements = <DrawingElement>[];
    for (var index = 0; index < rawElements.length; index++) {
      final raw = rawElements[index];
      if (raw is! Map<String, dynamic>) {
        throw FormatException('Элемент с индексом $index должен быть объектом.');
      }
      elements.add(_decodeElement(raw, index));
    }

    const knownKeys = {'type', 'version', 'elements'};
    return DrawDocument(
      elements: elements,
      extraData: {
        for (final entry in decoded.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Map<String, Object?> _encodeElement(DrawingElement element) {
    return {
      ...element.extraData,
      'id': element.id,
      'type': element.type.name,
      'x': element.x,
      'y': element.y,
      'width': element.width,
      'height': element.height,
      'seed': element.seed,
      'points': [
        for (final point in element.points) {'x': point.x, 'y': point.y},
      ],
      'strokeColor': element.strokeColor,
      'strokeWidth': element.strokeWidth,
      'roughness': element.roughness,
      if (element.type == DrawingElementType.text) 'text': element.text,
      if (element.type == DrawingElementType.text) 'fontSize': element.fontSize,
    };
  }

  DrawingElement _decodeElement(Map<String, dynamic> data, int index) {
    final typeName = data['type'];
    final DrawingElementType type;
    try {
      type = DrawingElementType.values.byName(typeName as String);
    } on Object {
      throw FormatException(
        'Неизвестный тип элемента в позиции $index: $typeName.',
      );
    }

    final rawPoints = data['points'];
    if (rawPoints is! List) {
      throw FormatException('Поле points элемента $index должно быть массивом.');
    }

    final points = <Point2>[];
    for (final rawPoint in rawPoints) {
      if (rawPoint is! Map<String, dynamic>) {
        throw FormatException('Некорректная точка элемента $index.');
      }
      points.add(Point2(
        _requiredDouble(rawPoint, 'x'),
        _requiredDouble(rawPoint, 'y'),
      ));
    }

    const knownKeys = {
      'id',
      'type',
      'x',
      'y',
      'width',
      'height',
      'seed',
      'points',
      'strokeColor',
      'strokeWidth',
      'roughness',
      'text',
      'fontSize',
    };

    return DrawingElement(
      id: _requiredString(data, 'id'),
      type: type,
      x: _requiredDouble(data, 'x'),
      y: _requiredDouble(data, 'y'),
      width: _requiredDouble(data, 'width'),
      height: _requiredDouble(data, 'height'),
      seed: _requiredInt(data, 'seed'),
      points: points,
      strokeColor: _optionalInt(data, 'strokeColor', 0xFF252525),
      strokeWidth: _optionalDouble(data, 'strokeWidth', 2),
      roughness: _optionalDouble(data, 'roughness', 1),
      text: data['text'] is String ? data['text'] as String : '',
      fontSize: _optionalDouble(data, 'fontSize', 24),
      extraData: {
        for (final entry in data.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Поле $key должно быть непустой строкой.');
    }
    return value;
  }

  int _requiredInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! int) {
      throw FormatException('Поле $key должно быть целым числом.');
    }
    return value;
  }

  double _requiredDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Поле $key должно быть конечным числом.');
    }
    return value.toDouble();
  }

  int _optionalInt(Map<String, dynamic> data, String key, int fallback) {
    final value = data[key];
    if (value == null) return fallback;
    if (value is! int) throw FormatException('Поле $key должно быть целым числом.');
    return value;
  }

  double _optionalDouble(
    Map<String, dynamic> data,
    String key,
    double fallback,
  ) {
    final value = data[key];
    if (value == null) return fallback;
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Поле $key должно быть конечным числом.');
    }
    return value.toDouble();
  }
}
