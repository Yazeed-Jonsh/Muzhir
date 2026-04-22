import 'dart:ui';

import 'package:muzhir/models/disease_detection.dart';
import 'package:muzhir/services/label_loader.dart';

/// Converts the raw `'boxes'` list from `YOLO.predict()` into a sorted,
/// filtered [List<DiseaseDetection>].
///
/// The YOLO26n NMS-free E2E head already applies NMS internally, so this
/// class only needs to:
///   1. Apply a confidence threshold to drop low-quality detections.
///   2. Map the integer `classIndex` to bilingual labels via [LabelLoader].
///   3. Convert the raw bounding-box map into a [Rect] with normalised coords.
///   4. Sort results by descending confidence.
class OutputMapper {
  OutputMapper._();

  /// Detections below this threshold are discarded.
  /// Slightly higher than the YOLO default (0.25) to reduce false positives
  /// in a plant-disease context where precision matters more than recall.
  static const double confidenceThreshold = 0.50;

  /// Maps the raw detect output to [DiseaseDetection] objects.
  ///
  /// [rawBoxes]  — `results['boxes']` from `YOLO.predict()`.
  /// [labels]    — label map from [LabelLoader.load()].
  static List<DiseaseDetection> map(
    List<dynamic> rawBoxes,
    Map<int, LabelEntry> labels,
  ) {
    final results = <DiseaseDetection>[];

    for (final raw in rawBoxes) {
      final box = raw as Map<dynamic, dynamic>;
      final confidence = (box['confidence'] as num).toDouble();
      if (confidence < confidenceThreshold) continue;

      final classId = (box['classIndex'] as num).toInt();
      final label = labels[classId];
      if (label == null) continue;

      // boundingBox values are normalised to [0, 1] relative to the original
      // image width and height as returned by ultralytics_yolo.
      final bb = box['boundingBox'] as Map<dynamic, dynamic>;
      final left = (bb['left'] as num).toDouble().clamp(0.0, 1.0);
      final top = (bb['top'] as num).toDouble().clamp(0.0, 1.0);
      final width = (bb['width'] as num).toDouble().clamp(0.0, 1.0);
      final height = (bb['height'] as num).toDouble().clamp(0.0, 1.0);

      results.add(
        DiseaseDetection(
          classId: classId,
          labelEn: label.en,
          labelAr: label.ar,
          confidence: confidence,
          boundingBox: Rect.fromLTWH(left, top, width, height),
        ),
      );
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }
}
