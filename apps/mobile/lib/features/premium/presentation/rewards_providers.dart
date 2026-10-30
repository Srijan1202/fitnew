import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../running/domain/efforts.dart';
import '../domain/streak_rewards.dart';

/// Beta 3.4 (ADR-027 amendment): the streak rewards this account earned
/// (`GET /v1/user/rewards`). Readable while streaks are switched off, so
/// whatever was earned keeps working.
abstract class RewardsApi {
  Future<Result<Set<StreakReward>>> earned();

  /// Beta 4.2: the running distance firsts, with the day each was earned
  /// (the server sends them to build 20 and later).
  Future<Result<Map<RunBadge, DateTime>>> badges();

  /// Owner 2026-10-30: the admin unlocked every reward theme, app icon,
  /// picture and rim for this account, for testing (`unlockAll`).
  Future<Result<bool>> unlockAll();
}

class DioRewardsApi implements RewardsApi {
  DioRewardsApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<Set<StreakReward>>> earned() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/user/rewards');
      return Ok({
        for (final e in r.data!['earned'] as List<dynamic>)
          if (StreakReward.byId((e as Map<String, dynamic>)['id'] as String?)
              case final reward?)
            reward,
      });
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  @override
  Future<Result<Map<RunBadge, DateTime>>> badges() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/user/rewards');
      return Ok({
        for (final e in r.data!['earned'] as List<dynamic>)
          if (RunBadge.byId((e as Map<String, dynamic>)['id'] as String?)
              case final badge?)
            badge: DateTime.parse(e['earnedAt'] as String),
      });
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  @override
  Future<Result<bool>> unlockAll() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/user/rewards');
      return Ok(r.data!['unlockAll'] == true);
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}

final rewardsApiProvider =
    Provider<RewardsApi>((ref) => DioRewardsApi(ref.watch(dioProvider)));

/// What was earned; null while unknown (offline, loading): nothing earned is
/// then taken away, and nothing locked is opened.
final earnedRewardsProvider = FutureProvider<Set<StreakReward>?>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(rewardsApiProvider).earned();
    return r.when(ok: (s) => s, err: (_) => null);
  },
  retry: (_, __) => null,
);

/// Beta 4.2: the running distance firsts earned, with their days; null while
/// unknown (offline, loading).
final earnedBadgesProvider = FutureProvider<Map<RunBadge, DateTime>?>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(rewardsApiProvider).badges();
    return r.when(ok: (s) => s, err: (_) => null);
  },
  retry: (_, __) => null,
);

/// Owner 2026-10-30: whether the admin unlocked everything for testing;
/// null while unknown (offline, loading).
final rewardsUnlockAllProvider = FutureProvider<bool?>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(rewardsApiProvider).unlockAll();
    return r.when(ok: (v) => v, err: (_) => null);
  },
  retry: (_, __) => null,
);

/// Every reward and badge id that unlocks a theme or an icon: the ones
/// earned, or all of them when the admin unlocked everything. Null until
/// all three are known, so nothing earned is taken away meanwhile.
final earnedUnlocksProvider = Provider<Set<String>?>((ref) {
  final all = ref.watch(rewardsUnlockAllProvider).value;
  final streak = ref.watch(earnedRewardsProvider).value;
  final badges = ref.watch(earnedBadgesProvider).value;
  if (all == null || streak == null || badges == null) return null;
  if (all) {
    return {
      for (final r in StreakReward.values) r.id,
      for (final b in RunBadge.values) b.id,
    };
  }
  return {for (final r in streak) r.id, for (final b in badges.keys) b.id};
});

/// The streak rewards that can be used (pictures, the rim): the ones earned,
/// or all of them when the admin unlocked everything; null while unknown.
final unlockedRewardsProvider = Provider<Set<StreakReward>?>((ref) {
  if (ref.watch(rewardsUnlockAllProvider).value ?? false) {
    return StreakReward.values.toSet();
  }
  return ref.watch(earnedRewardsProvider).value;
});

/// True once a reward is known to be earned (badges and counts).
final rewardEarnedProvider = Provider.family<bool, StreakReward>(
  (ref, reward) =>
      ref.watch(earnedRewardsProvider).value?.contains(reward) ?? false,
);

/// True once a reward can be used: earned, or unlocked by the admin.
final rewardUnlockedProvider = Provider.family<bool, StreakReward>(
  (ref, reward) =>
      ref.watch(unlockedRewardsProvider)?.contains(reward) ?? false,
);

/// The Ember rim, on by default once earned; a switch in Profile turns it
/// off (then a premium user's gold rim shows again).
class EmberRimSetting extends Notifier<bool> {
  static const _key = 'rewards.emberRim';

  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getBool(_key) ?? true;
    } on Object {
      // No storage: the default stands.
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, on);
    } on Object {
      // The choice still applies for this run.
    }
  }
}

final emberRimSettingProvider =
    NotifierProvider<EmberRimSetting, bool>(EmberRimSetting.new);

/// Whether pictures wear the Ember rim: earned (or unlocked) and on.
final emberRimProvider = Provider<bool>(
  (ref) =>
      ref.watch(rewardUnlockedProvider(StreakReward.emberRim)) &&
      ref.watch(emberRimSettingProvider),
);
