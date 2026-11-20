import '../elements/drawing_element.dart';

class DrawDocument {
  DrawDocument({List<DrawingElement> elements = const []})
      : elements = List.unmodifiable(elements);

  final List<DrawingElement> elements;

  DrawDocument addElement(DrawingElement element) =>
      DrawDocument(elements: [...elements, element]);

  DrawDocument removeElements(Set<String> ids) => DrawDocument(
        elements: elements.where((element) => !ids.contains(element.id)).toList(),
      );

  DrawDocument replaceElement(DrawingElement element) => DrawDocument(
        elements: [
          for (final current in elements)
            if (current.id == element.id) element else current,
        ],
      );

  DrawDocument reorder(Set<String> ids, {required bool toFront}) {
    final moving = elements.where((e) => ids.contains(e.id)).toList();
    final remaining = elements.where((e) => !ids.contains(e.id)).toList();
    return DrawDocument(
      elements: toFront ? [...remaining, ...moving] : [...moving, ...remaining],
    );
  }
}
