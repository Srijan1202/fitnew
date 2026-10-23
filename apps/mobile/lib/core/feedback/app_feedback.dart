import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta 3.2 (ADR-029 amendment): subtle sound and haptics.
///
/// One place decides what each moment sounds and feels like, so it stays
/// consistent and quiet. Sounds are two short chimes made for FITOS
/// (tool/sounds.py), played on the notification stream: they follow the
/// phone's notification volume and are silent in silent or vibrate mode.
/// Haptics go through the platform's own haptic engine and follow the
/// system haptics setting. Each can be switched off in Profile → Sounds &
/// haptics; both are on by default.
enum FeedbackEvent {
  /// A stepper or a toggle.
  tap,

  /// A set logged.
  setDone,

  /// A set that beat the previous best.
  record,

  /// 10 seconds of rest left.
  restSoon,

  /// Rest over.
  restOver,

  /// Session finished.
  sessionDone,
}

enum Chime { restOver, sessionDone }

enum Haptic { selection, light, medium, heavy }

/// What each moment does. Nothing else in the app chooses a sound.
({Haptic? haptic, Chime? chime}) feedbackFor(FeedbackEvent e) => switch (e) {
      FeedbackEvent.tap => (haptic: Haptic.selection, chime: null),
      FeedbackEvent.setDone => (haptic: Haptic.light, chime: null),
      FeedbackEvent.record => (haptic: Haptic.medium, chime: null),
      FeedbackEvent.restSoon => (haptic: Haptic.light, chime: null),
      FeedbackEvent.restOver => (haptic: Haptic.heavy, chime: Chime.restOver),
      FeedbackEvent.sessionDone => (
          haptic: Haptic.medium,
          chime: Chime.sessionDone,
        ),
    };

/// The two switches, remembered on the phone (trivial flags, §7.1).
class FeedbackSettings {
  const FeedbackSettings({this.sounds = true, this.haptics = true});
  final bool sounds;
  final bool haptics;

  FeedbackSettings copyWith({bool? sounds, bool? haptics}) => FeedbackSettings(
        sounds: sounds ?? this.sounds,
        haptics: haptics ?? this.haptics,
      );
}

class FeedbackSettingsController extends Notifier<FeedbackSettings> {
  static const _sounds = 'feedback.sounds';
  static const _haptics = 'feedback.haptics';

  @override
  FeedbackSettings build() {
    unawaited(_restore());
    return const FeedbackSettings();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = FeedbackSettings(
        sounds: p.getBool(_sounds) ?? true,
        haptics: p.getBool(_haptics) ?? true,
      );
    } on Object {
      // No storage: the defaults stand.
    }
  }

  Future<void> setSounds(bool on) async {
    state = state.copyWith(sounds: on);
    await _save(_sounds, on);
  }

  Future<void> setHaptics(bool on) async {
    state = state.copyWith(haptics: on);
    await _save(_haptics, on);
  }

  Future<void> _save(String key, bool on) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, on);
    } on Object {
      // Not remembered this time.
    }
  }
}

final feedbackSettingsProvider =
    NotifierProvider<FeedbackSettingsController, FeedbackSettings>(
  FeedbackSettingsController.new,
);

/// Where sound and haptics actually go. Tests record instead.
abstract class FeedbackOutput {
  Future<void> haptic(Haptic h);
  Future<void> chime(Chime c);
}

class DeviceFeedbackOutput implements FeedbackOutput {
  AudioPlayer? _player;

  @override
  Future<void> haptic(Haptic h) async {
    try {
      switch (h) {
        case Haptic.selection:
          await HapticFeedback.selectionClick();
        case Haptic.light:
          await HapticFeedback.lightImpact();
        case Haptic.medium:
          await HapticFeedback.mediumImpact();
        case Haptic.heavy:
          await HapticFeedback.heavyImpact();
      }
    } on Object {
      // A phone without a vibrator: nothing to do.
    }
  }

  /// `flutter test` has no audio plugin; a player there only fails late.
  static final bool _underTest =
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Future<void> chime(Chime c) async {
    if (_underTest) return;
    try {
      final player = _player ??= AudioPlayer()
        ..setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              // The notification stream: muted in silent and vibrate mode.
              usageType: AndroidUsageType.notificationEvent,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
      await player.play(
        AssetSource(
          switch (c) {
            Chime.restOver => 'sounds/rest_over.wav',
            Chime.sessionDone => 'sounds/session_done.wav',
          },
        ),
      );
    } on Object {
      // No audio (or no plugin, in tests): a silent moment, never an error.
    }
  }
}

final feedbackOutputProvider =
    Provider<FeedbackOutput>((_) => DeviceFeedbackOutput());

/// `ref.read(appFeedbackProvider)(FeedbackEvent.setDone)`.
class AppFeedback {
  AppFeedback(this._settings, this._out);

  final FeedbackSettings Function() _settings;
  final FeedbackOutput _out;

  void call(FeedbackEvent e) {
    final s = _settings();
    final f = feedbackFor(e);
    if (s.haptics && f.haptic != null) unawaited(_out.haptic(f.haptic!));
    if (s.sounds && f.chime != null) unawaited(_out.chime(f.chime!));
  }
}

final appFeedbackProvider = Provider<AppFeedback>(
  (ref) => AppFeedback(
    () => ref.read(feedbackSettingsProvider),
    ref.watch(feedbackOutputProvider),
  ),
);
