import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Beta 6.7 (H1, owner 2026-11-27: "move progress and recovery to the home
/// page"): the Home tab has three parts, Today · Progress · Recovery, chosen
/// at the top with Training's switch. It opens on Today (Home as it was); the
/// choice holds while the app is open. Home's readiness and check-in sleep,
/// and the check-in reminder, open Recovery; the weigh-in and the weekly
/// recap open Progress. (Beta 5.9 to 6.6 had them in Nutrition, ADR-058.)
enum HomeMode { today, progress, recovery }

class HomeModeController extends Notifier<HomeMode> {
  @override
  HomeMode build() => HomeMode.today;

  void set(HomeMode mode) => state = mode;
}

final homeModeProvider = NotifierProvider<HomeModeController, HomeMode>(
  HomeModeController.new,
);
