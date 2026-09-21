import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:fitos/features/workout/presentation/screens/volume_screen.dart';
import 'package:fitos/features/workout/presentation/widgets/today_session_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6 refresh fix: Home is kept alive by the shell, so the cached
/// `/today` (and `/volume`, a day) must follow what the user just did.
/// The repository fires `watchServerChanges` on a session started,
/// completed or abandoned here and after every drain that reached the
/// server; `todayProvider`, `dayProvider` and `volumeProvider` refetch on
/// each tick. Proven here by counting the fake server's calls and by the
/// screens showing the server's *new* answer, not the first one.
void main() {
  late AppDatabase db;
  late FakeWorkoutApi api;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    container = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        ...workoutOverrides(db, api),
      ],
    );
  });

  /// Keep the view providers alive, as the mounted Home does. Called
  /// inside each provider test (not in setUp) so the widget tests below
  /// start their fetches inside their own test zone.
  void keepAlive() => container
    ..listen(todayProvider, (_, __) {})
    ..listen(volumeProvider, (_, __) {})
    ..listen(dayProvider(1), (_, __) {});
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  int todayCalls() => api.calls.where((c) => c == 'today').length;
  int volumeCalls() => api.calls.where((c) => c == 'volume').length;

  /// Let the change stream, the provider rebuilds and the fetches settle.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  const neglectedCalves = [
    NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 7),
  ];

  test(
      'completing a session causes a second today (and volume) fetch, and the new answer is the one shown',
      () async {
    keepAlive();
    final repo = container.read(workoutRepositoryProvider);
    await container.read(todayProvider.future);
    await container.read(dayProvider(1).future);
    await container.read(volumeProvider.future);
    // One fetch each so far (today, the day, volume); nothing else.
    final t0 = todayCalls();
    final v0 = volumeCalls();
    expect(t0, 2);
    expect(v0, 1);

    final s = await repo.startSession(day: api.todayResponse);
    await settle();
    final afterStart = todayCalls();
    expect(afterStart, greaterThan(t0), reason: 'starting refetches');

    // The server's answer moves (the session is done, neglect changed).
    api.todayResponse = api.todayResponse.copyWith(
      completedSessionId: 'done-1',
      neglected: neglectedCalves,
    );
    await repo.complete(s.clientSessionId);
    await settle();
    expect(todayCalls(), greaterThan(afterStart));
    expect(volumeCalls(), greaterThan(v0));
    final t = await container.read(todayProvider.future);
    expect(t.completedSessionId, 'done-1');
    expect(t.neglected, neglectedCalves);
  });

  test('abandoning a session refreshes TODAY', () async {
    keepAlive();
    final repo = container.read(workoutRepositoryProvider);
    await container.read(todayProvider.future);
    final s = await repo.startSession(day: api.todayResponse);
    await settle();
    final before = todayCalls();
    api.todayResponse = api.todayResponse.copyWith(mesocycleWeek: 3);
    await repo.abandon(s.clientSessionId);
    await settle();
    expect(todayCalls(), greaterThan(before));
    expect((await container.read(todayProvider.future)).mesocycleWeek, 3);
  });

  test('starting a session refreshes today, the day and volume', () async {
    keepAlive();
    final repo = container.read(workoutRepositoryProvider);
    await container.read(todayProvider.future);
    await container.read(dayProvider(1).future);
    await container.read(volumeProvider.future);
    final t0 = todayCalls();
    final v0 = volumeCalls();
    api.todayResponse = api.todayResponse.copyWith(mesocycleWeek: 2);
    await repo.startSession(day: api.todayResponse);
    await settle();
    expect(todayCalls(), greaterThan(t0));
    expect(volumeCalls(), greaterThan(v0));
    expect((await container.read(todayProvider.future)).mesocycleWeek, 2);
    expect((await container.read(dayProvider(1).future)).mesocycleWeek, 2);
  });

  test(
      'a drain that reaches the server after an offline session refreshes TODAY and volume; an empty drain does not',
      () async {
    keepAlive();
    final repo = container.read(workoutRepositoryProvider);
    await container.read(todayProvider.future);
    await container.read(volumeProvider.future);
    // Offline: the session is queued, nothing reaches the server.
    api.offline = true;
    final s = await repo.startSession(day: api.todayResponse);
    await repo.complete(s.clientSessionId);
    await settle();
    expect(api.sessions, isEmpty);
    final t0 = todayCalls();
    final v0 = volumeCalls();
    // Back online: the drain sends start + complete → the server's view moved.
    api.offline = false;
    api.todayResponse = api.todayResponse.copyWith(
      completedSessionId: 'synced-1',
      neglected: neglectedCalves,
    );
    await repo.sync();
    await settle();
    expect(api.sessions, hasLength(1));
    expect(todayCalls(), greaterThan(t0));
    expect(volumeCalls(), greaterThan(v0));
    expect(
      (await container.read(todayProvider.future)).completedSessionId,
      'synced-1',
    );
    // Nothing left to send: another drain fires no refresh.
    final t1 = todayCalls();
    await repo.sync();
    await settle();
    expect(todayCalls(), t1);
  });

  testWidgets('the volume screen does not stay on its first-ever response',
      (tester) async {
    VolumeResponse volumeWith(double chest) => VolumeResponse(
          weeks: [
            VolumeWeek(
              isoWeek: '2026-W39',
              muscles: [
                MuscleWeek(
                  muscle: MuscleGroup.chest,
                  hardSets: chest,
                  tonnageKg: chest * 400,
                  status: LandmarkStatus.mevToMav,
                  landmarks: const VolumeLandmarks(
                    mv: 4,
                    mev: 8,
                    mavLow: 12,
                    mavHigh: 20,
                    mrv: 22,
                  ),
                  owned: true,
                ),
              ],
            ),
          ],
          owned: const [MuscleGroup.chest],
          neglected: const [],
          mesocycleWeek: 1,
          deload: DeloadState.none,
        );
    api.volumeResponse = volumeWith(9);
    final router = GoRouter(
      initialLocation: '/plan/volume',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: TodaySessionPanel()),
        ),
        GoRoute(path: '/plan/volume', builder: (_, __) => const VolumeScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('volume.chest.sets'))).data,
      '9 sets',
    );
    // A session completes; the server now says 13.
    api.volumeResponse = volumeWith(13);
    final repo = container.read(workoutRepositoryProvider);
    final s = await repo.startSession(day: api.todayResponse);
    await repo.complete(s.clientSessionId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('volume.chest.sets'))).data,
      '13 sets',
    );
  });

  testWidgets(
      'Home: the volume affordance reads as navigation and opens /plan/volume',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: TodaySessionPanel()),
          ),
        ),
        GoRoute(path: '/plan/volume', builder: (_, __) => const VolumeScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Training volume →'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today.volume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('volume.list')), findsOneWidget);
  });
}
