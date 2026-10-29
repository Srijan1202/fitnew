import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/premium/domain/streak_rewards.dart';
import 'package:fitos/features/running/domain/efforts.dart';
import 'package:fitos/features/premium/presentation/rewards_providers.dart';

/// Beta 3.4: a scripted `GET /v1/user/rewards`; nothing earned unless a test
/// says, and `offline` answers as unreachable.
class FakeRewardsApi implements RewardsApi {
  FakeRewardsApi([Set<StreakReward>? rewards])
      : rewards = rewards ?? <StreakReward>{};

  Set<StreakReward> rewards;
  bool offline = false;

  @override
  Future<Result<Set<StreakReward>>> earned() async =>
      offline ? const Err(Offline()) : Ok({...rewards});

  /// Beta 4.2: the running distance firsts earned, with their days.
  Map<RunBadge, DateTime> badgesEarned = {};

  @override
  Future<Result<Map<RunBadge, DateTime>>> badges() async =>
      offline ? const Err(Offline()) : Ok({...badgesEarned});
}
