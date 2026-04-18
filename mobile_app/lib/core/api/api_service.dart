import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:muzhir/models/diagnosis_response.dart';

/// HTTP client for the Muzhir backend with Firebase Bearer auth and debug logging.
class ApiService {
  ApiService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://10.0.2.2:8000/api/v1',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.addAll([
      _AuthInterceptor(_auth),
      _LoggingInterceptor(),
    ]);
  }

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
    final filename = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'image.jpg';
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: filename,
      ),
      'cropId': cropId?.trim() ?? '',
      'growthStageId': growthStageId?.trim() ?? '',
      'source': 'mobile',
    });

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
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
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
