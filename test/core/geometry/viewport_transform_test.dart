import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';

void main() {
  group('ViewportTransform', () {
    test('converts points between world and screen coordinates', () {
      const transform = ViewportTransform(
        scale: 2,
        translation: Point2(100, 50),
      );

      const worldPoint = Point2(10, 20);
      final screenPoint = transform.worldToScreen(worldPoint);

      expect(screenPoint, const Point2(120, 90));
      expect(transform.screenToWorld(screenPoint), worldPoint);
    });

    test('panning changes screen translation without changing scale', () {
      const transform = ViewportTransform(
        scale: 1.5,
        translation: Point2(10, 20),
      );

      final moved = transform.panBy(const Point2(-5, 12));

      expect(moved.scale, 1.5);
      expect(moved.translation, const Point2(5, 32));
    });

    test('zoom keeps the world point under the cursor stationary', () {
      const transform = ViewportTransform(
        scale: 1,
        translation: Point2(30, 40),
      );
      const cursor = Point2(150, 100);
      final worldPointBefore = transform.screenToWorld(cursor);

      final zoomed = transform.zoomAt(
        screenAnchor: cursor,
        scaleFactor: 2,
      );

      final worldPointAfter = zoomed.screenToWorld(cursor);

      expect(worldPointAfter.x, closeTo(worldPointBefore.x, 0.000001));
      expect(worldPointAfter.y, closeTo(worldPointBefore.y, 0.000001));
      expect(zoomed.scale, 2);
    });

    test('clamps zoom to the configured limits', () {
      const transform = ViewportTransform();

      final zoomedIn = transform.zoomAt(
        screenAnchor: const Point2(0, 0),
        scaleFactor: 100,
      );
      final zoomedOut = transform.zoomAt(
        screenAnchor: const Point2(0, 0),
        scaleFactor: 0.0001,
      );

      expect(zoomedIn.scale, ViewportTransform.maxScale);
      expect(zoomedOut.scale, ViewportTransform.minScale);
    });

    test('ignores invalid zoom factors', () {
      const transform = ViewportTransform();

      expect(
        transform.zoomAt(
          screenAnchor: const Point2(10, 10),
          scaleFactor: double.nan,
        ),
        transform,
      );
      expect(
        transform.zoomAt(
          screenAnchor: const Point2(10, 10),
          scaleFactor: -1,
        ),
        transform,
      );
    });
  });
}
