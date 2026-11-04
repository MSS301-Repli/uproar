// Widget test: the auth form validates input and talks to the bloc.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/features/auth/bloc/auth_bloc.dart';
import 'package:social_app/features/auth/data/auth_repository.dart';
import 'package:social_app/features/auth/ui/auth_page.dart';

import 'auth_bloc_test.dart' show FakeAuthRepository;

void main() {
  late FakeAuthRepository repository;
  late AuthBloc bloc;

  Future<void> pumpAuthPage(WidgetTester tester) async {
    repository = FakeAuthRepository();
    bloc = AuthBloc(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const AuthPage()),
      ),
    );
  }

  tearDown(() => bloc.close());

  testWidgets('empty form shows validation errors and does not sign in', (tester) async {
    await pumpAuthPage(tester);

    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repository.stored, isNull);
  });

  testWidgets('register mode shows the username field and enforces its rule', (tester) async {
    await pumpAuthPage(tester);
    expect(find.byKey(const Key('username')), findsNothing);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(find.byKey(const Key('username')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'anna@test.com');
    await tester.enterText(find.byKey(const Key('username')), 'a'); // too short
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text("3-30 characters: letters, digits, '_' or '.'"), findsOneWidget);
  });

  testWidgets('valid login reaches the bloc and signs in', (tester) async {
    await pumpAuthPage(tester);

    await tester.enterText(find.byKey(const Key('email')), 'anna@test.com');
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(bloc.state, isA<AuthAuthenticated>());
    expect((bloc.state as AuthAuthenticated).session, isA<UserSession>());
  });
}
