import 'package:flutter_tts/flutter_tts.dart';

/// Beta 4.1 (ADR-039): the coach's voice — the phone's own text-to-speech,
/// so it works offline. Android lowers music while it speaks (transient
/// focus, "may duck") and brings it back after. Tests record instead.
abstract class RunVoice {
  Future<void> say(String text);
  Future<void> stop();
}

class TtsRunVoice implements RunVoice {
  TtsRunVoice() : _tts = FlutterTts();

  final FlutterTts _tts;
  Future<void>? _ready;

  Future<void> _setUp() async {
    try {
      // Indian English when the phone has it, else its default English.
      final indian = await _tts.isLanguageAvailable('en-IN');
      await _tts.setLanguage(indian == true ? 'en-IN' : 'en-US');
      await _tts.setSpeechRate(0.5);
      // Queue: a call never cuts off the one before it.
      await _tts.setQueueMode(1);
    } on Object {
      // The phone's defaults stand.
    }
  }

  @override
  Future<void> say(String text) async {
    try {
      await (_ready ??= _setUp());
      await _tts.speak(text, focus: true);
    } on Object {
      // No voice on this phone: the run carries on silently.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Nothing was speaking.
    }
  }
}
