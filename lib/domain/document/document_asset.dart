/// Binary resource embedded in a FlutterDraw document.
class DocumentAsset {
  DocumentAsset({
    required this.id,
    required this.mimeType,
    required List<int> bytes,
    this.name,
    Map<String, Object?> extraData = const {},
  })  : bytes = List.unmodifiable(bytes),
        extraData = Map.unmodifiable(extraData);

  final String id;
  final String mimeType;
  final List<int> bytes;
  final String? name;

  /// Unknown asset fields are retained for forward-compatible round trips.
  final Map<String, Object?> extraData;
}
