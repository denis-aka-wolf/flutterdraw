import '../elements/rectangle_element.dart';

/// Immutable snapshot of the objects that make up a drawing.
class DrawDocument {
  DrawDocument({List<RectangleElement> rectangles = const []})
      : rectangles = List.unmodifiable(rectangles);

  final List<RectangleElement> rectangles;

  DrawDocument addRectangle(RectangleElement rectangle) {
    return DrawDocument(rectangles: [...rectangles, rectangle]);
  }

  DrawDocument removeElement(String id) {
    return DrawDocument(
      rectangles: rectangles.where((element) => element.id != id).toList(),
    );
  }

  DrawDocument replaceRectangle(RectangleElement rectangle) {
    return DrawDocument(
      rectangles: [
        for (final current in rectangles)
          if (current.id == rectangle.id) rectangle else current,
      ],
    );
  }
}
