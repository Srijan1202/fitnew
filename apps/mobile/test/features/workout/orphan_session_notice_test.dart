import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:fitos/features/workout/presentation/widgets/orphan_session_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6.6 Gate 7 (S24): the server held an active session the phone had
/// lost (sign-out wiped it before its end synced), so every new session was
/// refused with 409 and Retry could never succeed. The notice names it and
/// lets the user end it — explicitly (owner 8.5: sessions never auto-end).
void main() {
  late AppDatabase db;
  late _LiveTodayApi api;

  setUp(() {
    db = AppDatabase.inMemory();
    api = _LiveTodayApi();
  });
  tearDown(() => db.close());

  /// A session on the server with two sets, unknown to this phone.
  Future<WorkoutSession> orphan() async {
    final started = (await api.start(
      const StartSessionRequest(
        clientSessionId: 'orphan-client-id',
        startedAt: '2026-09-22T20:42:17.000Z',
      ),
    ) as Ok<WorkoutSession>)
        .value;
    final x = api.todayResponse.exercises.first;
    await api.addExercise(
      started.id,
      AddSessionExerciseRequest(
        clientExerciseId: 'orphan-x',
        exerciseId: x.exerciseId,
        orderIndex: 0,
      ),
    );
    await api.logSets(
      started.id,
      const LogSetsRequest(
        sets: [
          LogSetInput(
            clientSetId: 'o1',
            clientExerciseId: 'orphan-x',
            setIndex: 1,
            setType: SetType.working,
            weightKg: 50,
            reps: 10,
            rir: 1,
            loggedAt: '2026-09-22T20:43:00.000Z',
            plannedSetId: null,
          ),
          LogSetInput(
            clientSetId: 'o2',
            clientExerciseId: 'orphan-x',
            setIndex: 2,
            setType: SetType.working,
            weightKg: 50,
            reps: 9,
            rir: 1,
            loggedAt: '2026-09-22T20:45:30.000Z',
            plannedSetId: null,
          ),
        ],
      ),
    );
    api.calls.clear();
    return api.sessions['orphan-client-id']!;
  }

  late ProviderContainer container;

  Widget app() {
    return UncontrolledProviderScope(
      container: container = ProviderContainer(
        overrides: [
          sessionUserIdProvider.overrideWithValue('user-1'),
          ...workoutOverrides(db, api),
        ],
      ),
      child: MaterialApp(
        theme: FitTheme.build(),
        home: const Scaffold(body: OrphanSessionNotice()),
      ),
    );
  }

  Future<void> resolve(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(ValueKey('orphan.$action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('orphan.confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('orphan.confirm.ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('names the session FITOS holds: name, start, sets',
      (tester) async {
    await orphan();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('orphan.notice')), findsOneWidget);
    expect(find.text('UNFINISHED SESSION ON FITOS'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('orphan.summary'))).data,
      contains('· 2 sets'),
    );
    container.dispose();
  });

  testWidgets(
      'Finish asks, then completes it on the server at its last set; the notice goes and today / history are asked again',
      (tester) async {
    final o = await orphan();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final todays = api.calls.where((c) => c == 'today').length;

    await resolve(tester, 'finish');

    expect(api.calls, contains('complete'));
    expect(api.sessions[o.clientSessionId]!.status, SessionStatus.completed);
    expect(api.lastCompletedAt, '2026-09-22T20:45:30.000Z');
    expect(
      api.calls.where((c) => c == 'today').length,
      greaterThan(todays),
    );
    expect(find.byKey(const ValueKey('orphan.notice')), findsNothing);
    container.dispose();
  });

  testWidgets('Not now changes nothing', (tester) async {
    await orphan();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orphan.discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orphan.confirm.cancel')));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c == 'abandon' || c == 'complete'), isEmpty);
    expect(find.byKey(const ValueKey('orphan.notice')), findsOneWidget);
    container.dispose();
  });

  testWidgets('Discard abandons it on the server; the notice goes',
      (tester) async {
    final o = await orphan();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await resolve(tester, 'discard');
    expect(api.sessions[o.clientSessionId]!.status, SessionStatus.abandoned);
    expect(find.byKey(const ValueKey('orphan.notice')), findsNothing);
    container.dispose();
  });

  testWidgets(
      'the server\'s active session that IS this phone\'s own is not an orphan (normal resume stays as it was)',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final repo = container.read(workoutRepositoryProvider);
    await tester.runAsync(() async {
      await repo.startSession(day: api.todayResponse);
      await repo.sync();
    });
    container.invalidate(todayProvider);
    await tester.pumpAndSettle();
    expect(api.sessions.values.single.status, SessionStatus.active);
    expect(find.byKey(const ValueKey('orphan.notice')), findsNothing);
    container.dispose();
  });

  testWidgets('a failure while ending it is shown; nothing is lost',
      (tester) async {
    await orphan();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    api.offline = true;
    await resolve(tester, 'finish');
    expect(find.byKey(const ValueKey('orphan.error')), findsOneWidget);
    expect(
      api.sessions['orphan-client-id']!.status,
      SessionStatus.active,
    );
    container.dispose();
  });
}

/// `/today` computed from the fake server's sessions, as the real one is:
/// `activeSession` is whatever is active there now.
class _LiveTodayApi extends FakeWorkoutApi {
  String? lastCompletedAt;

  @override
  Future<Result<TodayResponse>> today({int? dayOfWeek}) async {
    final r = await super.today(dayOfWeek: dayOfWeek);
    if (r is! Ok<TodayResponse>) return r;
    final active = sessions.values
        .where((s) => s.status == SessionStatus.active)
        .firstOrNull;
    return Ok(r.value.copyWith(activeSession: active));
  }

  @override
  Future<Result<WorkoutSession>> complete(
    String id,
    CompleteSessionRequest request,
  ) {
    lastCompletedAt = request.completedAt;
    return super.complete(id, request);
  }
}
