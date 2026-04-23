import 'package:muzhir/core/utils/network_url_helper.dart';

/// One row from `GET /api/v1/history` ([ScanSummary] on the backend).
class ScanHistoryItem {
  const ScanHistoryItem({
    required this.scanId,
    required this.cropName,
    required this.cropNameAr,
    required this.createdAt,
    required this.status,
    this.severity,
    required this.imageUrl,
    this.diseaseName,
    this.diseaseNameAr,
    this.isHealthy = false,
    this.confidence,
  });

  final String scanId;
  final String cropName;
  final String cropNameAr;
  final DateTime createdAt;
  final String status;
  final String? severity;
  final String imageUrl;

  /// Diagnosis label (English); mirrors backend `diseaseName` / Firestore diagnosis.
  final String? diseaseName;
  final String? diseaseNameAr;

  /// From API `isHealthy` — matches backend / map-marker health logic.
  final bool isHealthy;

  /// Model confidence in \[0, 1\] from API `confidence` / `confidenceScore`; null if unknown or pending.
  final double? confidence;

  /// Whole percent for UI (e.g. 0.854 → 85); null when [confidence] is null.
  int? get confidencePercentDisplay {
    final c = confidence;
    if (c == null) return null;
    return (c * 100).round().clamp(0, 100);
  }

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      scanId: _string(json['scanId'] ?? json['scan_id']),
      cropName: _string(json['cropName'] ?? json['crop_name']),
      cropNameAr: _string(json['cropNameAr'] ?? json['crop_name_ar']),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      status: _string(json['status']),
      severity: _optionalString(json['severity']),
      imageUrl: NetworkUrlHelper.normalizeRemoteUrl(
        _string(json['imageUrl'] ?? json['image_url']),
      ),
      diseaseName: _optionalString(
        json['diseaseName'] ??
            json['disease_name'] ??
            json['label'] ??
            json['textEn'] ??
            json['text_en'],
      ),
      diseaseNameAr: _optionalString(
        json['diseaseNameAr'] ??
            json['disease_name_ar'] ??
            json['label_ar'] ??
            json['textAr'] ??
            json['text_ar'],
      ),
      isHealthy: json['isHealthy'] == true || json['is_healthy'] == true,
      confidence: _optionalConfidence(
        json['confidence'] ?? json['confidenceScore'] ?? json['confidence_score'],
      ),
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

String? _optionalString(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

double? _optionalConfidence(Object? value) {
  if (value == null) return null;
  double v;
  if (value is num) {
    v = value.toDouble();
  } else {
    final parsed = double.tryParse(value.toString().trim());
    if (parsed == null) return null;
    v = parsed;
  }
  if (v > 1.0 && v <= 100.0) {
    v = v / 100.0;
  }
  if (v < 0.0 || v > 1.0) return null;
  return v;
}

DateTime _parseDateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
}
