import 'dart:ui';

import 'package:muzhir/models/disease_detection.dart';
import 'package:muzhir/services/label_loader.dart';

/// Converts the raw `'boxes'` list from `YOLO.predict()` into a sorted,
/// filtered [List<DiseaseDetection>].
///
/// The YOLO26n NMS-free E2E head already applies NMS internally, so this
/// class only needs to:
///   1. Apply a confidence threshold to drop low-quality detections.
///   2. Map the class id/name to bilingual labels via [LabelLoader].
///   3. Convert the raw bounding-box map into a [Rect] with normalised coords.
///   4. Sort results by descending confidence.
class OutputMapper {
  OutputMapper._();

  /// Detections below this threshold are discarded.
  ///
  /// Keep this aligned with [InferenceService]'s native confidence threshold:
  /// lowering both improves recall while testing real diseased plant images.
  static const double confidenceThreshold = 0.25;

  /// Maps the raw detect output to [DiseaseDetection] objects.
  ///
  /// [rawBoxes]  — `results['boxes']` from `YOLO.predict()`.
  /// [labels]    — label map from [LabelLoader.load()].
  static List<DiseaseDetection> map(
    List<dynamic> rawBoxes,
    Map<int, LabelEntry> labels,
  ) {
    final results = <DiseaseDetection>[];

    final labelsByName = {
      for (final entry in labels.entries)
        _normalizeLabel(entry.value.en): entry,
    };

    for (final raw in rawBoxes) {
      if (raw is! Map) continue;
      final box = Map<dynamic, dynamic>.from(raw);
      final confidence = _readDouble(box['confidence']);
      if (confidence == null) continue;
      if (confidence < confidenceThreshold) continue;

      final labelEntry = _resolveLabel(box, labels, labelsByName);
      if (labelEntry == null) continue;
      final classId = labelEntry.key;
      final label = labelEntry.value;

      final bounds = _readNormalizedRect(box);
      if (bounds == null) continue;

      results.add(
        DiseaseDetection(
          classId: classId,
          labelEn: label.en,
          labelAr: label.ar,
          confidence: confidence,
          boundingBox: bounds,
        ),
      );
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  static MapEntry<int, LabelEntry>? _resolveLabel(
    Map<dynamic, dynamic> box,
    Map<int, LabelEntry> labels,
    Map<String, MapEntry<int, LabelEntry>> labelsByName,
  ) {
    final classId = _readInt(box['classIndex']) ??
        _readInt(box['class']) ??
        _readInt(box['id']);
    if (classId != null && labels[classId] != null) {
      return MapEntry(classId, labels[classId]!);
    }

    final className =
        _readString(box['className']) ?? _readString(box['class']);
    if (className == null) return null;
    return labelsByName[_normalizeLabel(className)];
  }

  static Rect? _readNormalizedRect(Map<dynamic, dynamic> box) {
    final normalizedBox = box['normalizedBox'];
    if (normalizedBox is Map) {
      return _rectFromEdges(
        left: _readDouble(normalizedBox['left']),
        top: _readDouble(normalizedBox['top']),
        right: _readDouble(normalizedBox['right']),
        bottom: _readDouble(normalizedBox['bottom']),
      );
    }

    final boundingBox = box['boundingBox'];
    if (boundingBox is Map) {
      final left = _readDouble(boundingBox['left']);
      final top = _readDouble(boundingBox['top']);
      final width = _readDouble(boundingBox['width']);
      final height = _readDouble(boundingBox['height']);
      if (left != null && top != null && width != null && height != null) {
        return Rect.fromLTWH(
          left.clamp(0.0, 1.0),
          top.clamp(0.0, 1.0),
          width.clamp(0.0, 1.0),
          height.clamp(0.0, 1.0),
        );
      }
      return _rectFromEdges(
        left: left,
        top: top,
        right: _readDouble(boundingBox['right']),
        bottom: _readDouble(boundingBox['bottom']),
      );
    }

    return _rectFromEdges(
      left: _readDouble(box['x1_norm']),
      top: _readDouble(box['y1_norm']),
      right: _readDouble(box['x2_norm']),
      bottom: _readDouble(box['y2_norm']),
    );
  }

  static Rect? _rectFromEdges({
    required double? left,
    required double? top,
    required double? right,
    required double? bottom,
  }) {
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    final l = left.clamp(0.0, 1.0);
    final t = top.clamp(0.0, 1.0);
    final r = right.clamp(0.0, 1.0);
    final b = bottom.clamp(0.0, 1.0);
    return Rect.fromLTWH(
        l, t, (r - l).clamp(0.0, 1.0), (b - t).clamp(0.0, 1.0));
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String? _readString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _normalizeLabel(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
  }
}
