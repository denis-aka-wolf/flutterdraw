import '../elements/drawing_element.dart';
import 'document_asset.dart';

class DrawDocument {
  DrawDocument({
    List<DrawingElement> elements = const [],
    Map<String, DocumentAsset> assets = const {},
    Map<String, Object?> extraData = const {},
  })  : elements = List.unmodifiable(elements),
        assets = Map.unmodifiable(assets),
        extraData = Map.unmodifiable(extraData);

  final List<DrawingElement> elements;
  final Map<String, DocumentAsset> assets;

  /// Unknown document-level fields retained when loading and saving a file.
  final Map<String, Object?> extraData;

  DrawDocument addElement(DrawingElement element) =>
      DrawDocument(elements: [...elements, element], assets: assets, extraData: extraData);

  DrawDocument removeElements(Set<String> ids) => DrawDocument(
        elements: elements.where((element) => !ids.contains(element.id)).toList(),
        assets: assets,
        extraData: extraData,
      );

  DrawDocument replaceElement(DrawingElement element) => DrawDocument(
        elements: [
          for (final current in elements)
            if (current.id == element.id) element else current,
        ],
        assets: assets,
        extraData: extraData,
      );

  DrawDocument reorder(Set<String> ids, {required bool toFront}) {
    final moving = elements.where((e) => ids.contains(e.id)).toList();
    final remaining = elements.where((e) => !ids.contains(e.id)).toList();
    return DrawDocument(
      elements: toFront ? [...remaining, ...moving] : [...moving, ...remaining],
      assets: assets,
      extraData: extraData,
    );
  }
}
