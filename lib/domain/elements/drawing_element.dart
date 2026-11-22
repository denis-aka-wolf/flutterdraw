import '../../core/geometry/viewport_transform.dart';

enum DrawingElementType {
  rectangle,
  ellipse,
  diamond,
  line,
  arrow,
  freehand,
  text,
  image,
}

enum StrokeAlignment { center, inside, outside }

class DrawingElement {
  DrawingElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.seed,
    List<Point2> points = const [],
    this.strokeColor = 0xFF252525,
    this.strokeWidth = 2,
    this.strokeAlignment = StrokeAlignment.center,
    this.roughness = 1,
    this.text = '',
    this.fontSize = 24,
    this.fontFamily = 'Roboto',
    this.textAlign = 'left',
    this.fillColor = 0x00000000,
    this.assetId,
    double opacity = 1,
    double? strokeOpacity,
    double? fillOpacity,
    Map<String, Object?> extraData = const {},
  })  : strokeOpacity = strokeOpacity ?? opacity,
        fillOpacity = fillOpacity ?? opacity,
        points = List.unmodifiable(points),
        extraData = Map.unmodifiable(extraData);

  final String id;
  final DrawingElementType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int seed;
  final List<Point2> points;
  final int strokeColor;
  final double strokeWidth;
  final StrokeAlignment strokeAlignment;
  final double roughness;
  final String text;
  final double fontSize;
  final String fontFamily;
  final String textAlign;
  final int fillColor;
  final String? assetId;
  final double strokeOpacity;
  final double fillOpacity;

  /// Legacy alias retained for callers that used the former shared opacity.
  double get opacity => strokeOpacity;

  /// Fields unknown to this version of FlutterDraw, retained for round trips.
  final Map<String, Object?> extraData;

  double get left => x < x + width ? x : x + width;
  double get top => y < y + height ? y : y + height;
  double get right => x > x + width ? x : x + width;
  double get bottom => y > y + height ? y : y + height;

  bool get isLargeEnough {
    switch (type) {
      case DrawingElementType.rectangle:
      case DrawingElementType.ellipse:
      case DrawingElementType.diamond:
      case DrawingElementType.image:
        return width.abs() >= 2 && height.abs() >= 2;
      case DrawingElementType.text:
        return text.trim().isNotEmpty;
      case DrawingElementType.line:
      case DrawingElementType.arrow:
      case DrawingElementType.freehand:
        return width.abs() >= 2 || height.abs() >= 2;
    }
  }

  factory DrawingElement.fromDrag({
    required String id,
    required DrawingElementType type,
    required Point2 start,
    required Point2 end,
    required int seed,
  }) {
    return DrawingElement(
      id: id,
      type: type,
      x: start.x,
      y: start.y,
      width: end.x - start.x,
      height: end.y - start.y,
      seed: seed,
      points:
          type == DrawingElementType.line || type == DrawingElementType.arrow
              ? [start, end]
              : const [],
    );
  }

  DrawingElement appendPoint(Point2 point) {
    final nextPoints = [...points, point];
    final xs = nextPoints.map((p) => p.x);
    final ys = nextPoints.map((p) => p.y);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    return copyWith(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
      points: nextPoints,
    );
  }

  DrawingElement translated(double dx, double dy, {String? newId}) {
    return copyWith(
      id: newId,
      x: x + dx,
      y: y + dy,
      points:
          points.map((point) => Point2(point.x + dx, point.y + dy)).toList(),
    );
  }

  DrawingElement copyWith({
    String? id,
    DrawingElementType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    int? seed,
    List<Point2>? points,
    int? strokeColor,
    double? strokeWidth,
    StrokeAlignment? strokeAlignment,
    double? roughness,
    String? text,
    double? fontSize,
    String? fontFamily,
    String? textAlign,
    int? fillColor,
    String? assetId,
    double? opacity,
    double? strokeOpacity,
    double? fillOpacity,
    Map<String, Object?>? extraData,
  }) {
    return DrawingElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      seed: seed ?? this.seed,
      points: points ?? this.points,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeAlignment: strokeAlignment ?? this.strokeAlignment,
      roughness: roughness ?? this.roughness,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      fillColor: fillColor ?? this.fillColor,
      assetId: assetId ?? this.assetId,
      strokeOpacity: strokeOpacity ?? opacity ?? this.strokeOpacity,
      fillOpacity: fillOpacity ?? opacity ?? this.fillOpacity,
      extraData: extraData ?? this.extraData,
    );
  }
}
