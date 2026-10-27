import 'dart:async';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/routing/app_shell.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/running/data/location_source.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/running/presentation/controllers/run_recorder.dart';
import 'package:fitos/features/running/presentation/controllers/running_providers.dart';
import 'package:fitos/features/running/presentation/screens/live_run_screen.dart';
import 'package:fitos/features/running/presentation/screens/plan_setup_screen.dart';
import 'package:fitos/features/running/presentation/screens/run_detail_screen.dart';
import 'package:fitos/features/running/presentation/screens/run_finish_screen.dart';
import 'package:fitos/features/running/presentation/screens/share_run_screen.dart';
import 'package:fitos/features/running/presentation/widgets/run_map.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/training_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_running.dart';
import '../../support/fake_training_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Beta 4.0 (ADR-038): the Running screens — the Gym | Running switch, a run
/// from Start to Save, the history, a run's page, sharing and GPX with the
/// privacy zone, a treadmill run, location refused, the admin's switch.
void main() {
  late AppDatabase db;
  late FakeRunningApi api;
  late FakeLocationSource gps;
  late FakeRunSharer sharer;
  late FakeBatteryAccess battery;
  late FakeMetaApi meta;
  late FakeRunVoice voice;
  late DateTime clock;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeRunningApi();
    gps = FakeLocationSource();
    sharer = FakeRunSharer();
    battery = FakeBatteryAccess();
    meta = FakeMetaApi();
    voice = FakeRunVoice();
    clock = DateTime.utc(2026, 10, 27, 1, 30);
  });
  // After a failure the test clock stops, and work it was driving can hold
  // the database: close it, but never wait on it for ever.
  tearDown(
    () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
  );

  /// The Training route and the running screens. With [root], the running
  /// screens go on the root navigator, as in the app.
  GoRoute planRoute({GlobalKey<NavigatorState>? root}) => GoRoute(
        path: Routes.plan,
        builder: (_, __) => const TrainingTabScreen(),
        routes: [
          GoRoute(
            path: 'run',
            parentNavigatorKey: root,
            builder: (_, __) => const LiveRunScreen(),
            routes: [
              GoRoute(
                path: 'finish',
                parentNavigatorKey: root,
                builder: (_, __) => const RunFinishScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'running-plan',
            parentNavigatorKey: root,
            builder: (_, __) => const PlanSetupScreen(),
          ),
          GoRoute(
            path: 'runs/:runId',
            parentNavigatorKey: root,
            builder: (_, s) => RunDetailScreen(id: s.pathParameters['runId']!),
            routes: [
              GoRoute(
                path: 'share',
                parentNavigatorKey: root,
                builder: (_, s) =>
                    ShareRunScreen(id: s.pathParameters['runId']!),
              ),
            ],
          ),
        ],
      );

  /// [shell]: Training inside a tab shell with a bottom bar, as in the app
  /// (the tab has its own navigator under the bar).
  Widget harness({bool shell = false}) {
    final root = GlobalKey<NavigatorState>();
    final router = shell
        ? GoRouter(
            navigatorKey: root,
            initialLocation: Routes.plan,
            routes: [
              StatefulShellRoute.indexedStack(
                // The app's own shell: its bar floats over the tab.
                builder: (_, __, navigationShell) =>
                    AppShell(navigationShell: navigationShell),
                branches: [
                  StatefulShellBranch(routes: [planRoute(root: root)]),
                ],
              ),
            ],
          )
        : GoRouter(initialLocation: Routes.plan, routes: [planRoute()]);
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
        exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ...workoutOverrides(
          db,
          FakeWorkoutApi(),
          meta: meta,
          running: api,
          location: gps,
          battery: battery,
          voice: voice,
        ),
        // The test clock's day (a Tuesday), for the plan's week.
        localTodayProvider.overrideWithValue('2026-10-27'),
        runClockProvider.overrideWithValue(() => clock),
        runSharerProvider.overrideWithValue(sharer),
        runMapModeProvider.overrideWithValue(RunMapMode.drawn),
        mapOnlineProvider.overrideWith((_) => Stream.value(true)),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// Scrolls the run report (summary or detail) until [key] is built.
  Future<void> reveal(WidgetTester tester, String key) =>
      tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('run.report.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  /// Scrolls the share screen until [key] is built.
  Future<void> shareTo(WidgetTester tester, String key) =>
      tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('share.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  /// Waits for [future] on the test's clock (the database and the queue run
  /// there; mixing in real time would deadlock them).
  Future<T> done<T>(WidgetTester tester, Future<T> future) async {
    late T value;
    var finished = false;
    unawaited(
      future.then((v) {
        value = v;
        finished = true;
      }),
    );
    for (var i = 0; i < 100 && !finished; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finished, isTrue, reason: 'still waiting');
    return value;
  }

  /// A recording run ticks every second, so the tree never "settles": pump
  /// two seconds of frames instead (dialogs and sheets finish in that).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openRunning(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('training.mode.running')));
    await settle(tester);
  }

  /// Sends fixes and lets the clock move with them.
  Future<void> run(
    WidgetTester tester,
    int seconds, {
    double lat0 = 12.9692,
  }) async {
    final c = container(tester);
    final rec = c.read(runRecorderProvider.notifier);
    for (final f in runNorth(from: clock, seconds: seconds, lat0: lat0)) {
      gps.send(f);
      await tester.pump();
    }
    clock = clock.add(Duration(seconds: seconds));
    await done(tester, rec.flush());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Training opens on Gym; Running is one tap away', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    final mode = tester.widget<SegmentedButton<TrainingMode>>(
      find.byKey(const ValueKey('training.mode')),
    );
    expect(mode.selected, {TrainingMode.gym});
    expect(find.byKey(const ValueKey('running.start')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('training.mode.running')));
    await settle(tester);
    expect(find.byKey(const ValueKey('running.start')), findsOneWidget);
    expect(find.byKey(const ValueKey('running.empty')), findsOneWidget);
    expect(find.text('0.00 km'), findsNWidgets(2));
  });

  testWidgets(
      'inside the app’s tabs, the setup sheet’s Start is above the bottom bar and starts the run',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(shell: true));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('training.mode.running')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    final start = find.byKey(const ValueKey('run.start'));
    // A tap that would land on the bar instead fails the test.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    await tester.tap(start);
    await settle(tester);
    expect(container(tester).read(runRecorderProvider), isNotNull);
    expect(find.byKey(const ValueKey('run.pause')), findsOneWidget);
  });

  testWidgets('the history leaves room for the floating tab bar',
      (tester) async {
    await tester.pumpWidget(harness(shell: true));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('training.mode.running')));
    await settle(tester);
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('running.list')),
    );
    final bar = tester.getSize(find.byType(FitBottomBar));
    expect(
      (list.padding! as EdgeInsets).bottom,
      greaterThanOrEqualTo(bar.height),
    );
  });

  testWidgets('switched off by the admin: Training is the gym alone',
      (tester) async {
    meta.flags = {'running': false};
    await tester.pumpWidget(harness());
    await settle(tester);
    expect(find.byKey(const ValueKey('training.mode')), findsNothing);
  });

  testWidgets(
      'a run from Start to Save: live numbers, pause, finish, summary, the history',
      (tester) async {
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.goal.distance')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.goal.distance.1.0')));
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);

    expect(find.byKey(const ValueKey('run.status')), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.byKey(const ValueKey('run.goal')), findsOneWidget);
    // About 400 m at 3 m/s, past nothing yet.
    await run(tester, 135);
    final c = container(tester);
    expect(c.read(runRecorderProvider)!.track.distanceM, closeTo(400, 15));
    expect(
      find.text(formatKm(c.read(runRecorderProvider)!.track.distanceM)),
      findsOneWidget,
    );
    // Past the first km: the split is announced, the goal is reached.
    await run(tester, 230, lat0: 12.9692 + 405 / 111195);
    expect(find.byKey(const ValueKey('run.split.toast.1')), findsOneWidget);
    expect(find.textContaining('reached'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(const ValueKey('run.pause')));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run.finish')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.finish.yes')));
    await settle(tester);

    // The summary: the phone's figures, a default name.
    expect(find.text('Run summary'), findsOneWidget);
    expect(find.byKey(const ValueKey('run.pending')), findsOneWidget);
    await reveal(tester, 'run.report.splits');
    expect(find.byKey(const ValueKey('run.report.splits')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('run.report.list')),
      const Offset(0, 3000),
    );
    await settle(tester);
    final name =
        tester.widget<TextField>(find.byKey(const ValueKey('run.name')));
    // Named by the time of day where the test runs (CI is in UTC).
    expect(
      name.controller!.text,
      defaultRunName(clock.toLocal(), RunKind.outdoor),
    );
    await tester.enterText(find.byKey(const ValueKey('run.name')), 'Lake loop');
    await reveal(tester, 'run.effort.4');
    await tester.tap(find.byKey(const ValueKey('run.effort.4')));
    await reveal(tester, 'run.save');
    await tester.tap(find.byKey(const ValueKey('run.save')));
    await settle(tester);
    await settle(tester);

    // The run's page; the server has it once the queue drains.
    expect(find.text('Lake loop'), findsWidgets);
    await done(tester, c.read(runningRepositoryProvider).engine.drain());
    await settle(tester);
    final id = api.stored.keys.single;
    expect(api.stored[id]!['name'], 'Lake loop');
    expect(api.stored[id]!['effort'], 4);
    final sent = decodeTrack(
      EncodedTrack.fromJson(api.stored[id]!['track'] as Map<String, dynamic>),
    );
    expect(sent.segments.single.length, greaterThan(100));
  });

  testWidgets('location refused: FITOS says why and starts nothing',
      (tester) async {
    gps.access = LocationAccess.deniedForever;
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    expect(find.byKey(const ValueKey('run.location.denied')), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await settle(tester);
    expect(gps.openedSettings, 1);
    expect(container(tester).read(runRecorderProvider), isNull);
  });

  testWidgets('the battery question comes once, before the first outdoor run',
      (tester) async {
    battery.unrestricted = false;
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    expect(find.byKey(const ValueKey('run.battery')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run.battery.open')));
    await settle(tester);
    expect(battery.opened, 1);
    expect(find.text('Running'), findsOneWidget);
    expect(container(tester).read(runSettingsProvider).batteryAsked, isTrue);
  });

  testWidgets('a treadmill run asks for the distance before it saves',
      (tester) async {
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.kind.treadmill')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    expect(find.byKey(const ValueKey('run.map')), findsNothing);
    expect(gps.listens, 0);
    clock = clock.add(const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('run.pause')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run.finish')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.finish.yes')));
    await settle(tester);
    await reveal(tester, 'run.save');
    await tester.tap(find.byKey(const ValueKey('run.save')));
    await settle(tester);
    expect(find.text('Type the distance the treadmill shows'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('run.treadmillDistance')),
      '4.2',
    );
    await reveal(tester, 'run.save');
    await tester.tap(find.byKey(const ValueKey('run.save')));
    await settle(tester);
    await settle(tester);
    // Saved, and straight to the (scripted) server.
    final body = api.stored.values.single;
    expect(body['kind'], 'treadmill');
    expect(body['distanceM'], closeTo(4200, 0.01));
    expect(body['durationSeconds'], 1200);
  });

  testWidgets('discard: the run is gone and Running is back to Start',
      (tester) async {
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    await run(tester, 20);
    await tester.tap(find.byKey(const ValueKey('run.pause')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run.finish')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.finish.yes')));
    await settle(tester);
    await reveal(tester, 'run.discard');
    await tester.tap(find.byKey(const ValueKey('run.discard')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.discard.yes')));
    await settle(tester);
    await settle(tester);
    expect(find.byKey(const ValueKey('running.start')), findsOneWidget);
    expect(
      (await done(tester, db.select(db.localRuns).get())),
      isEmpty,
    );
  });

  testWidgets('the screen lock catches taps until held', (tester) async {
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.lock')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('run.pause')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(container(tester).read(runRecorderProvider)!.isRunning, isTrue);
    await tester.longPress(find.byKey(const ValueKey('run.unlock')));
    await tester.pump();
    expect(find.byKey(const ValueKey('run.locked')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('run.pause')));
    await tester.pump();
    expect(container(tester).read(runRecorderProvider)!.isPaused, isTrue);
  });

  group('a saved run', () {
    Future<String> savedRun(WidgetTester tester) async {
      await openRunning(tester);
      final c = container(tester);
      final rec = c.read(runRecorderProvider.notifier);
      await done(
        tester,
        rec.start(kind: RunKind.outdoor, goal: const RunGoal.free()),
      );
      for (final f in runNorth(from: clock, seconds: 400)) {
        gps.send(f);
        await tester.pump();
      }
      clock = clock.add(const Duration(seconds: 400));
      final id = (await done(tester, rec.save(name: 'Lake loop')))!;
      await done(tester, c.read(runningRepositoryProvider).engine.drain());
      c.invalidate(runListProvider);
      await settle(tester);
      return id;
    }

    testWidgets('shows in the history with this week, and opens',
        (tester) async {
      final id = await savedRun(tester);
      expect(find.byKey(ValueKey('running.run.$id')), findsOneWidget);
      expect(find.text('1 run · 6:40'), findsNWidgets(2));
      await tester.tap(find.byKey(ValueKey('running.run.$id')));
      await settle(tester);
      expect(find.byKey(const ValueKey('run.report.distance')), findsOneWidget);
      expect(find.byKey(const ValueKey('run.pending')), findsNothing);
    });

    testWidgets('share: GPX without the first and last 200 m, or with them',
        (tester) async {
      final id = await savedRun(tester);
      await tester.tap(find.byKey(ValueKey('running.run.$id')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.share')));
      await settle(tester);
      await shareTo(tester, 'share.gpx');
      await tester.tap(find.byKey(const ValueKey('share.gpx')));
      await settle(tester);
      final hidden = String.fromCharCodes(sharer.shared.single.$3);
      expect(sharer.shared.single.$1, endsWith('Lake loop.gpx'));
      expect(sharer.shared.single.$2, 'application/gpx+xml');
      final all = api.stored[id]!;
      final track = decodeTrack(
        EncodedTrack.fromJson(all['track'] as Map<String, dynamic>),
      );
      final first = track.segments.first.first;
      expect(hidden, isNot(contains('lat="${first.lat.toStringAsFixed(6)}"')));
      await tester.ensureVisible(find.byKey(const ValueKey('share.hideEnds')));
      await tester.tap(find.byKey(const ValueKey('share.hideEnds')));
      await settle(tester);
      await shareTo(tester, 'share.gpx');
      await tester.tap(find.byKey(const ValueKey('share.gpx')));
      await settle(tester);
      final full = String.fromCharCodes(sharer.shared.last.$3);
      expect(full, contains('lat="${first.lat.toStringAsFixed(6)}"'));
      expect(
        '<trkpt'.allMatches(full).length,
        greaterThan('<trkpt'.allMatches(hidden).length),
      );
    });

    testWidgets('edit and delete', (tester) async {
      final id = await savedRun(tester);
      await tester.tap(find.byKey(ValueKey('running.run.$id')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.menu')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.edit')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('run.edit.name')),
        'Hill reps',
      );
      await tester.tap(find.byKey(const ValueKey('run.edit.effort.8')));
      await tester.tap(find.byKey(const ValueKey('run.edit.save')));
      await settle(tester);
      final c = container(tester);
      await done(tester, c.read(runningRepositoryProvider).engine.drain());
      await settle(tester);
      expect(api.stored[id]!['name'], 'Hill reps');
      expect(api.stored[id]!['effort'], 8);

      await tester.tap(find.byKey(const ValueKey('run.menu')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.delete')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.delete.yes')));
      await settle(tester);
      await done(tester, c.read(runningRepositoryProvider).engine.drain());
      await settle(tester);
      expect(api.stored.containsKey(id), isFalse);
      expect(find.byKey(ValueKey('running.run.$id')), findsNothing);
    });
  });

  testWidgets('the live screen fits at 200 % text', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.start')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('run.start')));
    await settle(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await run(tester, 60);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  group('beta 4.1: plans, sessions and the coach', () {
    const today = '2026-10-27';
    Finder setupList() => find
        .descendant(
          of: find.byKey(const ValueKey('plan.setup.list')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> toMake(WidgetTester tester) => tester.scrollUntilVisible(
          find.byKey(const ValueKey('plan.make')),
          200,
          scrollable: setupList(),
        );

    testWidgets(
        'no plan: the way to one; making one sends the choices and shows the week',
        (tester) async {
      await openRunning(tester);
      expect(find.byKey(const ValueKey('running.plan.none')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('running.plan.new')));
      await settle(tester);
      expect(find.text('New running plan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan.goal.half')));
      await tester.enterText(find.byKey(const ValueKey('plan.time')), '24:30');
      api.plan = planJson(
        goal: 'half',
        runs: [plannedRunJson(id: 'p-today', date: today)],
      );
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(api.createdPlans.single, {
        'goal': 'half',
        'level': 'runner',
        'race': {'distance': '5k', 'seconds': 1470},
        'goalSeconds': null,
        'daysPerWeek': 3,
        'weekdays': [2, 4, 7],
        'longRunWeekday': 7,
      });
      expect(find.byKey(const ValueKey('running.plan')), findsOneWidget);
      expect(find.text('Predicted Half marathon: 50:01'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('running.planned.p-today')),
        findsOneWidget,
      );
    });

    testWidgets('plan setup: a time that is not a time, and the beginner 5K',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.plan.new')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('plan.time')), '24');
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan.error')), findsOneWidget);
      expect(api.createdPlans, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan.goal.5k')),
        -200,
        scrollable: setupList(),
      );
      await tester.tap(find.byKey(const ValueKey('plan.goal.5k')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('plan.from.zero')));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan.time')), findsNothing);
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(api.createdPlans.single, containsPair('level', 'beginner'));
      expect(api.createdPlans.single['race'], isNull);
    });

    testWidgets(
        'today’s planned run starts from the plan card: its session runs with the coach',
        (tester) async {
      api.plan = planJson(
        runs: [
          plannedRunJson(
            id: 'p-today',
            date: today,
            kind: 'intervals',
            title: 'Intervals: 2 × 400 m',
            distanceM: null,
            steps: const [
              WorkoutStep(
                kind: StepKind.work,
                distanceM: 400,
                pace: PaceRange(270, 290),
                effort: 'hard',
                repIndex: 1,
                repOf: 2,
              ),
              WorkoutStep(
                kind: StepKind.recover,
                seconds: 60,
                effort: 'jog',
                repIndex: 1,
                repOf: 2,
              ),
              WorkoutStep(
                kind: StepKind.work,
                distanceM: 400,
                pace: PaceRange(270, 290),
                effort: 'hard',
                repIndex: 2,
                repOf: 2,
              ),
            ],
          ),
        ],
      );
      await openRunning(tester);
      await tester
          .tap(find.byKey(const ValueKey('running.planned.start.p-today')));
      await settle(tester);
      expect(find.byKey(const ValueKey('run.planned')), findsOneWidget);
      expect(find.byKey(const ValueKey('run.session')), findsOneWidget);
      expect(find.textContaining('Rep 1 of 2 · 400 m'), findsOneWidget);
      expect(voice.said.first, 'Rep 1 of 2. 400 metres at 4 40.');
      await tester.tap(find.byKey(const ValueKey('run.session.next')));
      await settle(tester);
      expect(find.textContaining('Recover · 1:00'), findsOneWidget);
    });

    testWidgets('a planned run can be skipped and the skip undone',
        (tester) async {
      api.plan = planJson(
        runs: [plannedRunJson(id: 'p-later', date: '2026-10-29')],
      );
      await openRunning(tester);
      await tester
          .tap(find.byKey(const ValueKey('running.planned.menu.p-later')));
      await settle(tester);
      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(api.calls, contains('patchPlanned p-later skip'));
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(api.calls, contains('patchPlanned p-later unskip'));
    });

    testWidgets('the setup sheet: a ready-made session, and sprints',
        (tester) async {
      api.presets = {
        'zones': null,
        'presets': [
          {
            'id': '6x400',
            'name': '6 × 400 m',
            'about': 'Speed.',
            'steps': [
              const WorkoutStep(
                kind: StepKind.work,
                distanceM: 400,
                effort: 'hard',
              ).toJson(),
            ],
          },
        ],
      };
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.start')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.type.session')));
      await settle(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('run.start')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('run.session.6x400')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.start')));
      await settle(tester);
      expect(find.byKey(const ValueKey('run.session')), findsOneWidget);
      expect(voice.said.first, '400 metres hard.');
      final c = container(tester);
      expect(c.read(runRecorderProvider)!.session!.name, '6 × 400 m');
    });

    testWidgets('sprints: reps, distance and rest make the session',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.start')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.type.sprints')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.sprint.reps.4')));
      await tester.tap(find.byKey(const ValueKey('run.sprint.m.200')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.start')));
      await settle(tester);
      final session = container(tester).read(runRecorderProvider)!.session!;
      expect(session.name, 'Sprints: 4 × 200 m');
      expect(session.count, 9); // warm-up, 4 reps, 3 rests, cool-down
    });

    testWidgets(
        'running settings: the voice coach, every half, and a test of the voice',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.settings')));
      await settle(tester);
      await tester
          .tap(find.byKey(const ValueKey('running.settings.testVoice')));
      await settle(tester);
      expect(voice.said.single, startsWith('1 kilometre.'));
      await tester
          .tap(find.byKey(const ValueKey('running.settings.everyHalf')));
      await settle(tester);
      expect(container(tester).read(runSettingsProvider).everyHalf, isTrue);
      await tester.tap(find.byKey(const ValueKey('running.settings.voice')));
      await settle(tester);
      expect(container(tester).read(runSettingsProvider).voice, isFalse);
      expect(
        find.byKey(const ValueKey('running.settings.testVoice')),
        findsNothing,
      );
    });
  });
}

String formatKm(double m) => (m / 1000).toStringAsFixed(2);
