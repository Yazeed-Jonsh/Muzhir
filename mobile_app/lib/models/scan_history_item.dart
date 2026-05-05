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
    final diagnosis = json['diagnosis'];
    final diagnosisMap = diagnosis is Map
        ? Map<String, dynamic>.from(diagnosis)
        : <String, dynamic>{};
    final disease = diagnosisMap['disease'];
    final diseaseMap = disease is Map
        ? Map<String, dynamic>.from(disease)
        : <String, dynamic>{};

    return ScanHistoryItem(
      scanId: _string(json['scanId']),
      cropName: _string(json['cropName']),
      cropNameAr: _string(json['cropNameAr']),
      createdAt: _parseDateTime(json['createdAt']),
      status: _string(json['status']),
      severity: _optionalString(json['severity']),
      imageUrl: NetworkUrlHelper.normalizeRemoteUrl(
        _string(json['imageUrl']),
      ),
      diseaseName: _optionalString(
        json['diseaseName'] ??
            json['disease_name'] ??
            json['label'] ??
            json['textEn'] ??
            json['text_en'] ??
            diagnosisMap['diseaseName'] ??
            diagnosisMap['disease_name'] ??
            diagnosisMap['label'] ??
            diagnosisMap['textEn'] ??
            diagnosisMap['text_en'] ??
            diseaseMap['diseaseName'] ??
            diseaseMap['disease_name'] ??
            diseaseMap['label'] ??
            diseaseMap['textEn'] ??
            diseaseMap['text_en'],
      ),
      diseaseNameAr: _optionalString(
        json['diseaseNameAr'] ??
            json['disease_name_ar'] ??
            json['labelAr'] ??
            json['label_ar'] ??
            json['textAr'] ??
            json['text_ar'] ??
            diagnosisMap['diseaseNameAr'] ??
            diagnosisMap['disease_name_ar'] ??
            diagnosisMap['labelAr'] ??
            diagnosisMap['label_ar'] ??
            diagnosisMap['textAr'] ??
            diagnosisMap['text_ar'] ??
            diseaseMap['diseaseNameAr'] ??
            diseaseMap['disease_name_ar'] ??
            diseaseMap['labelAr'] ??
            diseaseMap['label_ar'] ??
            diseaseMap['textAr'] ??
            diseaseMap['text_ar'],
      ),
      isHealthy: json['isHealthy'] == true,
      confidence: _optionalConfidence(
        json['confidence'],
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
