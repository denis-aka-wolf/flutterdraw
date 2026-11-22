import 'dart:typed_data';

Future<void> writeDocumentFile(String path, Uint8List bytes) async {
  throw UnsupportedError('Direct file overwrite is unavailable in the browser.');
}
