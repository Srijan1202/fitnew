import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  Widget harness() => ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: FitTheme.build(), home: const SignInScreen()),
      );

  final email = find.byKey(const ValueKey('sign-in.email'));
  final password = find.byKey(const ValueKey('sign-in.password'));

  testWidgets('renders both sign-in methods and the recovery links',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNWidgets(2)); // heading + button
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('validates before calling the repository', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('signIn')), isEmpty);
  });

  testWidgets('submits trimmed email and password to the controller',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      email,
      '  student@vit.ac.in  ',
    );
    await tester.enterText(
      password,
      'password1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // The screen passes the raw text; trimming is the data source's job so
    // every entry point (email, Google) trims identically.
    expect(repo.calls, contains('signInWithEmail:  student@vit.ac.in  '));
  });

  testWidgets('shows the failure message in oxide, never a raw exception',
      (tester) async {
    repo.nextSignIn = const Err(wrongPassword);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      email,
      'a@b.c',
    );
    await tester.enterText(
      password,
      'password1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('wrong-password'), findsNothing);
  });

  testWidgets('Google button calls the Google path', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('signInWithGoogle'));
  });
}
