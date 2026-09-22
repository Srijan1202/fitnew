import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/presentation/screens/personal_details_screen.dart';
import 'package:fitos/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_health_provider.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6.6 Gate 7 — Profile → Personal details, found missing on the S24.
/// The editor sends one PATCH with only what changed, lets the server
/// recompute targets (the app never computes or writes one), shows the
/// server's recomputed targets back on Profile, and shows Health Connect's
/// weight only as the phone's own reading — never sent, never auto-applied.
void main() {
  late FakeProfileRepository profile;
  late FakeHealthProvider health;
  late AppDatabase db;

  setUp(() {
    profile = FakeProfileRepository();
    health = FakeHealthProvider();
    db = AppDatabase.inMemory();
  });
  tearDown(() => db.close());

  /// A taller surface: the form's Save sits below the 800 x 600 default.
  /// The width stays 800, because test text uses a square-glyph font that is
  /// far wider than a real one; at a real phone width the Profile targets
  /// row would overflow in the test only.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app() {
    final router = GoRouter(
      initialLocation: Routes.personalDetails,
      routes: [
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'details',
              builder: (_, __) => const PersonalDetailsScreen(),
            ),
            GoRoute(
              path: 'goal',
              builder: (_, __) => const Scaffold(body: Text('GOAL EDITOR')),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        profileRepositoryProvider.overrideWithValue(profile),
        ...workoutOverrides(db, FakeWorkoutApi()),
        ...healthOverrides(health),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Future<void> open(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('details.save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    final option = find.text(label);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
  }

  testWidgets('prefilled from the server: name, height, weight',
      (tester) async {
    await open(tester);
    expect(fieldText(tester, 'details.displayName'), 'Persona');
    expect(fieldText(tester, 'details.heightCm'), '160');
    expect(fieldText(tester, 'details.weightKg'), '58');
    expect(find.textContaining('Born 2005-03-14'), findsOneWidget);
  });

  testWidgets(
      'saving sends ONLY what changed, in the contract\'s wire names — never a target',
      (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('details.weightKg')),
      '61.5',
    );
    await choose(tester, 'Moderately active');
    await save(tester);

    expect(profile.personalChanges, [
      {'weightKg': 61.5, 'activityLevel': 'moderate'},
    ]);
    for (final change in profile.personalChanges) {
      for (final forbidden in [
        'kcal',
        'proteinG',
        'carbG',
        'fatG',
        'targets',
      ]) {
        expect(change.containsKey(forbidden), isFalse);
      }
    }
    // A formula input changed: the goal (with the server's recomputed
    // targets) is re-read, not computed here.
    expect(
      profile.calls.where((c) => c == 'getGoal').length,
      greaterThanOrEqualTo(2),
    );
    expect(
      find.text('Saved. FITOS recalculated your targets.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'name, sex and height together; a name-only edit is not a target change',
      (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('details.displayName')),
      '  Asha  ',
    );
    await save(tester);
    expect(profile.personalChanges.last, {'displayName': 'Asha'});
    expect(find.text('Saved.'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await choose(tester, 'Male');
    await tester.enterText(
      find.byKey(const ValueKey('details.heightCm')),
      '172',
    );
    await save(tester);
    expect(profile.personalChanges.last, {'sex': 'male', 'heightCm': 172.0});
  });

  testWidgets('nothing changed: nothing is sent', (tester) async {
    await open(tester);
    await save(tester);
    expect(profile.personalChanges, isEmpty);
  });

  testWidgets('impossible values are refused on the phone, before any request',
      (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('details.weightKg')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('details.heightCm')),
      '400',
    );
    await tester.enterText(
      find.byKey(const ValueKey('details.displayName')),
      '   ',
    );
    await save(tester);
    expect(find.text('That does not look right for weight.'), findsOneWidget);
    expect(find.text('That does not look right for height.'), findsOneWidget);
    expect(find.text('A name, so FITOS can greet you.'), findsOneWidget);
    expect(profile.personalChanges, isEmpty);
  });

  testWidgets('a server failure is shown in place and nothing is lost',
      (tester) async {
    profile.failPersonalDetails = const Offline();
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('details.weightKg')),
      '60',
    );
    await save(tester);
    expect(find.byKey(const ValueKey('details.error')), findsOneWidget);
    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(fieldText(tester, 'details.weightKg'), '60');
  });

  testWidgets(
      'Health Connect weight is shown as the phone\'s reading, never copied into the FITOS field or sent',
      (tester) async {
    health.connection_ = const HealthConnectionState(
      sdk: HealthSdkStatus.available,
      granted: {HealthMetricKind.weight},
    );
    health.snapshot_ = HealthSnapshot.empty(
      date: '2026-09-23',
      timezone: 'Asia/Kolkata',
      availability: HealthAvailability.noData,
      fetchedAt: FakeHealthProvider.fetchedAt,
    ).copyWith(
      weight: metricOf(
        HealthMetricKind.weight,
        56.8,
        unit: 'kg',
        at: '2026-09-22T01:00:00.000Z',
      ),
    );
    await open(tester);

    expect(
      find.textContaining('Health Connect on this phone: 56.8 kg · 2026-09-22'),
      findsOneWidget,
    );
    expect(fieldText(tester, 'details.weightKg'), '58', reason: 'FITOS value');
    await save(tester);
    expect(profile.personalChanges, isEmpty, reason: 'nothing sent by itself');
  });

  testWidgets('the goal is changed in its own editor, linked from here',
      (tester) async {
    await open(tester);
    final link = find.byKey(const ValueKey('details.goal'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('GOAL EDITOR'), findsOneWidget);
  });

  testWidgets('Profile links to the editor', (tester) async {
    phone(tester);
    final router = GoRouter(
      initialLocation: Routes.profile,
      routes: [
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'details',
              builder: (_, __) => const PersonalDetailsScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('user-1'),
          profileRepositoryProvider.overrideWithValue(profile),
          ...workoutOverrides(db, FakeWorkoutApi()),
          ...healthOverrides(health),
        ],
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('profile.personalDetails'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsOneWidget);
  });
}
