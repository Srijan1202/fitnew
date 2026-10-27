import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/theme/tokens.dart';
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
              child: _ModeSwitch(
                mode: mode,
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

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final TrainingMode mode;
  final ValueChanged<TrainingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TrainingMode>(
        key: const ValueKey('training.mode'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: TrainingMode.gym,
            icon: Icon(Icons.fitness_center, size: 18),
            label: Text('Gym', key: ValueKey('training.mode.gym')),
          ),
          ButtonSegment(
            value: TrainingMode.running,
            icon: Icon(Icons.directions_run, size: 18),
            label: Text('Running', key: ValueKey('training.mode.running')),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? FitPalette.current.glow
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? FitBrand.carbon
                : FitColors.ink,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: FitColors.rule)),
        ),
      ),
    );
  }
}
