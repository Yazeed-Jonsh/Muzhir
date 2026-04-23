import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muzhir/core/config/env_config.dart';
import 'package:geolocator/geolocator.dart';

import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/models/scan_history_item.dart';

/// HTTP client for the Muzhir backend with Firebase Bearer auth and debug logging.
class ApiService {
  factory ApiService({FirebaseAuth? firebaseAuth}) {
    _instance ??= ApiService._internal(firebaseAuth: firebaseAuth);
    return _instance!;
  }

  ApiService._internal({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.backendApiV1BaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.addAll([
      _AuthInterceptor(_auth, _dio),
      _LoggingInterceptor(),
    ]);
  }

  static ApiService? _instance;
  final FirebaseAuth _auth;
  late final Dio _dio;

  /// Calls `GET /health` and returns whether the response status indicates success.
  Future<bool> checkHealth() async {
    print('[checkHealth] Sending request...');
    try {
      final response = await _dio.get<Map<String, dynamic>>('/health');
      print('[checkHealth] Response received (status=${response.statusCode})');
      final code = response.statusCode;
      if (code == null || code < 200 || code >= 300) {
        print('[checkHealth] Error: unexpected HTTP status: $code');
        return false;
      }
      return true;
    } on DioException catch (e) {
      print('Dio Error: ${e.message}');
      return false;
    }
  }

  /// Multipart `POST /diagnose` — uses the same [Dio] instance as [_AuthInterceptor].
  ///
  /// [cropId] is optional on the client; the backend still requires non-empty `cropId` and
  /// `growthStageId` form fields, so pass [growthStageId] when calling the live API.
  Future<DiagnosisResponse> uploadImageForDiagnosis(
    File imageFile, {
    String? cropId,
    String? growthStageId,
  }) async {
    // Multipart bodies (FormData) are single-use streams; refresh token first to
    // reduce the chance of interceptor-level 401 retry on a finalized body.
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}

    double? captureLatitude;
    double? captureLongitude;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          captureLatitude = position.latitude;
          captureLongitude = position.longitude;
        }
      }
    } catch (_) {
      // Omit coordinates when location is unavailable.
    }

    final filename = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'image.jpg';
    final formMap = <String, dynamic>{
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: filename,
      ),
      'cropId': cropId?.trim() ?? '',
      'growthStageId': growthStageId?.trim() ?? '',
      'source': 'mobile',
    };
    if (captureLatitude != null) {
      formMap['latitude'] = captureLatitude;
    }
    if (captureLongitude != null) {
      formMap['longitude'] = captureLongitude;
    }
    final formData = FormData.fromMap(formMap);

    final response = await _dio.post<Map<String, dynamic>>(
      '/diagnose',
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Diagnose response body was empty',
        type: DioExceptionType.badResponse,
      );
    }

    return DiagnosisResponse.fromJson(data);
  }

  /// `GET /history` — returns the signed-in user's scans (same [_dio] + [_AuthInterceptor]).
  ///
  /// The API returns [ScanSummary] rows, not full [DiagnosisResponse] bodies; use
  /// [ScanHistoryItem] for type-safe parsing.
  Future<List<ScanHistoryItem>> getScanHistory({
    int limit = 20,
    String? cropId,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final response = await _dio.get<dynamic>(
      '/history',
      queryParameters: <String, dynamic>{
        'limit': safeLimit,
        if (cropId != null && cropId.trim().isNotEmpty) 'cropId': cropId.trim(),
      },
    );

    final data = response.data;
    if (data is! List) {
      throw FormatException(
        'getScanHistory: expected JSON array, got ${data.runtimeType}',
      );
    }

    return data.map((raw) {
      if (raw is! Map) {
        throw FormatException(
          'getScanHistory: expected object in array, got ${raw.runtimeType}',
        );
      }
      return ScanHistoryItem.fromJson(Map<String, dynamic>.from(raw));
    }).toList();
  }

  /// `GET /map-markers` — scans with GPS for the map (same [_dio] + [_AuthInterceptor]).
  ///
  /// Optional [crop] filters by stored `cropId` (e.g. `tomato`, `corn`). Each item is parsed
  /// with [DiagnosisResponse.fromMapMarkerJson] (minimal fields: scan id, coordinates,
  /// [DiagnosisResponse.cropType], [DiagnosisSection.isHealthy]).
  Future<List<DiagnosisResponse>> getMapMarkers({String? crop}) async {
    final response = await _dio.get<dynamic>(
      '/map-markers',
      queryParameters: <String, dynamic>{
        if (crop != null && crop.trim().isNotEmpty) 'crop': crop.trim(),
      },
    );

    final data = response.data;
    if (data is! List) {
      throw FormatException(
        'getMapMarkers: expected JSON array, got ${data.runtimeType}',
      );
    }

    return data.map((raw) {
      if (raw is! Map) {
        throw FormatException(
          'getMapMarkers: expected object in array, got ${raw.runtimeType}',
        );
      }
      return DiagnosisResponse.fromMapMarkerJson(
        Map<String, dynamic>.from(raw),
      );
    }).toList();
  }

  /// `GET /scan/{scanId}` — full scan document for the signed-in owner.
  Future<DiagnosisResponse> getScanDiagnosis(String scanId) async {
    final id = scanId.trim();
    if (id.isEmpty) {
      throw ArgumentError('scanId must not be empty');
    }
    final response = await _dio.get<Map<String, dynamic>>('/scan/$id');
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Scan response body was empty',
        type: DioExceptionType.badResponse,
      );
    }
    return DiagnosisResponse.fromScanDetailJson(id, data);
  }

  /// `DELETE /scan/{scanId}` — soft delete for the signed-in owner.
  ///
  /// Uses the same authenticated [_dio] client, so [_AuthInterceptor] attaches
  /// the Firebase Bearer token automatically.
  Future<void> deleteScan(String scanId) async {
    final id = scanId.trim();
    if (id.isEmpty) {
      throw ArgumentError('scanId must not be empty');
    }
    final response = await _dio.delete<void>('/scan/$id');
    final code = response.statusCode;
    if (code == null || code < 200 || code >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Delete scan failed (status=$code)',
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// Multipart `POST /profile-photo`.
  ///
  /// Uploads the signed-in user's profile picture and returns the new URL from
  /// response fields (`profileImageUrl` or `imageUrl`).
  Future<String> uploadProfilePicture(File imageFile) async {
    // Multipart bodies cannot be replayed once sent; refresh token before building
    // FormData so we avoid 401-triggered automatic retry for uploads.
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}

    final filename = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'profile.jpg';
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: filename,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/profile-photo',
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Profile upload response body was empty',
        type: DioExceptionType.badResponse,
      );
    }

    final url =
        (data['profileImageUrl'] ?? data['imageUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw const FormatException(
        'uploadProfilePicture: missing profileImageUrl/imageUrl in response.',
      );
    }
    return url;
  }

  /// `DELETE /profile-photo`.
  Future<void> removeProfilePicture() async {
    await _dio.delete<void>('/profile-photo');
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._auth, this._dio);

  final FirebaseAuth _auth;
  final Dio _dio;

  /// Prevents infinite 401 retry loops when a forced refresh still fails auth.
  static const String _kExtra401Retried = '__muzhirAuth401Retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken(false);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // Token read failed; proceed without Bearer (caller may get 401).
      }
    }
    print(
      'DEBUG: Full Authorization Header: ${options.headers['Authorization']}',
    );
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final opts = err.requestOptions;
    final isMultipart = opts.data is FormData;

    if (status != 401 || opts.extra[_kExtra401Retried] == true) {
      handler.next(err);
      return;
    }

    // FormData streams are finalized after first send; retrying with `fetch(opts)`
    // would throw "The FormData has already been finalized".
    if (isMultipart) {
      handler.next(err);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      handler.next(err);
      return;
    }

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }
      opts.extra[_kExtra401Retried] = true;
      opts.headers['Authorization'] = 'Bearer $token';
      print(
        'DEBUG: Full Authorization Header (after refresh): '
        '${opts.headers['Authorization']}',
      );
      final response = await _dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (_) {
      handler.next(err);
    }
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('[API] --> ${options.method} ${options.uri}');
    print('[API]     Headers: ${options.headers}');
    if (options.data != null) {
      print('[API]     Body: ${options.data}');
    }
    if (options.queryParameters.isNotEmpty) {
      print('[API]     Query: ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print(
      '[API] <-- ${response.statusCode} ${response.requestOptions.uri}',
    );
    print('[API]     Data: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print(
      '[API] xx ${err.response?.statusCode ?? '---'} ${err.requestOptions.uri}',
    );
    print('[API]     ${err.message}');
    if (err.response?.data != null) {
      print('[API]     Data: ${err.response?.data}');
    }
    handler.next(err);
  }
}
