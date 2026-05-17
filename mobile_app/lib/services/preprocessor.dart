import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

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
    final original = await imageFile.readAsBytes();
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;

    // Normalize orientation from EXIF so model input matches what users see.
    final oriented = img.bakeOrientation(decoded);
    // Keep offline path deterministic and aligned with backend preprocessing.
    final resized = img.copyResize(
      oriented,
      width: 640,
      height: 640,
      interpolation: img.Interpolation.linear,
    );
    final encoded = img.encodeJpg(resized, quality: 95);
    return Uint8List.fromList(encoded);
  }
}
