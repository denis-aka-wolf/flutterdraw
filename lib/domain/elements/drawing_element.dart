import '../../core/geometry/viewport_transform.dart';

enum DrawingElementType {
  rectangle,
  ellipse,
  diamond,
  line,
  arrow,
  freehand,
}

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
    this.roughness = 1,
    Map<String, Object?> extraData = const {},
  })  : points = List.unmodifiable(points),
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
  final double roughness;

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
        return width.abs() >= 2 && height.abs() >= 2;
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
      points: type == DrawingElementType.line ||
              type == DrawingElementType.arrow
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
      points: points
          .map((point) => Point2(point.x + dx, point.y + dy))
          .toList(),
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
    double? roughness,
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
      roughness: roughness ?? this.roughness,
      extraData: extraData ?? this.extraData,
    );
  }
}
