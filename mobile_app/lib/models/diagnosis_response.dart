import 'package:muzhir/core/utils/network_url_helper.dart';

/// Response payload for a scan diagnosis from the Muzhir API.
class DiagnosisResponse {
  const DiagnosisResponse({
    required this.scanId,
    required this.imageUrl,
    required this.diagnosis,
    required this.recommendation,
    this.latitude,
    this.longitude,
    this.cropType = '',
    this.scannedAt,
  });

  final String scanId;
  final String imageUrl;
  final DiagnosisSection diagnosis;
  final RecommendationSection recommendation;
  /// Saved capture coordinates from the API (diagnose response or scan detail).
  final double? latitude;
  final double? longitude;
  /// English crop label or id when provided (e.g. map markers).
  final String cropType;
  /// Scan creation time when the API provides it (e.g. map markers, scan detail).
  final DateTime? scannedAt;

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
      imageUrl: NetworkUrlHelper.normalizeRemoteUrl(
        _string(json['imageUrl'] ?? json['image_url']),
      ),
      diagnosis: DiagnosisSection.fromJson(diagnosisRaw),
      recommendation: RecommendationSection.fromJson(recommendationRaw),
      latitude: _optionalDouble(json['latitude'] ?? json['captureLatitude']),
      longitude: _optionalDouble(json['longitude'] ?? json['captureLongitude']),
      cropType: _string(json['cropType'] ?? json['crop_type']),
      scannedAt: _optionalDateTime(json['scannedAt'] ?? json['createdAt'] ?? json['created_at']),
    );
  }

  /// One row from `GET /api/v1/map-markers` ([MapMarkerItem]).
  factory DiagnosisResponse.fromMapMarkerJson(Map<String, dynamic> json) {
    final diseaseLabel = _string(json['diseaseName'] ?? json['label']);
    final isHealthy = json['isHealthy'] == true ||
        json['is_healthy'] == true ||
        _labelImpliesHealthy(diseaseLabel);

    return DiagnosisResponse(
      scanId: _string(json['scanId'] ?? json['scan_id']),
      imageUrl: '',
      diagnosis: DiagnosisSection(
        label: diseaseLabel.isEmpty ? '—' : diseaseLabel,
        confidence: _double(json['confidence']),
        isHealthy: isHealthy,
        labelAr: _optionalLabelAr(json['diseaseNameAr'] ?? json['disease_name_ar']),
      ),
      recommendation: const RecommendationSection(textAr: '', textEn: ''),
      latitude: _optionalDouble(json['latitude']),
      longitude: _optionalDouble(json['longitude']),
      cropType: _string(json['cropType'] ?? json['crop_type']),
      scannedAt: _optionalDateTime(json['createdAt'] ?? json['created_at'] ?? json['scannedAt']),
    );
  }

  /// Maps `GET /api/v1/scan/{scanId}` ([ScanModel]) JSON into this shape.
  ///
  /// The scan detail payload nests diagnosis under `diagnosis` and uses
  /// `treatmentText` / `treatmentTextAr` for recommendations.
  factory DiagnosisResponse.fromScanDetailJson(
    String scanId,
    Map<String, dynamic> json,
  ) {
    final image = json['image'];
    var imageUrl = '';
    if (image is Map) {
      imageUrl = _string(image['imageUrl'] ?? image['image_url']);
    }
    if (imageUrl.isEmpty) {
      imageUrl = _string(json['imageUrl'] ?? json['image_url']);
    }

    Map<String, dynamic> diseaseMap = {};
    Map<String, dynamic> recFromDiagnosis = {};
    var confidence = _double(
      json['confidence_score'],
    );

    final rawDiagnosis = json['diagnosis'];
    if (rawDiagnosis is Map) {
      final dm = Map<String, dynamic>.from(rawDiagnosis);
      confidence = _double(
        dm['confidence'] ?? dm['confidenceScore'] ?? confidence,
      );
      final d = dm['disease'];
      if (d is Map) {
        diseaseMap = Map<String, dynamic>.from(d);
      }
      final r = dm['recommendation'];
      if (r is Map) {
        recFromDiagnosis = Map<String, dynamic>.from(r);
      }
    }

    var label = _string(
      diseaseMap['diseaseName'] ?? json['diseaseName'] ?? json['label'],
    );
    if (label.isEmpty) {
      label = '—';
    }

    final labelAr = _optionalLabelAr(
      diseaseMap['diseaseNameAr'] ??
          diseaseMap['disease_name_ar'] ??
          json['diseaseNameAr'] ??
          json['disease_name_ar'],
    );

    final isHealthy = json['isHealthy'] == true ||
        json['is_healthy'] == true ||
        _labelImpliesHealthy(label);

    final topRec = json['recommendation'];
    Map<String, dynamic> recMap = recFromDiagnosis;
    if (recMap.isEmpty && topRec is Map) {
      recMap = Map<String, dynamic>.from(topRec);
    }

    final textEn = _string(
      recMap['text_en'] ??
          recMap['textEn'] ??
          recMap['treatmentText'] ??
          recMap['treatment_text'],
    );
    final textAr = _string(
      recMap['text_ar'] ??
          recMap['textAr'] ??
          recMap['treatmentTextAr'] ??
          recMap['treatment_text_ar'],
    );

    var cropType = '';
    final rawCrop = json['crop'];
    if (rawCrop is Map) {
      final cm = Map<String, dynamic>.from(rawCrop);
      cropType = _string(cm['cropName'] ?? cm['cropId']);
    }
    if (cropType.isEmpty) {
      cropType = _string(json['cropName'] ?? json['cropId']);
    }

    return DiagnosisResponse(
      scanId: scanId,
      imageUrl: NetworkUrlHelper.normalizeRemoteUrl(imageUrl),
      diagnosis: DiagnosisSection(
        label: label,
        confidence: confidence.clamp(0.0, 1.0),
        isHealthy: isHealthy,
        labelAr: labelAr,
      ),
      recommendation: RecommendationSection(textAr: textAr, textEn: textEn),
      latitude: _optionalDouble(json['latitude'] ?? json['captureLatitude']),
      longitude: _optionalDouble(json['longitude'] ?? json['captureLongitude']),
      cropType: cropType,
      scannedAt: _optionalDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['scannedAt'],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'scanId': scanId,
        'imageUrl': imageUrl,
        'diagnosis': diagnosis.toMap(),
        'recommendation': recommendation.toMap(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (cropType.isNotEmpty) 'cropType': cropType,
        if (scannedAt != null) 'scannedAt': scannedAt!.toIso8601String(),
      };
}

/// `diagnosis` object: label, confidence, and health flag.
class DiagnosisSection {
  const DiagnosisSection({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    this.labelAr,
  });

  final String label;
  final double confidence;
  final bool isHealthy;

  /// Arabic disease name when the API provides it (e.g. class map or scan detail).
  final String? labelAr;

  factory DiagnosisSection.fromJson(Map<String, dynamic> json) {
    return DiagnosisSection(
      label: _string(json['label']),
      confidence: _double(json['confidence']),
      isHealthy: json['is_healthy'] == true || json['isHealthy'] == true,
      labelAr: _optionalLabelAr(json['labelAr'] ?? json['label_ar']),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'confidence': confidence,
        'is_healthy': isHealthy,
        if (labelAr != null) 'labelAr': labelAr,
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

String? _optionalLabelAr(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }
  return null;
}

bool _labelImpliesHealthy(String label) {
  final l = label.toLowerCase();
  return l.contains('no disease') || l.contains('healthy');
}
