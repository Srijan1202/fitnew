import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_mode_switch.dart';
import '../../../running/presentation/screens/running_home_screen.dart';
import 'workout_week_screen.dart';

/// Beta 4.0 (ADR-038, owner): the Training tab has two halves, Gym and
/// Running, chosen at the top. It opens on Gym; the choice holds while the
/// app is open. With the admin's `running` switch off it is the gym alone.
enum TrainingMode { gym, running }

class TrainingModeController extends Notifier<TrainingMode> {
  @override
  TrainingMode build() => TrainingMode.gym;

  void set(TrainingMode mode) => state = mode;
}

final trainingModeProvider =
    NotifierProvider<TrainingModeController, TrainingMode>(
  TrainingModeController.new,
);

class TrainingTabScreen extends ConsumerStatefulWidget {
  const TrainingTabScreen({super.key});

  @override
  ConsumerState<TrainingTabScreen> createState() => _TrainingTabScreenState();
}

class _TrainingTabScreenState extends ConsumerState<TrainingTabScreen> {
  /// Running is built the first time it is chosen, then kept (like the gym).
  bool _runningBuilt = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(featureOnProvider(AppFeature.running))) {
      return const WorkoutWeekScreen();
    }
    final mode = ref.watch(trainingModeProvider);
    if (mode == TrainingMode.running) _runningBuilt = true;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                0,
              ),
              child: FitModeSwitch<TrainingMode>(
                key: const ValueKey('training.mode'),
                thumbKey: const ValueKey('training.mode.thumb'),
                value: mode,
                halves: [
                  const FitModeHalf(
                    TrainingMode.gym,
                    'Gym',
                    Icons.fitness_center,
                    key: ValueKey('training.mode.gym'),
                  ),
                  const FitModeHalf(
                    TrainingMode.running,
                    'Running',
                    Icons.directions_run,
                    key: ValueKey('training.mode.running'),
                  ),
                ],
                onChanged: ref.read(trainingModeProvider.notifier).set,
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: mode.index,
                children: [
                  const WorkoutWeekScreen(),
                  if (_runningBuilt)
                    const RunningHomeScreen()
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
