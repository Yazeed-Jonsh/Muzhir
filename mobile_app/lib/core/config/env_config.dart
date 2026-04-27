import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  /// Compile-time override (empty means "not set").
  static const String _dartDefineBackendUrl = String.fromEnvironment(
    'MUZHIR_BACKEND_URL',
    defaultValue: '',
  );

  /// Default when no dart-define or `.env` value is present.
  ///
  /// - Points to the production backend on Render.
  static String get _platformDefaultBackendBaseUrl {
    return 'https://muzhir.onrender.com';
  }

  static String get backendBaseUrl {
    final fromDefine = _dartDefineBackendUrl.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    final value =
        dotenv.isInitialized ? dotenv.env['MUZHIR_BACKEND_URL']?.trim() : null;
    if (value != null && value.isNotEmpty) return value;
    return _platformDefaultBackendBaseUrl;
  }

  static String get backendApiV1BaseUrl {
    final base = backendBaseUrl;
    if (base.endsWith('/api/v1')) return base;
    return '$base/api/v1';
  }
}
