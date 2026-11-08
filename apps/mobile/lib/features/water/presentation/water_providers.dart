import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../data/water_api.dart';
import '../domain/water.dart';

final waterApiProvider =
    Provider<WaterApi>((ref) => DioWaterApi(ref.watch(dioProvider)));

/// Beta 6.0 (F7, ADR-059): today's water, offline-first.
///
/// A tap changes the total on the phone at once and is kept on the phone
/// (SharedPreferences, per account) until the server has it. The phone
/// sends the day's TOTAL, never a "+250", so a send repeated after a lost
/// answer changes nothing. Sends wait [sendAfter] after the last tap, so a
/// few quick taps are one request. A total the server does not have yet is
/// sent again the next time this is built (opening the app, a new day) or
/// on the next tap.
class WaterController extends AsyncNotifier<WaterDay> {
  static const sendAfter = Duration(milliseconds: 800);

  Timer? _timer;
  late String _uid;

  String get _key => 'water.v1.$_uid';

  @override
  Future<WaterDay> build() async {
    _uid = requireSession(ref);
    final today = ref.watch(localTodayProvider);
    ref.onDispose(() => _timer?.cancel());
    final saved = await _load();
    final r = await ref.read(waterApiProvider).today();
    final WaterDay day;
    switch (r) {
      case Ok(:final value):
        if (saved != null && saved.unsynced && saved.date == value.date) {
          day = value.copyWith(ml: saved.ml, unsynced: true);
          _schedule();
        } else {
          if (saved != null && saved.unsynced) {
            // A day before today, never sent: send it, keep today's.
            unawaited(ref.read(waterApiProvider).set(saved.date, saved.ml));
          }
          day = value;
        }
      case Err(:final failure):
        if (failure is Forbidden) throw failure;
        day = saved != null && saved.date == today
            ? saved
            : WaterDay(
                date: today,
                ml: 0,
                targetMl: saved?.targetMl ?? kWaterDefaultTargetMl,
                fromWeight: saved?.fromWeight ?? false,
              );
    }
    await _save(day);
    return day;
  }

  /// Adds [deltaMl] (negative to take some off), between 0 and 10 L.
  void add(int deltaMl) {
    final cur = state.value;
    if (cur == null) return;
    final ml = (cur.ml + deltaMl).clamp(0, kWaterMaxMl);
    if (ml == cur.ml) return;
    final next = cur.copyWith(ml: ml, unsynced: true);
    state = AsyncData(next);
    unawaited(_save(next));
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(sendAfter, () => unawaited(_send()));
  }

  Future<void> _send() async {
    final cur = state.value;
    if (cur == null || !cur.unsynced) return;
    final r = await ref.read(waterApiProvider).set(cur.date, cur.ml);
    if (!ref.mounted) return;
    if (r case Ok(:final value)) {
      final now = state.value;
      // A tap while it was on its way: that newer total goes next.
      if (now == null || now.date != value.date || now.ml != value.ml) return;
      state = AsyncData(value);
      await _save(value);
    }
  }

  Future<WaterDay?> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return WaterDay.fromJson(j).copyWith(unsynced: j['unsynced'] == true);
    } on Object {
      return null;
    }
  }

  Future<void> _save(WaterDay d) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, jsonEncode({...d.toJson(), 'unsynced': d.unsynced}));
    } on Object {
      // Kept in memory only; the next tap tries again.
    }
  }
}

final waterProvider = AsyncNotifierProvider<WaterController, WaterDay>(
  WaterController.new,
  retry: (_, __) => null,
);
