import 'dart:typed_data';

import 'document_file_writer_io.dart'
    if (dart.library.html) 'document_file_writer_web.dart' as implementation;

Future<void> writeDocumentFile(String path, Uint8List bytes) =>
    implementation.writeDocumentFile(path, bytes);
