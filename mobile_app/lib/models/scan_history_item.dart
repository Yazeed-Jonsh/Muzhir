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

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      scanId: _string(json['scanId'] ?? json['scan_id']),
      cropName: _string(json['cropName'] ?? json['crop_name']),
      cropNameAr: _string(json['cropNameAr'] ?? json['crop_name_ar']),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      status: _string(json['status']),
      severity: _optionalString(json['severity']),
      imageUrl: _string(json['imageUrl'] ?? json['image_url']),
      diseaseName: _optionalString(
        json['diseaseName'] ?? json['disease_name'] ?? json['label'],
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

DateTime _parseDateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
}
