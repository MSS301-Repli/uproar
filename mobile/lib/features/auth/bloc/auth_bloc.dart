import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../data/auth_repository.dart';

// ---------------- Events: what the UI asks for ----------------

sealed class AuthEvent {
  const AuthEvent();
}

/// App launched: try to restore a stored session.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});
  final String email;
  final String password;
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({required this.email, required this.username, required this.password});
  final String email;
  final String username;
  final String password;
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Refresh token rejected (expired, revoked, account locked): back to login.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

// ---------------- States: what the UI shows ----------------

sealed class AuthState {
  const AuthState();
}

/// Checking the stored session (splash screen).
class AuthChecking extends AuthState {
  const AuthChecking();
}

/// Login/register form. [loading] disables the button, [error] is shown under it.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.loading = false, this.error});
  final bool loading;
  final String? error;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);
  final UserSession session;
}

// ---------------- Bloc: events in, states out ----------------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthChecking()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(
      (event, emit) => emit(const AuthUnauthenticated(error: 'Session expired. Please sign in again.')),
    );
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final session = await _repository.restoreSession();
    emit(session == null ? const AuthUnauthenticated() : AuthAuthenticated(session));
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthUnauthenticated(loading: true));
    try {
      emit(AuthAuthenticated(await _repository.login(email: event.email.trim(), password: event.password)));
    } catch (e) {
      emit(AuthUnauthenticated(error: apiErrorMessage(e)));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(const AuthUnauthenticated(loading: true));
    try {
      emit(
        AuthAuthenticated(
          await _repository.register(
            email: event.email.trim(),
            username: event.username.trim(),
            password: event.password,
          ),
        ),
      );
    } catch (e) {
      emit(AuthUnauthenticated(error: apiErrorMessage(e)));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
