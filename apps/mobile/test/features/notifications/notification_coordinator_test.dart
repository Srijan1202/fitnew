import 'dart:async';
import 'dart:convert';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/notifications/activity_signal.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/notifications/data/notification_scheduler.dart';
import 'package:fitos/features/notifications/domain/notifications.dart';
import 'package:fitos/features/notifications/presentation/notification_coordinator.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notifications.dart';

/// Phase 15 (ADR-021) — the phone side of the reminders: the server's plan
/// goes on the device; what the user does cancels the reminders it makes
/// pointless, at once and offline; outcomes go back with the next request;
/// a tap opens the right screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationsApi api;
  late FakeNotificationScheduler device;
  late DateTime now;
  late double? proteinToday;
  late StreamController<void> drained;
  late GoRouter router;

  // 09:00 IST, Monday 2026-10-19.
  final nine = DateTime.utc(2026, 10, 19, 3, 30);

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    api = FakeNotificationsApi();
    device = FakeNotificationScheduler();
    now = nine;
    proteinToday = null;
    drained = StreamController<void>.broadcast();
    router = GoRouter(
      initialLocation: '/',
      routes: [
        for (final p in [
          Routes.today,
          Routes.plan,
          Routes.progress,
          Routes.nutrition,
        ])
          GoRoute(path: p, builder: (_, __) => const SizedBox()),
        GoRoute(
          path: Routes.foodLog,
          builder: (_, s) {
            final t = s.extra! as LogTarget;
            return Text('LOG ${t.date} ${t.slot.wire}');
          },
        ),
      ],
    );
  });
  tearDown(() => drained.close());

  ProviderContainer container({String? user = 'user-1'}) {
    final c = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue(user),
        userTimezoneProvider.overrideWithValue('Asia/Kolkata'),
        notificationsApiProvider.overrideWithValue(api),
        notificationSchedulerProvider.overrideWithValue(device),
        notifyClockProvider.overrideWithValue(() => now),
        notifyProteinSourceProvider
            .overrideWithValue((_) async => proteinToday),
        notifyDrainedProvider.overrideWithValue(drained.stream),
        pushTokenSourceProvider.overrideWithValue(() async => 'fcm-token-1'),
        routerProvider.overrideWithValue(router),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<NotificationCoordinator> started(ProviderContainer c) async {
    c.read(notificationCoordinatorProvider);
    await pumpEventQueue();
    return c.read(notificationCoordinatorProvider.notifier);
  }

  final workout = plannedItem(
    'a1111111-1111-4111-8111-111111111111',
    at: DateTime.utc(2026, 10, 19, 11, 30),
    cancelOn: const [
      CancelRule(event: 'workout-started', localDate: '2026-10-19'),
    ],
  );
  final protein = plannedItem(
    'b2222222-2222-4222-8222-222222222222',
    kind: 'protein-gap',
    screen: 'food-log',
    at: DateTime.utc(2026, 10, 19, 13, 30),
    cancelOn: const [
      CancelRule(event: 'protein-reached', localDate: '2026-10-19', grams: 90),
    ],
  );
  final streak = plannedItem(
    'c3333333-3333-4333-8333-333333333333',
    kind: 'streak-at-risk',
    screen: 'today',
    localDate: '2026-10-20',
    at: DateTime.utc(2026, 10, 20, 15, 30),
    cancelOn: const [
      CancelRule(event: 'any-activity', localDate: '2026-10-20'),
    ],
  );
  final comeback = plannedItem(
    'd4444444-4444-4444-8444-444444444444',
    kind: 'comeback',
    screen: 'today',
    localDate: '2026-10-21',
    at: DateTime.utc(2026, 10, 21, 7),
    cancelOn: const [
      CancelRule(event: 'app-opened', localDate: '2026-10-19'),
    ],
  );

  test(
      'on sign-in: the plan is fetched and put on the device; the FCM token is registered; nothing without a session',
      () async {
    api.nextItems = [workout, protein];
    await started(container());
    expect(api.planCalls, hasLength(1));
    expect(device.scheduled.keys, {workout.id, protein.id});
    expect(api.tokens, ['fcm-token-1']);

    final signedOut = FakeNotificationsApi();
    api = signedOut;
    await started(container(user: null));
    expect(signedOut.planCalls, isEmpty);
  });

  test(
      'a new plan replaces the old one on the device; a past item is reported as delivered next time, once',
      () async {
    api.nextItems = [workout, protein];
    final c = container();
    final n = await started(c);
    api.nextItems = [protein];
    now = DateTime.utc(2026, 10, 19, 12); // after the workout reminder
    await n.refresh();
    // (Already shown reminders are left alone on the device.)
    expect(
      device.scheduled.values.where((i) => i.at.isAfter(now)).map((i) => i.id),
      [protein.id],
    );
    final reported = api.planCalls.last;
    expect(
      reported.map((e) => '${e.id}:${e.event}'),
      ['${workout.id}:delivered'],
    );
    await n.refresh();
    expect(api.planCalls.last, isEmpty);
  });

  test(
      'doing the thing cancels its reminder at once, offline too, and is reported; other days stay',
      () async {
    api.nextItems = [workout, protein, streak];
    final n = await started(container());
    api.planFailure = const Offline();
    await n.onActivity(
      Activity(ActivityKind.workoutStarted, DateTime.utc(2026, 10, 19, 4)),
    );
    expect(device.scheduled.keys, {protein.id, streak.id});
    // Any activity on the 20th clears that evening's streak saver.
    await n.onActivity(
      Activity(ActivityKind.foodLogged, DateTime.utc(2026, 10, 20, 7)),
    );
    expect(device.scheduled.keys, {protein.id});
    api.planFailure = null;
    await n.refresh();
    expect(
      api.planCalls.last.map((e) => '${e.id}:${e.event}').toSet(),
      {'${workout.id}:cancelled', '${streak.id}:cancelled'},
    );
  });

  test('protein on track: once the food queue delivers, the protein nudge goes',
      () async {
    api.nextItems = [protein];
    final n = await started(container());
    proteinToday = 60;
    await n.checkProtein();
    expect(device.scheduled.keys, {protein.id});
    proteinToday = 92;
    drained.add(null);
    await pumpEventQueue();
    expect(device.scheduled, isEmpty);
    expect(n.cancelled, {protein.id});
  });

  test(
      'offline: opening the app still cancels the comeback reminders; the plan on the device stays',
      () async {
    api.nextItems = [workout, comeback];
    final cc = container();
    final n = await started(cc);
    expect(device.scheduled.keys, {workout.id, comeback.id});
    api.planFailure = const Offline();
    await n.refresh();
    expect(device.scheduled.keys, {workout.id});
    expect(cc.read(notificationCoordinatorProvider).failure, isA<Offline>());
  });

  test(
      'permission: asked once by itself; refused means nothing is scheduled and nothing reported delivered',
      () async {
    device
      ..allowed = false
      ..grantOnRequest = false;
    api.nextItems = [workout];
    final c = container();
    final n = await started(c);
    expect(device.requests, 1);
    expect(device.scheduled, isEmpty);
    expect(c.read(notificationCoordinatorProvider).permitted, isFalse);
    now = DateTime.utc(2026, 10, 19, 12);
    await n.refresh();
    expect(device.requests, 1, reason: 'not asked again by itself');
    expect(
      api.planCalls.last,
      isEmpty,
      reason: 'never shown, so not delivered',
    );
    device.grantOnRequest = true;
    expect(await n.askPermission(), isTrue);
    expect(device.scheduled.keys, {workout.id});
  });

  testWidgets(
      'a tap: reported opened (not delivered as well) and opens its screen; the protein nudge opens dinner logging',
      (tester) async {
    api.nextItems = [workout, protein];
    final cc = container();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: cc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    late NotificationCoordinator n;
    await tester.runAsync(() async => n = await started(cc));
    await tester.runAsync(
      () => n.onTap(NotificationScheduler.payloadOf(protein)),
    );
    await tester.pumpAndSettle();
    expect(find.text('LOG 2026-10-19 dinner'), findsOneWidget);
    await tester.runAsync(
      () => n.onTap(NotificationScheduler.payloadOf(workout)),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      Routes.plan,
    );
    now = DateTime.utc(2026, 10, 20, 3);
    await tester.runAsync(n.refresh);
    expect(
      api.planCalls.last.map((e) => '${e.id}:${e.event}').toSet(),
      {'${protein.id}:opened', '${workout.id}:opened'},
    );
  });

  test('the plan and pending reports survive a restart', () async {
    api.nextItems = [workout];
    await started(container());
    api.planFailure = const Offline();
    final second = await started(container());
    await second.onActivity(
      Activity(ActivityKind.workoutStarted, DateTime.utc(2026, 10, 19, 4)),
    );
    api.planFailure = null;
    final third = await started(container());
    expect(third.cancelled, isEmpty, reason: 'a new plan replaced it');
    expect(
      api.planCalls.last.map((e) => '${e.id}:${e.event}'),
      ['${workout.id}:cancelled'],
    );
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('notify.plan.user-1')!)
        as Map<String, dynamic>;
    expect(stored['pending'], isEmpty);
  });
}
