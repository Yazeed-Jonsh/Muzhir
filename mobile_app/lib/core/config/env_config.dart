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
  /// - Android emulator: `10.0.2.2` reaches the host machine.
  /// - iOS Simulator: `127.0.0.1` reaches the Mac host.
  /// - Physical iOS device: set `MUZHIR_BACKEND_URL` in `.env` to your Mac's LAN IP.
  static String get _platformDefaultBackendBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  static String get backendBaseUrl {
    final fromDefine = _dartDefineBackendUrl.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    final value = dotenv.env['MUZHIR_BACKEND_URL']?.trim();
    if (value != null && value.isNotEmpty) return value;
    return _platformDefaultBackendBaseUrl;
  }

  static String get backendApiV1BaseUrl {
    final base = backendBaseUrl;
    if (base.endsWith('/api/v1')) return base;
    return '$base/api/v1';
  }
}
