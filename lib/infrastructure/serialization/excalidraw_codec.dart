import 'dart:convert';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/elements/drawing_element.dart';

/// Excalidraw JSON codec. Unknown fields and unsupported elements are retained.
class ExcalidrawCodec {
  const ExcalidrawCodec();

  static const _metadataKey = 'flutterdrawExcalidrawMetadata';
  static const _originalKey = 'flutterdrawExcalidrawOriginal';
  static const _unsupportedKey = 'flutterdrawExcalidrawUnsupported';

  DrawDocument decode(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['type'] != 'excalidraw') {
      throw const FormatException('Файл не является документом Excalidraw.');
    }
    final rawElements = decoded['elements'];
    if (rawElements is! List) {
      throw const FormatException('В Excalidraw поле elements должно быть массивом.');
    }
    final elements = <DrawingElement>[];
    final unsupported = <Object?>[];
    for (var i = 0; i < rawElements.length; i++) {
      final item = rawElements[i];
      if (item is! Map || item['isDeleted'] == true) continue;
      final raw = Map<String, Object?>.from(item);
      final element = _decodeElement(raw, i);
      if (element == null) { unsupported.add(raw); } else { elements.add(element); }
    }
    final metadata = <String, Object?>{
      for (final entry in decoded.entries)
        if (!const {'type', 'version', 'elements'}.contains(entry.key))
          entry.key: entry.value,
    };
    return DrawDocument(elements: elements, extraData: {
      _metadataKey: metadata,
      if (unsupported.isNotEmpty) _unsupportedKey: unsupported,
    });
  }

  String encode(DrawDocument document, {bool pretty = true}) {
    final metadataValue = document.extraData[_metadataKey];
    final metadata = metadataValue is Map
        ? Map<String, Object?>.from(metadataValue) : <String, Object?>{};
    final elements = <Object?>[
      for (final element in document.elements) _encodeElement(element),
      if (document.extraData[_unsupportedKey] is List)
        ...(document.extraData[_unsupportedKey] as List),
    ];
    final result = <String, Object?>{
      ...metadata,
      'type': 'excalidraw',
      'version': 2,
      'source': metadata['source'] ?? 'https://github.com/denis-aka-wolf/flutterdraw',
      'elements': elements,
      'appState': metadata['appState'] ?? {'viewBackgroundColor': '#ffffff'},
      'files': metadata['files'] ?? <String, Object?>{},
    };
    return pretty ? const JsonEncoder.withIndent('  ').convert(result) : jsonEncode(result);
  }

  DrawingElement? _decodeElement(Map<String, Object?> raw, int index) {
    final type = switch (raw['type']) {
      'rectangle' => DrawingElementType.rectangle,
      'ellipse' => DrawingElementType.ellipse,
      'diamond' => DrawingElementType.diamond,
      'line' => DrawingElementType.line,
      'arrow' => DrawingElementType.arrow,
      'freedraw' => DrawingElementType.freehand,
      'text' => DrawingElementType.text,
      _ => null,
    };
    if (type == null) return null;
    final x = _number(raw['x']);
    final y = _number(raw['y']);
    final width = _number(raw['width']);
    final height = _number(raw['height']);
    final points = <Point2>[];
    final rawPoints = raw['points'];
    if (rawPoints is List) {
      for (final point in rawPoints) {
        if (point is List && point.length >= 2) {
          points.add(Point2(x + _number(point[0]), y + _number(point[1])));
        }
      }
    }
    if ((type == DrawingElementType.line || type == DrawingElementType.arrow) && points.isEmpty) {
      points.addAll([Point2(x, y), Point2(x + width, y + height)]);
    }
    final groupIds = raw['groupIds'];
    final groupId = groupIds is List && groupIds.isNotEmpty ? groupIds.first : null;
    final extra = <String, Object?>{_originalKey: raw};
    if (groupId is String && groupId.isNotEmpty) extra['flutterdrawGroupId'] = groupId;
    return DrawingElement(
      id: raw['id'] is String ? raw['id']! as String : 'excalidraw-$index',
      type: type, x: x, y: y, width: width, height: height,
      seed: _integer(raw['seed'], index + 1), points: points,
      strokeColor: _parseColor(raw['strokeColor'], 0xFF252525),
      fillColor: _parseColor(raw['backgroundColor'], 0x00000000),
      strokeWidth: _number(raw['strokeWidth'], 2),
      strokeAlignment: StrokeAlignment.values.firstWhere(
        (value) => value.name == raw['flutterdrawStrokeAlignment'],
        orElse: () => StrokeAlignment.center,
      ),
      roughness: _number(raw['roughness'], 1),
      strokeOpacity: (_number(raw['flutterdrawStrokeOpacity'], _number(raw['opacity'], 100)) / 100).clamp(0.0, 1.0).toDouble(),
      fillOpacity: (_number(raw['flutterdrawFillOpacity'], _number(raw['opacity'], 100)) / 100).clamp(0.0, 1.0).toDouble(),
      text: raw['text'] is String ? raw['text']! as String : '',
      fontSize: _number(raw['fontSize'], 24),
      fontFamily: _fontFamily(raw['fontFamily']),
      textAlign: raw['textAlign'] is String ? raw['textAlign']! as String : 'left',
      extraData: extra,
    );
  }

  Map<String, Object?> _encodeElement(DrawingElement element) {
    final originalValue = element.extraData[_originalKey];
    final original = originalValue is Map
        ? Map<String, Object?>.from(originalValue) : <String, Object?>{};
    final groupId = element.extraData['flutterdrawGroupId'];
    final result = <String, Object?>{
      ...original,
      'id': element.id,
      'type': _elementType(element.type),
      'x': element.x, 'y': element.y, 'width': element.width, 'height': element.height,
      'angle': original['angle'] ?? 0,
      'strokeColor': _color(element.strokeColor),
      'backgroundColor': element.fillColor == 0 ? 'transparent' : _color(element.fillColor),
      'fillStyle': 'solid',
      'strokeWidth': element.strokeWidth,
      'flutterdrawStrokeAlignment': element.strokeAlignment.name,
      'strokeStyle': original['strokeStyle'] ?? 'solid',
      'roughness': element.roughness,
      'opacity': 100,
      'flutterdrawStrokeOpacity': (element.strokeOpacity * 100).round(),
      'flutterdrawFillOpacity': (element.fillOpacity * 100).round(),
      'seed': element.seed,
      'version': original['version'] is int ? (original['version']! as int) + 1 : 1,
      'versionNonce': original['versionNonce'] ?? element.seed,
      'isDeleted': false,
      'updated': DateTime.now().millisecondsSinceEpoch,
    };
    if (element.type == DrawingElementType.line || element.type == DrawingElementType.arrow ||
        element.type == DrawingElementType.freehand) {
      result['points'] = element.points.map((p) => [p.x - element.x, p.y - element.y]).toList();
    } else if (element.type == DrawingElementType.text) {
      result['text'] = element.text;
      result['fontSize'] = element.fontSize;
      result['fontFamily'] = _fontFamilyNumber(element.fontFamily);
      result['textAlign'] = element.textAlign;
      result['verticalAlign'] = original['verticalAlign'] ?? 'top';
      result['baseline'] = original['baseline'] ?? element.fontSize;
    }
    if (groupId is String && groupId.isNotEmpty) {
      result['groupIds'] = [groupId];
    } else {
      result['groupIds'] = <String>[];
    }
    return result;
  }

  static String _elementType(DrawingElementType type) => switch (type) {
    DrawingElementType.rectangle => 'rectangle',
    DrawingElementType.ellipse => 'ellipse',
    DrawingElementType.diamond => 'diamond',
    DrawingElementType.line => 'line',
    DrawingElementType.arrow => 'arrow',
    DrawingElementType.freehand => 'freedraw',
    DrawingElementType.text => 'text',
  };
  static double _number(Object? value, [double fallback = 0]) =>
      value is num && value.isFinite ? value.toDouble() : fallback;
  static int _integer(Object? value, int fallback) => value is int ? value : fallback;
  static int _parseColor(Object? value, int fallback) {
    if (value is! String || value == 'transparent') return fallback;
    final hex = value.startsWith('#') ? value.substring(1) : value;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? fallback : 0xFF000000 | (parsed & 0xFFFFFF);
  }
  static String _color(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  static String _fontFamily(Object? value) => switch (value) {
    1 => 'Roboto', 2 => 'Arial', 3 => 'Courier New', _ => 'Roboto',
  };
  static int _fontFamilyNumber(String value) => switch (value) {
    'Arial' => 2, 'Courier New' => 3, _ => 1,
  };
}
