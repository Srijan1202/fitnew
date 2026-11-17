import 'package:fitos/core/notifications/rest_countdown.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every call the timer makes, for the test to read.
class RecordingRestNotifier implements RestNotifier {
  final calls = <String>[];

  @override
  Future<void> schedule(Duration inFuture, {required String body}) async =>
      calls.add('schedule ${inFuture.inSeconds} $body');

  @override
  Future<void> showCountdown(
    DateTime endsAt, {
    required String exercise,
  }) async =>
      calls.add('countdown ${endsAt.toIso8601String()} $exercise');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

/// Beta 6.4 (N2, owner Q1): the rest on the lock screen while FITOS is
/// hidden, with +15 s and Skip.
void main() {
  test('+15 s counts from the later of the end and now', () {
    final now = DateTime.utc(2026, 11, 17, 18);
    expect(
      RestCountdown.extended(now.add(const Duration(seconds: 40)), now),
      now.add(const Duration(seconds: 55)),
    );
    expect(
      RestCountdown.extended(now.subtract(const Duration(seconds: 5)), now),
      now.add(const Duration(seconds: 15)),
    );
  });

  test('the countdown carries its rest; a bad one carries nothing', () {
    final at = DateTime.utc(2026, 11, 17, 18, 1, 30);
    final p = RestCountdown.readPayload(RestCountdown.payload(at, 'Squat'))!;
    expect([p.endsAt.toUtc(), p.exercise], [at, 'Squat']);
    expect(RestCountdown.readPayload('nope'), isNull);
    expect(RestCountdown.readPayload(null), isNull);
  });

  test('what an action tells the session', () {
    expect(
      RestCountdown.readMessage({'skip': true}),
      (endsAt: null, skip: true),
    );
    expect(
      RestCountdown.readMessage({'endsAt': 1000})!.endsAt,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
    expect(RestCountdown.readMessage({'endsAt': 'x'}), isNull);
    expect(RestCountdown.readMessage('x'), isNull);
  });

  test('a quiet, ongoing countdown on the lock screen with +15 s and Skip', () {
    final d = RestCountdown.countdownDetails(
      DateTime.now().add(const Duration(seconds: 60)),
    );
    expect(d.ongoing, isTrue);
    expect(d.usesChronometer, isTrue);
    expect(d.chronometerCountDown, isTrue);
    expect(d.visibility, NotificationVisibility.public);
    expect(d.importance, Importance.low);
    expect(d.actions!.map((a) => a.id), [
      RestCountdown.addAction,
      RestCountdown.skipAction,
    ]);
    expect(d.timeoutAfter, inInclusiveRange(55000, 60000));
  });

  ProviderContainer container(RecordingRestNotifier n) {
    final c = ProviderContainer(
      overrides: [
        restNotifierProvider.overrideWithValue(n),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets(
      'hidden: "Rest over" and the countdown; back: both gone (owner Q1)',
      (tester) async {
    final n = RecordingRestNotifier();
    final c = container(n);
    final now = DateTime(2026, 11, 17, 18);
    final timer = c.read(restTimerProvider.notifier)..clock = () => now;
    timer.start(const Duration(seconds: 90), exerciseName: 'Bench Press');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(n.calls, [
      'schedule 90 Next set: Bench Press',
      'countdown ${now.add(const Duration(seconds: 90)).toIso8601String()} Bench Press',
    ]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(n.calls.last, 'cancel');
    timer.skip();
  });

  testWidgets('+15 s and Skip from the lock screen reach the session',
      (tester) async {
    final n = RecordingRestNotifier();
    final c = container(n);
    final now = DateTime(2026, 11, 17, 18);
    final timer = c.read(restTimerProvider.notifier)..clock = () => now;
    timer.start(const Duration(seconds: 60), exerciseName: 'Squat');
    final later = now.add(const Duration(seconds: 75));
    timer.onAction({'endsAt': later.millisecondsSinceEpoch});
    final s = c.read(restTimerProvider)!;
    expect(s.endsAt, later);
    expect(s.total, const Duration(seconds: 75));
    expect(s.remaining, const Duration(seconds: 75));
    timer.onAction('nonsense');
    expect(c.read(restTimerProvider)!.endsAt, later);
    timer.onAction({'skip': true});
    expect(c.read(restTimerProvider), isNull);
    // Nothing to change without a rest.
    timer.onAction({'endsAt': later.millisecondsSinceEpoch});
    expect(c.read(restTimerProvider), isNull);
  });
}
