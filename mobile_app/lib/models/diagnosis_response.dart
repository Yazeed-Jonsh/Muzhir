/// Response payload for a scan diagnosis from the Muzhir API.
class DiagnosisResponse {
  const DiagnosisResponse({
    required this.scanId,
    required this.imageUrl,
    required this.diagnosis,
    required this.recommendation,
  });

  final String scanId;
  final String imageUrl;
  final DiagnosisSection diagnosis;
  final RecommendationSection recommendation;

  factory DiagnosisResponse.fromJson(Map<String, dynamic> json) {
    final diagnosisRaw = json['diagnosis'];
    final recommendationRaw = json['recommendation'];
    if (diagnosisRaw is! Map<String, dynamic>) {
      throw const FormatException(
        'DiagnosisResponse.fromJson: "diagnosis" must be a JSON object.',
      );
    }
    if (recommendationRaw is! Map<String, dynamic>) {
      throw const FormatException(
        'DiagnosisResponse.fromJson: "recommendation" must be a JSON object.',
      );
    }
    return DiagnosisResponse(
      scanId: _string(json['scanId'] ?? json['scan_id']),
      imageUrl: _string(json['imageUrl'] ?? json['image_url']),
      diagnosis: DiagnosisSection.fromJson(diagnosisRaw),
      recommendation: RecommendationSection.fromJson(recommendationRaw),
    );
  }

  Map<String, dynamic> toMap() => {
        'scanId': scanId,
        'imageUrl': imageUrl,
        'diagnosis': diagnosis.toMap(),
        'recommendation': recommendation.toMap(),
      };
}

/// `diagnosis` object: label, confidence, and health flag.
class DiagnosisSection {
  const DiagnosisSection({
    required this.label,
    required this.confidence,
    required this.isHealthy,
  });

  final String label;
  final double confidence;
  final bool isHealthy;

  factory DiagnosisSection.fromJson(Map<String, dynamic> json) {
    return DiagnosisSection(
      label: _string(json['label']),
      confidence: _double(json['confidence']),
      isHealthy: json['is_healthy'] == true || json['isHealthy'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'confidence': confidence,
        'is_healthy': isHealthy,
      };
}

/// `recommendation` object: Arabic and English copy.
class RecommendationSection {
  const RecommendationSection({
    required this.textAr,
    required this.textEn,
  });

  final String textAr;
  final String textEn;

  factory RecommendationSection.fromJson(Map<String, dynamic> json) {
    return RecommendationSection(
      textAr: _string(json['text_ar'] ?? json['textAr']),
      textEn: _string(json['text_en'] ?? json['textEn']),
    );
  }

  Map<String, dynamic> toMap() => {
        'text_ar': textAr,
        'text_en': textEn,
      };
}

String _string(Object? value) => value?.toString() ?? '';

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
