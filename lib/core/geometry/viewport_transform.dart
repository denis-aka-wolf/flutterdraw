/// A two-dimensional point used by the canvas geometry layer.
///
/// This type deliberately has no Flutter dependency so it can be reused by
/// serialization, geometry, and rendering code.
class Point2 {
  const Point2(this.x, this.y);

  final double x;
  final double y;

  Point2 operator +(Point2 other) => Point2(x + other.x, y + other.y);

  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);

  Point2 operator *(double factor) => Point2(x * factor, y * factor);

  @override
  bool operator ==(Object other) =>
      other is Point2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point2($x, $y)';
}

/// Immutable mapping between document (world) coordinates and screen pixels.
class ViewportTransform {
  const ViewportTransform({
    this.scale = 1,
    this.translation = const Point2(0, 0),
  })  : assert(scale > 0),
        assert(scale.isFinite);

  static const double minScale = 0.1;
  static const double maxScale = 8;

  final double scale;

  /// Screen-space location of the world origin.
  final Point2 translation;

  Point2 worldToScreen(Point2 world) {
    return Point2(
      world.x * scale + translation.x,
      world.y * scale + translation.y,
    );
  }

  Point2 screenToWorld(Point2 screen) {
    return Point2(
      (screen.x - translation.x) / scale,
      (screen.y - translation.y) / scale,
    );
  }

  ViewportTransform panBy(Point2 screenDelta) {
    return ViewportTransform(
      scale: scale,
      translation: translation + screenDelta,
    );
  }

  /// Changes zoom while keeping the world point under [screenAnchor] fixed.
  ViewportTransform zoomAt({
    required Point2 screenAnchor,
    required double scaleFactor,
  }) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      return this;
    }

    final nextScale =
        (scale * scaleFactor).clamp(minScale, maxScale).toDouble();
    if (nextScale == scale) {
      return this;
    }

    final worldAnchor = screenToWorld(screenAnchor);
    return ViewportTransform(
      scale: nextScale,
      translation: Point2(
        screenAnchor.x - worldAnchor.x * nextScale,
        screenAnchor.y - worldAnchor.y * nextScale,
      ),
    );
  }
}
