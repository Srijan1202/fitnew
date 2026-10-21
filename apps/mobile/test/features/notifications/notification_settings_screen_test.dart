import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/notifications/domain/notifications.dart';
import 'package:fitos/features/notifications/presentation/notification_coordinator.dart';
import 'package:fitos/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notifications.dart';

/// Phase 15 (§21): every reminder individually switchable, the tone,
/// quiet hours, what is coming up and why, a sample — and Android's
/// permission, asked for in words first.
void main() {
  late FakeNotificationsApi api;
  late FakeNotificationScheduler device;
  final nine = DateTime.utc(2026, 10, 19, 3, 30);

  setUp(() {
    SharedPreferences.setMockInitialValues(const {'notify.asked': true});
    api = FakeNotificationsApi()
      ..nextItems = [
        plannedItem(
          'a1111111-1111-4111-8111-111111111111',
          at: DateTime.utc(2026, 10, 19, 11, 30),
        ),
      ];
    device = FakeNotificationScheduler();
  });

  Widget app({double textScale = 1}) {
    final router = GoRouter(
      initialLocation: Routes.notifications,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold()),
        GoRoute(
          path: Routes.notifications,
          builder: (_, __) => const NotificationSettingsScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        userTimezoneProvider.overrideWithValue('Asia/Kolkata'),
        notificationsApiProvider.overrideWithValue(api),
        notificationSchedulerProvider.overrideWithValue(device),
        notifyClockProvider.overrideWithValue(() => nine),
        notifyProteinSourceProvider.overrideWithValue((_) async => null),
        notifyDrainedProvider.overrideWithValue(const Stream.empty()),
        pushTokenSourceProvider.overrideWithValue(() async => null),
        routerProvider.overrideWithValue(router),
      ],
      child: MaterialApp.router(
        theme: FitTheme.build(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    bool tall = true,
  }) async {
    if (tall) {
      // The list builds lazily: tall enough to hold every row.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(app(textScale: textScale));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  bool switchOn(WidgetTester tester, String k) =>
      tester.widget<SwitchListTile>(key(k)).value;
  Future<void> tapVisible(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows every kind with its own switch (§21 defaults), the tone, quiet hours and what is next, with why',
      (tester) async {
    await open(tester);
    for (final k in NotifyKind.values) {
      expect(
        switchOn(tester, 'notify.kind.${k.wire}'),
        k != NotifyKind.weighIn && k != NotifyKind.recoveryCheckin,
        reason: k.wire,
      );
    }
    expect(
      tester.widget<ChoiceChip>(key('notify.tone.cheeky')).selected,
      isTrue,
    );
    expect(
      tester.widget<Text>(key('notify.quietStart.value')).data,
      '22:30',
    );
    expect(
      tester.widget<Text>(key('notify.next.workout-reminder')).data,
      'Next: Mon 17:00',
    );
    await tester.ensureVisible(key('notify.upcoming.0'));
    expect(
      find.text('About an hour before you usually train.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'switching a kind off sends just that change and replans; the tone too',
      (tester) async {
    await open(tester);
    final plans = api.planCalls.length;
    await tapVisible(tester, 'notify.kind.protein-gap');
    expect(api.patches.last, {
      'kinds': {'protein-gap': false},
    });
    expect(switchOn(tester, 'notify.kind.protein-gap'), isFalse);
    expect(api.planCalls.length, greaterThan(plans));
    await tapVisible(tester, 'notify.tone.gentle');
    expect(api.patches.last, {'tone': 'gentle'});
    expect(
      tester.widget<Text>(key('notify.tone.description')).data,
      NotifyTone.gentle.description,
    );
  });

  testWidgets('all off hides the rest; a failed save puts the switch back',
      (tester) async {
    await open(tester);
    await tapVisible(tester, 'notify.enabled');
    expect(api.patches.last, {'enabled': false});
    expect(key('notify.kind.comeback'), findsNothing);
    api.updateFailure = const Offline();
    await tapVisible(tester, 'notify.enabled');
    expect(switchOn(tester, 'notify.enabled'), isFalse);
    expect(key('notify.error'), findsOneWidget);
  });

  testWidgets(
      'notifications blocked on the phone: said plainly, with a button that asks Android',
      (tester) async {
    device
      ..allowed = false
      ..grantOnRequest = true;
    await open(tester);
    expect(key('notify.permission'), findsOneWidget);
    await tapVisible(tester, 'notify.permission.allow');
    expect(device.requests, 1);
    expect(key('notify.permission'), findsNothing);
    expect(device.scheduled, isNotEmpty);
  });

  testWidgets('a sample: the words in your tone, shown on the phone',
      (tester) async {
    await open(tester);
    await tapVisible(tester, 'notify.sample');
    expect(api.previews, [NotifyKind.workoutReminder]);
    expect(device.shown, ['Psst. Push.']);
    expect(key('notify.sample.text'), findsOneWidget);
  });

  for (final (w, h) in [(360.0, 640.0), (411.0, 891.0)]) {
    testWidgets('${w.toInt()}×${h.toInt()} at 2x text: no overflow',
        (tester) async {
      tester.view.physicalSize = Size(w * 2, h * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      device.allowed = false;
      await open(tester, textScale: 2, tall: false);
      expect(tester.takeException(), isNull);
      final scroll = find.byKey(const ValueKey('notify.scroll'));
      await tester.drag(scroll, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
