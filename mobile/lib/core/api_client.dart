import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Gateway URL. Android emulator reaches the host machine at 10.0.2.2.
/// Override per device: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

/// Single Dio instance for the whole app. Every request goes through the API Gateway.
///
/// - Adds `Authorization: Bearer <accessToken>` to every request.
/// - On 401, refreshes the token once and retries the request.
/// - If refreshing fails, clears the session and calls [onSessionExpired].
class ApiClient {
  ApiClient(this._storage, {Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ) {
    this.dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _attachToken, onError: _refreshOn401));
  }

  final Dio dio;
  final TokenStorage _storage;

  /// Set by AuthBloc so an expired session sends the user back to login.
  void Function()? onSessionExpired;

  static const _publicPaths = ['/api/auth/login', '/api/auth/register', '/api/auth/refresh'];

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_publicPaths.contains(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _refreshOn401(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final alreadyRetried = request.extra['retried'] == true;
    if (error.response?.statusCode != 401 || _publicPaths.contains(request.path) || alreadyRetried) {
      return handler.next(error);
    }

    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return _expire(error, handler);

    try {
      // Plain Dio: must not go through this interceptor again
      final response = await Dio(
        BaseOptions(baseUrl: dio.options.baseUrl),
      ).post('/api/auth/refresh', data: {'refreshToken': refreshToken});
      await _storage.saveTokens(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer ${response.data['accessToken']}';
      handler.resolve(await dio.fetch(request));
    } on DioException {
      await _expire(error, handler);
    }
  }

  Future<void> _expire(DioException error, ErrorInterceptorHandler handler) async {
    await _storage.clear();
    onSessionExpired?.call();
    handler.next(error);
  }
}

/// Turns any API error into a message for the user.
/// Backend errors look like { "status": 409, "message": "Email is already registered", ... }.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Check your connection.';
    }
  }
  return 'Something went wrong. Please try again.';
}
