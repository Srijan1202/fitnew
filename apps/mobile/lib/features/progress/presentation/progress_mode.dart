import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Beta 5.7 (owner: "divide the progress and recovery in 2 sections same as
/// we did in gym and running"): the tab has two halves, chosen at the top
/// with Training's switch. It opens on Progress; the choice holds while the
/// app is open. Home's readiness and check-in sleep, and the check-in
/// reminder, open Recovery.
enum ProgressMode { progress, recovery }

class ProgressModeController extends Notifier<ProgressMode> {
  @override
  ProgressMode build() => ProgressMode.progress;

  void set(ProgressMode mode) => state = mode;
}

final progressModeProvider =
    NotifierProvider<ProgressModeController, ProgressMode>(
  ProgressModeController.new,
);
