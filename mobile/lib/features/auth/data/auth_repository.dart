import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';

/// The signed-in user, as returned by identity-service.
class UserSession {
  const UserSession({required this.userId, required this.username, required this.role});

  final int userId;
  final String username;
  final String role; // 'USER' or 'ADMIN'

  bool get isAdmin => role == 'ADMIN';
}

/// Talks to identity-service through the gateway (/api/auth/**).
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<UserSession> login({required String email, required String password}) async {
    final response = await _api.dio.post('/api/auth/login', data: {'email': email, 'password': password});
    return _saveSession(response.data as Map<String, dynamic>);
  }

  Future<UserSession> register({required String email, required String username, required String password}) async {
    final response = await _api.dio.post(
      '/api/auth/register',
      data: {'email': email, 'username': username, 'password': password},
    );
    return _saveSession(response.data as Map<String, dynamic>);
  }

  /// Called on app start: a stored token means "still signed in" if /me accepts it
  /// (the interceptor refreshes it first if it has expired).
  Future<UserSession?> restoreSession() async {
    if (await _storage.readAccessToken() == null) return null;
    try {
      final me = (await _api.dio.get('/api/auth/me')).data as Map<String, dynamic>;
      return UserSession(userId: me['id'] as int, username: me['username'] as String, role: me['role'] as String);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {
        // Server unreachable: still sign out locally
      }
    }
    await _storage.clear();
  }

  Future<UserSession> _saveSession(Map<String, dynamic> json) async {
    await _storage.saveTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);
    return UserSession(
      userId: json['userId'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}
