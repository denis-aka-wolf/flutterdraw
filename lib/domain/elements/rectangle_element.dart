import '../../core/geometry/viewport_transform.dart';

/// Rectangle geometry and appearance stored in document/world coordinates.
class RectangleElement {
  const RectangleElement({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.seed,
    this.strokeColor = 0xFF252525,
    this.strokeWidth = 2,
    this.roughness = 1,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final int seed;
  final int strokeColor;
  final double strokeWidth;
  final double roughness;

  Point2 get topLeft => Point2(x, y);
  Point2 get bottomRight => Point2(x + width, y + height);

  bool get isLargeEnough => width >= 2 && height >= 2;

  factory RectangleElement.fromPoints({
    required String id,
    required Point2 start,
    required Point2 end,
    required int seed,
  }) {
    final left = start.x < end.x ? start.x : end.x;
    final top = start.y < end.y ? start.y : end.y;
    final right = start.x > end.x ? start.x : end.x;
    final bottom = start.y > end.y ? start.y : end.y;

    return RectangleElement(
      id: id,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
      seed: seed,
    );
  }

  RectangleElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? seed,
    int? strokeColor,
    double? strokeWidth,
    double? roughness,
  }) {
    return RectangleElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      seed: seed ?? this.seed,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      roughness: roughness ?? this.roughness,
    );
  }
}
