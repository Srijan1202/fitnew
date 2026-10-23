import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_icons.dart';
import '../domain/streak_rewards.dart';

/// Beta 3.2 (ADR-027 amendment): the phone's launcher icon. Android keeps the
/// choice itself (which activity-alias is enabled, AppIcons.kt), so nothing
/// is stored here.
abstract interface class AppIconSwitcher {
  /// The icon on the launcher; null where it cannot be changed (not Android,
  /// or the channel is missing), and then the picker is hidden.
  Future<AppIcon?> current();

  Future<void> choose(AppIcon icon);
}

class DeviceAppIconSwitcher implements AppIconSwitcher {
  const DeviceAppIconSwitcher();

  static const _channel = MethodChannel('fitos/device');

  @override
  Future<AppIcon?> current() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return AppIcon.byName(await _channel.invokeMethod<String>('appIcon'));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> choose(AppIcon icon) =>
      _channel.invokeMethod<void>('setAppIcon', icon.name);
}

final appIconSwitcherProvider =
    Provider<AppIconSwitcher>((_) => const DeviceAppIconSwitcher());

class AppIconController extends AsyncNotifier<AppIcon?> {
  @override
  Future<AppIcon?> build() => ref.watch(appIconSwitcherProvider).current();

  /// False when the phone refused; the icon then stays as it was.
  Future<bool> choose(AppIcon icon) async {
    if (state.value == icon) return true;
    try {
      await ref.read(appIconSwitcherProvider).choose(icon);
    } on Object {
      return false;
    }
    state = AsyncData(icon);
    return true;
  }

  /// A premium icon goes back to Standard as soon as the app knows the user
  /// is not premium, as the premium themes do (ADR-028).
  Future<void> keepWithin({required bool premium}) async {
    if (premium) return;
    final icon = await future;
    if (icon != null && icon.premium) await choose(AppIcon.standard);
  }

  /// Beta 3.4: a streak icon this account has not earned (another account
  /// on the phone) goes back to Standard once the earned list is known.
  Future<void> keepEarned(Set<StreakReward> earned) async {
    final icon = await future;
    final reward = icon?.reward;
    if (reward != null && !earned.contains(reward)) {
      await choose(AppIcon.standard);
    }
  }
}

final appIconControllerProvider =
    AsyncNotifierProvider<AppIconController, AppIcon?>(AppIconController.new);
