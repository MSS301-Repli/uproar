import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/ui/auth_page.dart';
import 'features/home/home_page.dart';

void main() {
  // Dependencies are created once here and handed down (no service locator needed at this size)
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final authRepository = AuthRepository(api, storage);

  runApp(SocialApp(api: api, authRepository: authRepository));
}

class SocialApp extends StatelessWidget {
  const SocialApp({super.key, required this.api, required this.authRepository});

  final ApiClient api;
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: api),
        RepositoryProvider.value(value: authRepository),
      ],
      child: BlocProvider(
        create: (_) {
          final bloc = AuthBloc(authRepository)..add(const AuthStarted());
          api.onSessionExpired = () => bloc.add(const AuthSessionExpired());
          return bloc;
        },
        child: MaterialApp(
          title: 'Uproar',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          // The auth state decides the root screen: no manual navigation on login/logout
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => switch (state) {
              AuthChecking() => const Scaffold(body: Center(child: CircularProgressIndicator())),
              AuthUnauthenticated() => const AuthPage(),
              AuthAuthenticated(:final session) => HomePage(session: session),
            },
          ),
        ),
      ),
    );
  }
}
