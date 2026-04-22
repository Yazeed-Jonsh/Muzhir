import 'dart:io';
import 'dart:typed_data';

/// Converts a [File] produced by [image_picker] into the raw bytes that
/// [ultralytics_yolo] `YOLO.predict()` expects.
///
/// The `ultralytics_yolo` native layer handles all further preprocessing
/// internally (resize to 640×640, normalisation, channel ordering, EXIF
/// orientation) so this class only needs to read the bytes.
///
/// If we ever switch to manual `tflite_flutter`, this is the single place
/// to add resize + normalisation + EXIF correction.
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
