import 'dart:convert';

import '../../core/geometry/viewport_transform.dart';
import '../../domain/document/draw_document.dart';
import '../../domain/document/document_asset.dart';
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
      'assets': {
        for (final entry in document.assets.entries)
          entry.key: {
            ...entry.value.extraData,
            'mimeType': entry.value.mimeType,
            'name': entry.value.name,
            'data': base64Encode(entry.value.bytes),
          },
      },
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

    final assets = <String, DocumentAsset>{};
    final rawAssets = decoded['assets'];
    if (rawAssets != null && rawAssets is! Map) {
      throw const FormatException('Поле assets должно быть JSON-объектом.');
    }
    if (rawAssets is Map) {
      for (final entry in rawAssets.entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException('Некорректная запись ресурса документа.');
        }
        final assetData = Map<String, dynamic>.from(entry.value as Map);
        final mimeType = assetData['mimeType'];
        final encodedBytes = assetData['data'];
        if (mimeType is! String || encodedBytes is! String) {
          throw FormatException('Ресурс ${entry.key} не содержит mimeType или data.');
        }
        final assetId = entry.key as String;
        assets[assetId] = DocumentAsset(
          id: assetId,
          mimeType: mimeType,
          name: assetData['name'] is String ? assetData['name'] as String : null,
          bytes: base64Decode(encodedBytes),
          extraData: {
            for (final field in assetData.entries)
              if (!const {'mimeType', 'name', 'data'}.contains(field.key))
                field.key: field.value,
          },
        );
      }
    }

    const knownKeys = {'type', 'version', 'elements', 'assets'};
    return DrawDocument(
      elements: elements,
      assets: assets,
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
      'strokeAlignment': element.strokeAlignment.name,
      'roughness': element.roughness,
      'strokeOpacity': element.strokeOpacity,
      'fillOpacity': element.fillOpacity,
      'fillColor': element.fillColor,
      if (element.assetId != null) 'assetId': element.assetId,
      if (element.type == DrawingElementType.text) 'fontFamily': element.fontFamily,
      if (element.type == DrawingElementType.text) 'textAlign': element.textAlign,
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
      'strokeAlignment',
      'roughness',
      'opacity',
      'strokeOpacity',
      'fillOpacity',
      'fillColor',
      'assetId',
      'fontFamily',
      'textAlign',
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
      strokeAlignment: StrokeAlignment.values.firstWhere(
        (value) => value.name == data['strokeAlignment'],
        orElse: () => StrokeAlignment.center,
      ),
      roughness: _optionalDouble(data, 'roughness', 1),
      strokeOpacity: _optionalDouble(data, 'strokeOpacity', _optionalDouble(data, 'opacity', 1)).clamp(0.0, 1.0).toDouble(),
      fillOpacity: _optionalDouble(data, 'fillOpacity', _optionalDouble(data, 'opacity', 1)).clamp(0.0, 1.0).toDouble(),
      fillColor: _optionalInt(data, 'fillColor', 0x00000000),
      assetId: data['assetId'] is String ? data['assetId'] as String : null,
      fontFamily: data['fontFamily'] is String ? data['fontFamily'] as String : 'Roboto',
      textAlign: data['textAlign'] is String ? data['textAlign'] as String : 'left',
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
    if (value == null) {
      return fallback;
    }
    if (value is! int) {
      throw FormatException('Поле $key должно быть целым числом.');
    }
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
