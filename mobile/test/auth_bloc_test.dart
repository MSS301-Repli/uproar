// Unit test: business logic of AuthBloc, no network.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/features/auth/bloc/auth_bloc.dart';
import 'package:social_app/features/auth/data/auth_repository.dart';

/// In-memory stand-in for the real repository.
class FakeAuthRepository implements AuthRepository {
  UserSession? stored;
  bool failLogin = false;

  @override
  Future<UserSession> login({required String email, required String password}) async {
    if (failLogin) {
      final request = RequestOptions(path: '/api/auth/login');
      throw DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 401,
          data: {'status': 401, 'message': 'Invalid email or password'},
        ),
      );
    }
    return stored = const UserSession(userId: 2, username: 'anna', role: 'USER');
  }

  @override
  Future<UserSession> register({required String email, required String username, required String password}) async =>
      stored = UserSession(userId: 3, username: username, role: 'USER');

  @override
  Future<UserSession?> restoreSession() async => stored;

  @override
  Future<void> logout() async => stored = null;
}

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  test('no stored session -> unauthenticated', () async {
    final bloc = AuthBloc(repository)..add(const AuthStarted());
    await expectLater(bloc.stream, emits(isA<AuthUnauthenticated>()));
    await bloc.close();
  });

  test('stored session -> authenticated without logging in again', () async {
    repository.stored = const UserSession(userId: 1, username: 'admin', role: 'ADMIN');
    final bloc = AuthBloc(repository)..add(const AuthStarted());
    await expectLater(bloc.stream, emits(isA<AuthAuthenticated>().having((s) => s.session.isAdmin, 'isAdmin', true)));
    await bloc.close();
  });

  test('successful login: loading, then authenticated', () async {
    final bloc = AuthBloc(repository)..add(const AuthLoginRequested(email: 'anna@test.com', password: 'password1'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthUnauthenticated>().having((s) => s.loading, 'loading', true),
        isA<AuthAuthenticated>().having((s) => s.session.username, 'username', 'anna'),
      ]),
    );
    await bloc.close();
  });

  test('wrong password shows the message from the server', () async {
    repository.failLogin = true;
    final bloc = AuthBloc(repository)..add(const AuthLoginRequested(email: 'anna@test.com', password: 'wrong'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthUnauthenticated>().having((s) => s.loading, 'loading', true),
        isA<AuthUnauthenticated>().having((s) => s.error, 'error', 'Invalid email or password'),
      ]),
    );
    await bloc.close();
  });

  test('logout clears the session', () async {
    repository.stored = const UserSession(userId: 2, username: 'anna', role: 'USER');
    final bloc = AuthBloc(repository)..add(const AuthLogoutRequested());
    await expectLater(bloc.stream, emits(isA<AuthUnauthenticated>()));
    expect(repository.stored, isNull);
    await bloc.close();
  });
}
