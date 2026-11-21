import '../elements/drawing_element.dart';

class DrawDocument {
  DrawDocument({
    List<DrawingElement> elements = const [],
    Map<String, Object?> extraData = const {},
  })  : elements = List.unmodifiable(elements),
        extraData = Map.unmodifiable(extraData);

  final List<DrawingElement> elements;

  /// Unknown document-level fields retained when loading and saving a file.
  final Map<String, Object?> extraData;

  DrawDocument addElement(DrawingElement element) =>
      DrawDocument(elements: [...elements, element], extraData: extraData);

  DrawDocument removeElements(Set<String> ids) => DrawDocument(
        elements: elements.where((element) => !ids.contains(element.id)).toList(),
        extraData: extraData,
      );

  DrawDocument replaceElement(DrawingElement element) => DrawDocument(
        elements: [
          for (final current in elements)
            if (current.id == element.id) element else current,
        ],
        extraData: extraData,
      );

  DrawDocument reorder(Set<String> ids, {required bool toFront}) {
    final moving = elements.where((e) => ids.contains(e.id)).toList();
    final remaining = elements.where((e) => !ids.contains(e.id)).toList();
    return DrawDocument(
      elements: toFront ? [...remaining, ...moving] : [...moving, ...remaining],
      extraData: extraData,
    );
  }
}
