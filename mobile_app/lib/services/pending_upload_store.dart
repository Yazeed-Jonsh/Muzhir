import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// One offline scan queued for lazy upload to the backend.
class PendingUpload {
  const PendingUpload({
    required this.imagePath,
    required this.cropId,
    this.latitude,
    this.longitude,
    required this.capturedAt,
  });

  final String imagePath;
  final String cropId;
  final double? latitude;
  final double? longitude;
  final DateTime capturedAt;

  File get imageFile => File(imagePath);

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'cropId': cropId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
        imagePath: json['imagePath'] as String,
        cropId: json['cropId'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );
}

/// Persists two things across sessions:
/// 1. The last successful map-marker response (for offline display).
/// 2. A queue of offline scans awaiting upload.
class PendingUploadStore {
  static const _kMarkerCache = 'muzhir_map_markers_v1';
  static const _kQueue = 'muzhir_pending_uploads_v1';

  // ── Marker cache ─────────────────────────────────────────────────────────────

  static Future<void> saveMarkers(List<Map<String, dynamic>> markers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMarkerCache, jsonEncode(markers));
  }

  static Future<List<Map<String, dynamic>>> loadMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMarkerCache);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Pending upload queue ──────────────────────────────────────────────────────

  static Future<void> enqueue(PendingUpload upload) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueue) ?? '[]';
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.add(upload.toJson());
    await prefs.setString(_kQueue, jsonEncode(list));
  }

  static Future<List<PendingUpload>> loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueue);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              PendingUpload.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueue);
  }
}
