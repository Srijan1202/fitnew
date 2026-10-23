import 'package:fitos/core/feedback/app_feedback.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 3.2 (ADR-029 amendment): one mapping from moments to sound and
/// haptics; each switch turns its half off; the rest timer ticks once at 10
/// seconds left and chimes once at the end.
class RecordingOutput implements FeedbackOutput {
  final haptics = <Haptic>[];
  final chimes = <Chime>[];

  @override
  Future<void> haptic(Haptic h) async => haptics.add(h);

  @override
  Future<void> chime(Chime c) async => chimes.add(c);
}

class FixedSettings extends FeedbackSettingsController {
  FixedSettings(this.initial);
  final FeedbackSettings initial;

  @override
  FeedbackSettings build() => initial;
}

void main() {
  late RecordingOutput out;

  setUp(() => out = RecordingOutput());

  ProviderContainer container({
    FeedbackSettings settings = const FeedbackSettings(),
  }) {
    final c = ProviderContainer(
      overrides: [
        feedbackOutputProvider.overrideWithValue(out),
        feedbackSettingsProvider.overrideWith(() => FixedSettings(settings)),
        restNotifierProvider.overrideWithValue(const NoopRestNotifier()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
      'each moment: chimes only for rest over and session done; haptics light for sets, firmer for records and the end of rest',
      () {
    expect(
      feedbackFor(FeedbackEvent.tap),
      (haptic: Haptic.selection, chime: null),
    );
    expect(
      feedbackFor(FeedbackEvent.setDone),
      (haptic: Haptic.light, chime: null),
    );
    expect(
      feedbackFor(FeedbackEvent.record),
      (haptic: Haptic.medium, chime: null),
    );
    expect(
      feedbackFor(FeedbackEvent.restSoon),
      (haptic: Haptic.light, chime: null),
    );
    expect(
      feedbackFor(FeedbackEvent.restOver),
      (haptic: Haptic.heavy, chime: Chime.restOver),
    );
    expect(
      feedbackFor(FeedbackEvent.sessionDone),
      (haptic: Haptic.medium, chime: Chime.sessionDone),
    );
  });

  test('both on by default; each switch turns off only its half', () async {
    expect(const FeedbackSettings().sounds, isTrue);
    expect(const FeedbackSettings().haptics, isTrue);

    container().read(appFeedbackProvider)(FeedbackEvent.restOver);
    await Future<void>.delayed(Duration.zero);
    expect(out.haptics, [Haptic.heavy]);
    expect(out.chimes, [Chime.restOver]);

    out = RecordingOutput();
    container(settings: const FeedbackSettings(sounds: false))
        .read(appFeedbackProvider)(FeedbackEvent.restOver);
    await Future<void>.delayed(Duration.zero);
    expect(out.haptics, [Haptic.heavy]);
    expect(out.chimes, isEmpty);

    out = RecordingOutput();
    container(settings: const FeedbackSettings(haptics: false))
        .read(appFeedbackProvider)(FeedbackEvent.sessionDone);
    await Future<void>.delayed(Duration.zero);
    expect(out.haptics, isEmpty);
    expect(out.chimes, [Chime.sessionDone]);
  });

  testWidgets(
      'the rest timer: one tick at 10 s left, one chime and buzz at zero, nothing after',
      (tester) async {
    final c = container();
    var now = DateTime.utc(2026, 10, 24, 18);
    final timer = c.read(restTimerProvider.notifier)..clock = () => now;
    timer.start(const Duration(seconds: 30), exerciseName: 'Bench Press');
    for (var i = 0; i < 40; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(out.haptics, [Haptic.light, Haptic.heavy]);
    expect(out.chimes, [Chime.restOver]);
    expect(c.read(restTimerProvider)!.done, isTrue);
    timer.skip();
  });
}
