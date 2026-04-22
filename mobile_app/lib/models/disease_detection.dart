import 'dart:ui';

/// A single on-device detection returned by the YOLO26n inference engine.
class DiseaseDetection {
  const DiseaseDetection({
    required this.classId,
    required this.labelEn,
    required this.labelAr,
    required this.confidence,
    required this.boundingBox,
  });

  /// Index 0–7 matching class_map.json.
  final int classId;

  /// English disease label (e.g. "Corn Blight").
  final String labelEn;

  /// Arabic disease label (e.g. "لفحة الذرة").
  final String labelAr;

  /// Confidence score in [0, 1].
  final double confidence;

  /// Bounding box in normalised coordinates [0, 1] relative to the original
  /// image dimensions, expressed as (left, top, right, bottom).
  final Rect boundingBox;

  /// All eight `class_map.json` entries are disease classes; use "no
  /// detections" in the UI for a healthy-looking plant.
  bool get isHealthy => false;

  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  @override
  String toString() =>
      'DiseaseDetection(classId: $classId, label: $labelEn, '
      'conf: $confidencePercent%, box: $boundingBox)';
}
