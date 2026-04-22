import 'dart:convert';

import 'package:flutter/services.dart';

/// Bilingual label entry from class_map.json.
class LabelEntry {
  const LabelEntry({required this.en, required this.ar});

  final String en;
  final String ar;
}

/// Singleton loader for the 8-class disease label map.
///
/// Reads `assets/models/class_map.json` once and caches the result for the
/// lifetime of the app. Safe to call concurrently — the first caller awaits
/// the load; all subsequent callers receive the cached map immediately.
class LabelLoader {
  LabelLoader._();

  static Map<int, LabelEntry>? _cache;
  static Future<Map<int, LabelEntry>>? _pending;

  /// Returns the label map, loading it on first call.
  static Future<Map<int, LabelEntry>> load() {
    if (_cache != null) return Future.value(_cache);
    _pending ??= _load().then((m) {
      _cache = m;
      _pending = null;
      return m;
    });
    return _pending!;
  }

  static Future<Map<int, LabelEntry>> _load() async {
    final jsonStr =
        await rootBundle.loadString('assets/models/class_map.json');
    final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
    return raw.map(
      (k, v) => MapEntry(
        int.parse(k),
        LabelEntry(
          en: (v as Map<String, dynamic>)['en'] as String,
          ar: v['ar'] as String,
        ),
      ),
    );
  }

  /// Clears the cache — useful in tests.
  static void clearCache() {
    _cache = null;
    _pending = null;
  }
}
