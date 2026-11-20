import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/core/geometry/viewport_transform.dart';
import 'package:flutterdraw/domain/elements/rectangle_element.dart';

void main() {
  group('RectangleElement', () {
    test('normalizes points regardless of drag direction', () {
      final rectangle = RectangleElement.fromPoints(
        id: 'rect-1',
        start: const Point2(80, 60),
        end: const Point2(20, 10),
        seed: 42,
      );

      expect(rectangle.x, 20);
      expect(rectangle.y, 10);
      expect(rectangle.width, 60);
      expect(rectangle.height, 50);
    });

    test('keeps identity and style when copied', () {
      const rectangle = RectangleElement(
        id: 'rect-1',
        x: 10,
        y: 20,
        width: 30,
        height: 40,
        seed: 7,
      );

      final moved = rectangle.copyWith(x: 50, y: 60);

      expect(moved.id, rectangle.id);
      expect(moved.seed, rectangle.seed);
      expect(moved.x, 50);
      expect(moved.y, 60);
    });
  });
}
