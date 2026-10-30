import 'dart:async';
import 'dart:convert';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/app_shell.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/running/data/location_source.dart';
import 'package:fitos/features/running/data/watch_import.dart';
import 'package:fitos/features/running/domain/efforts.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/running/presentation/controllers/run_recorder.dart';
import 'package:fitos/features/running/presentation/controllers/running_providers.dart';
import 'package:fitos/features/running/presentation/screens/badges_screen.dart';
import 'package:fitos/features/running/presentation/screens/live_run_screen.dart';
import 'package:fitos/features/running/presentation/screens/plan_setup_screen.dart';
import 'package:fitos/features/running/presentation/screens/records_screen.dart';
import 'package:fitos/features/running/presentation/screens/run_detail_screen.dart';
import 'package:fitos/features/running/presentation/screens/run_finish_screen.dart';
import 'package:fitos/features/running/presentation/screens/run_replay_screen.dart';
import 'package:fitos/features/running/presentation/screens/share_run_screen.dart';
import 'package:fitos/features/running/presentation/widgets/route_snapshot.dart';
import 'package:fitos/features/running/presentation/widgets/run_map.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/training_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_exercise_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_rewards_api.dart';
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
  late FakeRouteSnapshotter snapshots;
  late FakeBatteryAccess battery;
  late FakeMetaApi meta;
  late FakeRunVoice voice;
  late FakeRewardsApi rewards;
  late FakeWatch watch;
  late DateTime clock;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeRunningApi();
    gps = FakeLocationSource();
    sharer = FakeRunSharer();
    snapshots = FakeRouteSnapshotter();
    battery = FakeBatteryAccess();
    meta = FakeMetaApi();
    voice = FakeRunVoice();
    rewards = FakeRewardsApi();
    watch = FakeWatch()..allowed = false;
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
            path: 'running-records',
            parentNavigatorKey: root,
            builder: (_, __) => const RecordsScreen(),
          ),
          GoRoute(
            path: 'running-badges',
            parentNavigatorKey: root,
            builder: (_, __) => const BadgesScreen(),
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
              GoRoute(
                path: 'replay',
                parentNavigatorKey: root,
                builder: (_, s) =>
                    RunReplayScreen(id: s.pathParameters['runId']!),
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
          rewards: rewards,
        ),
        // The test clock's day (a Tuesday), for the plan's week.
        localTodayProvider.overrideWithValue('2026-10-27'),
        runClockProvider.overrideWithValue(() => clock),
        runSharerProvider.overrideWithValue(sharer),
        routeSnapshotterProvider.overrideWithValue(snapshots),
        watchSourceProvider.overrideWithValue(watch),
        runMapModeProvider.overrideWithValue(RunMapMode.drawn),
        mapOnlineProvider.overrideWith((_) => Stream.value(true)),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// Running's history sits below the header, the plan and the totals:
  /// scrolls the page until [finder] is built.
  Future<void> toHistory(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('running.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  /// Scrolls the run report (summary or detail) until [key] is built.
  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('run.report.list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Wholly on screen, not just its edge.
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pump();
  }

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
    // The chosen half is the pill: on the left for Gym, then the right.
    double thumbX() =>
        tester.getCenter(find.byKey(const ValueKey('training.mode.thumb'))).dx;
    final middle =
        tester.getCenter(find.byKey(const ValueKey('training.mode'))).dx;
    expect(container(tester).read(trainingModeProvider), TrainingMode.gym);
    expect(thumbX(), lessThan(middle));
    expect(find.byKey(const ValueKey('running.start')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('training.mode.running')));
    await settle(tester);
    expect(thumbX(), greaterThan(middle));
    expect(find.byKey(const ValueKey('running.start')), findsOneWidget);
    await toHistory(tester, find.byKey(const ValueKey('running.empty')));
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
      'beta 4.2: a run that beats a record and earns a badge says so on its summary, out loud, before it is saved',
      (tester) async {
    // A 400 m record of 3:20 on file; no 1 km yet; no badges yet.
    api.recordsJson = {
      'records': [
        for (final k in EffortKey.values)
          {
            'key': k.wire,
            'best': k == EffortKey.m400
                ? [
                    {
                      'runId': 'old',
                      'name': 'Old',
                      'startedAt': '2026-10-01T01:00:00Z',
                      'seconds': 200.0,
                    },
                  ]
                : <Object>[],
          },
      ],
      'pending': 0,
    };
    await openRunning(tester);
    final c = container(tester);
    await done(
      tester,
      c.read(runRecorderProvider.notifier).start(
            kind: RunKind.outdoor,
            goal: const RunGoal.free(),
          ),
    );
    for (final f in runNorth(from: clock, seconds: 400)) {
      gps.send(f);
      await tester.pump();
    }
    clock = clock.add(const Duration(seconds: 400));
    await done(tester, c.read(runRecorderProvider.notifier).finish());
    GoRouter.of(tester.element(find.byType(TrainingTabScreen)))
        .push(Routes.runFinish);
    await settle(tester);
    expect(find.text('Run summary'), findsOneWidget);
    expect(find.byKey(const ValueKey('run.achievements')), findsOneWidget);
    expect(find.byKey(const ValueKey('run.newRecord.400m')), findsOneWidget);
    expect(find.byKey(const ValueKey('run.newRecord.1k')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('run.newBadge.first-run')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('run.newBadge.first-5k')), findsNothing);
    expect(
      voice.said.where((x) => x.startsWith('New record. 400 metres in')),
      hasLength(1),
    );
    expect(voice.said.last, contains('Badge earned: First run.'));
  });

  testWidgets(
      'beta 4.2: Badges — earned ones with their day and what they unlocked, the rest with how to earn them',
      (tester) async {
    rewards.badgesEarned = {
      RunBadge.firstRun: DateTime.utc(2026, 10, 1),
      RunBadge.first5k: DateTime.utc(2026, 10, 2),
      RunBadge.first10k: DateTime.utc(2026, 10, 20),
    };
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.badges')));
    await settle(tester);
    String text(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(text('badge.first-10k.status'), startsWith('Earned'));
    expect(
      text('badge.first-10k.unlocks'),
      'Unlocked the Finisher app icon: choose it in Profile.',
    );
    expect(
      text('badge.first-half.status'),
      'Run a half marathon in one go to earn it.',
    );
    expect(text('badge.first-half.unlocks'), 'Unlocks the Road theme.');
    expect(find.byKey(const ValueKey('badge.first-run.unlocks')), findsNothing);
  });

  testWidgets(
      'beta 4.5: a Galaxy Watch run comes in by itself when Running opens: marked as the watch\u2019s, with heart rate, and no map when the route was not shared',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final start = DateTime.utc(2026, 10, 26, 1);
    watch
      ..allowed = true
      ..found = [
        WatchRun(
          id: 'hc-1',
          start: start,
          end: start.add(const Duration(minutes: 30)),
          treadmill: false,
          pausedSeconds: 0,
          distanceM: 5200,
          hrAvg: 150,
          hrMax: 176,
        ),
      ];
    await openRunning(tester);
    await settle(tester);
    expect(api.stored.values.single['source'], 'watch');
    final id = api.stored.keys.single;
    await toHistory(tester, find.byKey(ValueKey('running.run.$id')));
    expect(find.byKey(ValueKey('running.run.$id.watch')), findsOneWidget);
    final row = find.byKey(ValueKey('running.run.$id'));
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await settle(tester);
    expect(find.byKey(const ValueKey('run.report.noRoute')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('run.report.when'))).data,
      endsWith('Galaxy Watch'),
    );
    await reveal(tester, 'run.report.hrMax');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('run.report.hrAvg'))).data,
      '150',
    );
  });

  testWidgets(
      'beta 4.5: the watch switch in Running settings asks Health Connect; turned off, nothing is imported',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await openRunning(tester);
    await tester.tap(find.byKey(const ValueKey('running.settings')));
    await settle(tester);
    final sw = find.byKey(const ValueKey('running.settings.watch'));
    await tester.ensureVisible(sw);
    // On by default; off, then on again (Health Connect asked).
    await tester.tap(sw);
    await settle(tester);
    expect(container(tester).read(runSettingsProvider).watchImport, isFalse);
    watch.grantOnAsk = true;
    await tester.tap(sw);
    await settle(tester);
    expect(watch.asks, [true]);
    expect(container(tester).read(runSettingsProvider).watchImport, isTrue);
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
    // The upload takes a moment, as on a phone: the run's page opens first.
    api.holdUploads = Completer<void>();
    await reveal(tester, 'run.save');
    await tester.tap(find.byKey(const ValueKey('run.save')));
    await settle(tester);
    await settle(tester);

    // The run's page; the server has it once the queue drains.
    expect(find.text('Lake loop'), findsWidgets);
    expect(find.byKey(const ValueKey('run.pending')), findsOneWidget);
    api.holdUploads!.complete();
    await done(tester, c.read(runningRepositoryProvider).engine.drain());
    await settle(tester);
    final id = api.stored.keys.single;
    expect(api.stored[id]!['name'], 'Lake loop');
    expect(api.stored[id]!['effort'], 4);
    // Owner 2026-10-30: once sent, the page is the server's run, not
    // "Not synced yet" until FITOS is closed.
    expect(find.byKey(const ValueKey('run.pending')), findsNothing);
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
    /// Beta 4.2: the history sits below Records and Badges; scroll to it.
    Future<void> openRun(WidgetTester tester, String id) async {
      final row = find.byKey(ValueKey('running.run.$id'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('running.list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Clear of the floating tab bar.
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
    }

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

    testWidgets(
        'beta 4.1: a sprint session’s summary names the best rep and how far to trust it',
        (tester) async {
      final id = await savedRun(tester);
      const work =
          WorkoutStep(kind: StepKind.work, distanceM: 100, effort: 'all out');
      api.stored[id]!
        ..['workout'] = const RunWorkout(
          name: 'Sprints: 2 × 100 m',
          steps: [
            work,
            WorkoutStep(kind: StepKind.recover, seconds: 120, effort: 'stand'),
            work,
          ],
        ).toJson()
        ..['laps'] = [
          {'step': 0, 'distanceM': 101.0, 'seconds': 14.2, 'pace': 140.6},
          {'step': 1, 'distanceM': 20.0, 'seconds': 120.0, 'pace': 6000.0},
          {'step': 2, 'distanceM': 99.0, 'seconds': 13.6, 'pace': 137.4},
        ];
      await openRun(tester, id);
      await settle(tester);
      await reveal(tester, 'run.report.laps.best');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('run.report.laps.best')))
            .data,
        'Best: Work · 13.6 s',
      );
      expect(find.byKey(const ValueKey('run.report.laps.gps')), findsOneWidget);
    });

    testWidgets('shows in the history with this week, and opens',
        (tester) async {
      final id = await savedRun(tester);
      await toHistory(tester, find.byKey(ValueKey('running.run.$id')));
      expect(find.byKey(ValueKey('running.run.$id')), findsOneWidget);
      expect(find.text('1 run · 6:40'), findsNWidgets(2));
      await openRun(tester, id);
      await settle(tester);
      expect(find.byKey(const ValueKey('run.report.distance')), findsOneWidget);
      expect(find.byKey(const ValueKey('run.pending')), findsNothing);
    });

    testWidgets('share: GPX without the first and last 200 m, or with them',
        (tester) async {
      final id = await savedRun(tester);
      await openRun(tester, id);
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

    testWidgets(
        'beta 4.1.1: the share card is the picture shared: the map is made with the route in it, again when the ends are shown',
        (tester) async {
      final id = await savedRun(tester);
      await openRun(tester, id);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.share')));
      await settle(tester);
      expect(snapshots.taken, hasLength(1));
      expect(find.byKey(const ValueKey('share.map.picture')), findsOneWidget);
      final hiddenPoints =
          snapshots.taken.single.fold<int>(0, (n, s) => n + s.length);
      expect(hiddenPoints, greaterThan(1));

      await shareTo(tester, 'share.hideEnds');
      await tester.tap(find.byKey(const ValueKey('share.hideEnds')));
      await settle(tester);
      expect(snapshots.taken, hasLength(2));
      final allPoints =
          snapshots.taken.last.fold<int>(0, (n, s) => n + s.length);
      expect(allPoints, greaterThan(hiddenPoints));
      expect(find.byKey(const ValueKey('share.map.picture')), findsOneWidget);
    });

    testWidgets(
        'beta 4.1.1: no map picture (offline): the card keeps FITOS’s own drawn route',
        (tester) async {
      snapshots.image = null;
      final id = await savedRun(tester);
      await openRun(tester, id);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('run.share')));
      await settle(tester);
      expect(find.byKey(const ValueKey('share.map.drawn')), findsOneWidget);
      expect(find.byKey(const ValueKey('share.map.picture')), findsNothing);
    });

    testWidgets(
        'beta 4.2: a run’s best efforts with the record’s medal, and its trophy in the history',
        (tester) async {
      final id = await savedRun(tester);
      await toHistory(tester, find.byKey(ValueKey('running.run.$id')));
      // About 1.2 km at 3 m/s: 400 m and 1 km, both records (the first run).
      expect(
        find.byKey(ValueKey('running.run.$id.record')),
        findsOneWidget,
      );
      await openRun(tester, id);
      await settle(tester);
      await reveal(tester, 'run.report.effort.1k');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('run.report.effort.400m')),
          matching: find.byIcon(Icons.emoji_events),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('run.report.effort.5k')), findsNothing);
      expect(
        find.byKey(const ValueKey('run.report.efforts.record')),
        findsOneWidget,
      );
    });

    testWidgets(
        'beta 4.2: Records — each distance’s record or none; a distance opens its best three, and a run',
        (tester) async {
      final id = await savedRun(tester);
      api.recordsJson = {
        'records': [
          for (final k in EffortKey.values)
            {
              'key': k.wire,
              'best': k == EffortKey.k5
                  ? [
                      {
                        'runId': id,
                        'name': 'Lake loop',
                        'startedAt': '2026-10-26T01:30:00Z',
                        'seconds': 1471.4,
                      },
                      {
                        'runId': 'other',
                        'name': 'Slow one',
                        'startedAt': '2026-10-20T01:30:00Z',
                        'seconds': 1600.0,
                      },
                    ]
                  : <Object>[],
            },
        ],
        'pending': 3,
      };
      container(tester).invalidate(recordsProvider);
      await tester.tap(find.byKey(const ValueKey('running.records')));
      await settle(tester);
      expect(find.text('Running records'), findsOneWidget);
      String time(String key) =>
          tester.widget<Text>(find.byKey(ValueKey('records.$key.time'))).data!;
      expect(time('5k'), '24:31');
      expect(time('10k'), '—');
      expect(find.byKey(const ValueKey('records.pending')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('records.5k')));
      await settle(tester);
      expect(find.byKey(const ValueKey('records.5k.1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('records.5k.0')));
      await settle(tester);
      expect(find.byKey(const ValueKey('run.report.distance')), findsOneWidget);
    });

    testWidgets(
        'beta 4.4: a run\u2019s map in pace colours with the legend; Replay plays it, pauses, scrubs and changes speed',
        (tester) async {
      final id = await savedRun(tester);
      await openRun(tester, id);
      await settle(tester);
      expect(find.byKey(const ValueKey('run.paceLegend')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('run.replay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('replay.map')), findsOneWidget);
      String text(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      Future<void> tapIt(String key) async {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey(key)));
      }

      // Half a second into a 20 s replay: under way, not at the end.
      expect(text('replay.time'), isNot('0:00'));
      // Pause, then the scrubber to the end: the whole run.
      await tapIt('replay.play');
      await tester.pump();
      final slider =
          tester.widget<Slider>(find.byKey(const ValueKey('replay.scrub')));
      slider.onChanged!(1);
      await tester.pump();
      final run = api.stored[id]!;
      expect(
        text('replay.distance'),
        formatKm((run['distanceM'] as num).toDouble()),
      );
      await tapIt('replay.speed.2.0');
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('replay.speed.2.0')))
            .selected,
        isTrue,
      );
      // Play again from the end: it starts over.
      await tapIt('replay.play');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('replay.scrub'))).value,
        lessThan(0.5),
      );
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('edit and delete', (tester) async {
      final id = await savedRun(tester);
      await openRun(tester, id);
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
      // Number boxes: phone number pads have no ":".
      await tester.enterText(find.byKey(const ValueKey('plan.time.m')), '24');
      await tester.enterText(find.byKey(const ValueKey('plan.time.s')), '30');
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

    testWidgets(
        'beta 4.4: 1 to 5 runs a week for any plan; a half on 2 says it is harder',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.plan.new')));
      await settle(tester);
      for (final n in [1, 2, 3, 4, 5]) {
        expect(find.byKey(ValueKey('plan.days.$n')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('plan.goal.half')));
      await tester.enterText(find.byKey(const ValueKey('plan.time.m')), '24');
      final days2 = find.byKey(const ValueKey('plan.days.2'));
      await tester.ensureVisible(days2);
      await tester.tap(days2);
      await settle(tester);
      expect(find.byKey(const ValueKey('plan.fewRuns')), findsOneWidget);
      // Two days: Tuesday and Sunday (Thursday off).
      final thu = find.byKey(const ValueKey('plan.day.4'));
      await tester.ensureVisible(thu);
      await tester.tap(thu);
      await settle(tester);
      api.plan = planJson(goal: 'half', runs: const []);
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(api.createdPlans.single, containsPair('daysPerWeek', 2));
      expect(api.createdPlans.single['weekdays'], [2, 7]);
    });

    testWidgets('plan setup: a time that is not a time, and the beginner 5K',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.plan.new')));
      await settle(tester);
      // Nothing typed is not a time, and neither are 75 seconds.
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan.error')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan.time.s')),
        -200,
        scrollable: setupList(),
      );
      await tester.enterText(find.byKey(const ValueKey('plan.time.m')), '24');
      await tester.enterText(find.byKey(const ValueKey('plan.time.s')), '75');
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan.error')), findsOneWidget);
      expect(api.createdPlans, isEmpty);
      await tester.scrollUntilVisible(
        find.text('DISTANCE'),
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

    testWidgets('plan setup: a goal time in hours, minutes and seconds',
        (tester) async {
      await openRunning(tester);
      await tester.tap(find.byKey(const ValueKey('running.plan.new')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('plan.goal.half')));
      await tester.tap(find.byKey(const ValueKey('plan.from.goal')));
      await settle(tester);
      expect(find.text('Goal time for the Half marathon'), findsOneWidget);
      // The seconds box left empty counts as 0; letters never get in.
      await tester.enterText(find.byKey(const ValueKey('plan.time.h')), '1');
      await tester.enterText(find.byKey(const ValueKey('plan.time.m')), '5a2');
      api.plan = planJson(goal: 'half', runs: const []);
      await toMake(tester);
      await tester.tap(find.byKey(const ValueKey('plan.make')));
      await settle(tester);
      expect(api.createdPlans.single, containsPair('goalSeconds', 6720));
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
      final felt = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') felt.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.tap(find.byKey(const ValueKey('run.session.next')));
      await settle(tester);
      expect(felt, contains('HapticFeedbackType.heavyImpact'));
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

    testWidgets(
        'build your own: saved on the phone, there next time, deleted; run with its steps',
        (tester) async {
      Future<void> openSessions() async {
        await tester.tap(find.byKey(const ValueKey('running.start')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('run.type.session')));
        await settle(tester);
      }

      Future<void> buildOne() async {
        await tester.tap(find.byKey(const ValueKey('run.session.build')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('session.build.reps.4')));
        await tester.tap(find.byKey(const ValueKey('session.build.m.800')));
        await settle(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('session.build.name')))
              .data,
          '4 × 800 m',
        );
        final save = find.byKey(const ValueKey('session.build.save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await settle(tester);
      }

      await openRunning(tester);
      await openSessions();
      await buildOne();
      expect(find.byKey(const ValueKey('run.session.mine.0')), findsOneWidget);
      // Closed and opened again: still there; then deleted.
      Navigator.of(tester.element(find.byKey(const ValueKey('run.start'))))
          .pop();
      await settle(tester);
      await openSessions();
      expect(find.byKey(const ValueKey('run.session.mine.0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('run.session.mine.delete.0')));
      await settle(tester);
      expect(find.byKey(const ValueKey('run.session.mine.0')), findsNothing);
      final c = container(tester);
      expect(await done(tester, c.read(myWorkoutsProvider.future)), isEmpty);
      // Beta 4.4 (E28): kept with the account too, and deleted there.
      await settle(tester);
      expect(api.mine, isEmpty);
      expect(api.calls, containsAll(['putMyWorkout', 'deleteMyWorkout']));

      await buildOne();
      await settle(tester);
      expect(api.mine.values.single['name'], '4 × 800 m');
      await tester.tap(find.byKey(const ValueKey('run.start')));
      await settle(tester);
      final session = c.read(runRecorderProvider)!.session!;
      expect(session.name, '4 × 800 m');
      expect(session.count, 9); // warm-up, 4 reps, 3 recoveries, cool-down
    });

    testWidgets(
        'beta 4.4 (E28): a session made offline goes up later; one from before 4.4 goes up once',
        (tester) async {
      // A session kept by 4.3 (no id) is already on the phone.
      await db.into(db.cachedJson).insert(
            CachedJsonCompanion.insert(
              key: 'running.myWorkouts.user-1',
              json: jsonEncode({
                'workouts': [
                  {
                    'name': 'Old one',
                    'steps': <Object>[],
                  },
                ],
              }),
              storedAt: '2026-10-28T00:00:00Z',
            ),
          );
      api.failWith = const Offline();
      await openRunning(tester);
      final c = container(tester);
      expect(
        (await done(tester, c.read(myWorkoutsProvider.future))).single.name,
        'Old one',
      );
      await done(
        tester,
        c.read(myWorkoutsProvider.notifier).add(
              const RunWorkout(name: 'Offline hills', steps: []),
            ),
      );
      await settle(tester);
      expect(api.mine, isEmpty);
      expect(
        c.read(myWorkoutsProvider).value!.map((w) => w.name),
        ['Offline hills', 'Old one'],
      );

      // Back online: the next read sends both, then takes the account's list.
      api.failWith = null;
      c.invalidate(myWorkoutsProvider);
      await done(tester, c.read(myWorkoutsProvider.future));
      await settle(tester);
      expect(
        api.mine.values.map((w) => w['name']).toSet(),
        {'Old one', 'Offline hills'},
      );
      expect(c.read(myWorkoutsProvider).value, hasLength(2));
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
