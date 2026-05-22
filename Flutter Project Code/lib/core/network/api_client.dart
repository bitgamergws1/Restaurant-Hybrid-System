import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_endpoints.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ApiException
/// Typed error thrown by [ApiClient] so UI can react precisely.
/// ─────────────────────────────────────────────────────────────────────────────
final class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  bool get isUnauthorised => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// ─────────────────────────────────────────────────────────────────────────────
/// _AuthInterceptor
/// Injects the session token from SharedPreferences into every request.
/// On 401 it clears the stored token so the router can redirect to /login.
/// ─────────────────────────────────────────────────────────────────────────────
final class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor(this._prefs);

  final SharedPreferences _prefs;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _prefs.getString(ApiConfig.tokenPrefKey);
    if (token != null && token.isNotEmpty) {
      options.headers[ApiConfig.sessionTokenHeader] = token;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If the server says the session is invalid, nuke the local token
    // so the GoRouter redirect logic automatically sends the user to /login.
    if (err.response?.statusCode == 401) {
      _prefs.remove(ApiConfig.tokenPrefKey);
      _prefs.remove(ApiConfig.userPrefKey);
    }
    handler.next(err);
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// _LoggingInterceptor
/// Prints requests and responses in debug builds only.
/// ─────────────────────────────────────────────────────────────────────────────
final class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('→ ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('← ${response.statusCode} ${response.requestOptions.uri}');
      return true;
    }());
    handler.next(response);
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// ApiClient
/// Thin wrapper around [Dio]. All feature-layer repositories use this.
///
/// Usage (inside a Riverpod provider):
/// ```dart
/// final client = ref.watch(apiClientProvider);
/// final response = await client.post(ApiEndpoints.login, data: {...});
/// ```
/// ─────────────────────────────────────────────────────────────────────────────
final class ApiClient {
  ApiClient(SharedPreferences prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.timeoutSeconds),
        receiveTimeout: const Duration(seconds: ApiConfig.timeoutSeconds),
        headers: {'Content-Type': 'application/json'},
        // Don't throw on non-2xx so we can parse error bodies ourselves
        validateStatus: (_) => true,
      ),
    )
      ..interceptors.add(_AuthInterceptor(prefs))
      ..interceptors.add(_LoggingInterceptor());
  }

  late final Dio _dio;

  // ── Public helpers ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParams,
    );
    return _handle(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return _handle(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.patch<dynamic>(path, data: data);
    return _handle(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _dio.delete<dynamic>(path);
    return _handle(response);
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  /// Validates the HTTP status and extracts the `data` field from
  /// the backend's standard `{ success, message, data }` envelope.
  Map<String, dynamic> _handle(Response<dynamic> response) {
    final body = response.data;

    // Network-level failure (Dio threw internally)
    if (body == null) {
      throw const ApiException(message: 'No response from server');
    }

    final map = body as Map<String, dynamic>;
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      // Success — return the inner `data` map (or empty map if absent)
      return (map['data'] as Map<String, dynamic>?) ?? {};
    }

    // Server returned a structured error
    final message =
        map['message'] as String? ?? 'Unexpected error (HTTP $statusCode)';
    throw ApiException(message: message, statusCode: statusCode, data: map);
  }
}
