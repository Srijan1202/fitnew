import 'package:fitos/app.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

/// The whole app through the router and the auth gate, with the repository
/// faked. These are the spec's acceptance paths in miniature: a signed-out
/// launch lands on sign-in, a restored session lands on TODAY, sign-out
/// returns to sign-in.
void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  Widget app() => ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const FitOSApp(),
      );

  testWidgets('cold start, signed out → sign-in screen on paper',
      (tester) async {
    repo.restoreResult = const AuthState.signedOut();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Phase 1'), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
      FitColors.paper,
    );
  });

  testWidgets('cold start, session persisted → straight to TODAY, no sign-in',
      (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Phase 1'), findsOneWidget);
    expect(find.text('student@vit.ac.in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('sign out from TODAY returns to sign-in', (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('signOut'));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Phase 1'), findsNothing);
  });

  testWidgets('uses ink, not colour, for the primary type', (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Phase 1'));
    final context = tester.element(find.text('Phase 1'));
    final style = heading.style ?? Theme.of(context).textTheme.displayMedium!;
    expect(style.color, FitColors.ink);
  });
}
