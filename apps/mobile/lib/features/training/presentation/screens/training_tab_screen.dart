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

/// Owner 2026-10-30: the thin segmented bar became a bold switch like the tab
/// bar: a 52 px track (the bar's canvas, edge and glow), the chosen half a
/// solid block in the accent, with the buttons' corners, that slides across.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final TrainingMode mode;
  final ValueChanged<TrainingMode> onChanged;

  static const _height = 52.0;
  static const _inset = 4.0;
  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final glass = FitPalette.current.glass;
    // The chosen half has the app's button corners (FitRadius.small, owner
    // 2026-10-30: a full pill was too round); the track follows it out.
    final radius = FitRadius.small.x + _inset;
    return Container(
      key: const ValueKey('training.mode'),
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: FitColors.paper.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: FitColors.rule),
        boxShadow: glass
            ? <BoxShadow>[
                BoxShadow(
                  color: FitPalette.current.glow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            alignment: mode == TrainingMode.gym
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: _duration,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                key: const ValueKey('training.mode.thumb'),
                decoration: BoxDecoration(
                  color: FitColors.accent,
                  borderRadius: BorderRadius.circular(radius - _inset),
                ),
              ),
            ),
          ),
          // The full height of the track, so each label sits in its middle.
          Positioned.fill(
            child: Row(
              children: <Widget>[
                _Segment(
                  label: 'Gym',
                  icon: Icons.fitness_center,
                  on: mode == TrainingMode.gym,
                  radius: radius - _inset,
                  onTap: () => onChanged(TrainingMode.gym),
                  textKey: const ValueKey('training.mode.gym'),
                ),
                _Segment(
                  label: 'Running',
                  icon: Icons.directions_run,
                  on: mode == TrainingMode.running,
                  radius: radius - _inset,
                  onTap: () => onChanged(TrainingMode.running),
                  textKey: const ValueKey('training.mode.running'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.on,
    required this.radius,
    required this.onTap,
    required this.textKey,
  });

  final String label;
  final IconData icon;
  final bool on;
  final double radius;
  final VoidCallback onTap;
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: on ? null : onTap,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: on ? FitColors.onAccent : FitColors.ink60,
              ),
              duration: _ModeSwitch._duration,
              builder: (_, colour, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 20, color: colour),
                  const SizedBox(width: FitSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      key: textKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style?.copyWith(
                        color: colour,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
