import 'dart:io';
import 'dart:typed_data';

/// Converts a [File] produced by [image_picker] into the raw bytes that
/// [ultralytics_yolo] `YOLO.predict()` expects.
///
/// The `ultralytics_yolo` native layer owns preprocessing: image decode,
/// orientation handling, letterbox resize, RGB normalisation, and tensor
/// preparation. This class intentionally performs file I/O only.
class Preprocessor {
  Preprocessor._();

  /// Returns the raw JPEG/PNG bytes of [imageFile].
  ///
  /// Throws a [FileSystemException] if the file does not exist or cannot
  /// be read.
  static Future<Uint8List> prepareImageBytes(File imageFile) async {
    if (!imageFile.existsSync()) {
      throw FileSystemException(
        'Image file not found',
        imageFile.path,
      );
    }
    return imageFile.readAsBytes();
  }
}
