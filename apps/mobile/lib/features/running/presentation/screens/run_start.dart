import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/location_source.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';

/// Beta 4.0 (ADR-038): starting a run — choose the kind and the goal, get
/// location (and, once, the battery setting), then the live screen.

/// Opens the setup sheet and, on Start, starts the run.
Future<void> startRunFlow(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<(RunKind, RunGoal)>(
    context: context,
    // Above the whole app: the Training tab's own navigator sits under the
    // bottom bar, which covered the sheet's Start button (beta 4.0.1).
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const RunSetupSheet(),
  );
  if (choice == null || !context.mounted) return;
  final (kind, goal) = choice;
  final recorder = ref.read(runRecorderProvider.notifier);
  if (kind == RunKind.outdoor) {
    final access = await recorder.access();
    if (!context.mounted) return;
    if (access != LocationAccess.granted) {
      await _explainLocation(context, ref, access);
      return;
    }
    await _askBatteryOnce(context, ref);
    if (!context.mounted) return;
  }
  await recorder.start(kind: kind, goal: goal);
  if (context.mounted) await context.push(Routes.runLive);
}

Future<void> _explainLocation(
  BuildContext context,
  WidgetRef ref,
  LocationAccess access,
) async {
  final source = ref.read(locationSourceProvider);
  final (title, body, action) = switch (access) {
    LocationAccess.serviceOff => (
        'Turn on location',
        'Location is off on this phone. FITOS needs it to draw your route '
            'and measure the distance.',
        source.openLocationSettings,
      ),
    LocationAccess.deniedForever => (
        'Allow location for FITOS',
        'FITOS needs your precise location while you use it to record a '
            'run. Turn it on in FITOS’s settings: Permissions → Location → '
            'Allow only while using the app.',
        source.openAppSettings,
      ),
    _ => (
        'FITOS needs your location',
        'Without it FITOS cannot draw your route or measure the distance. '
            'You can still record a treadmill run.',
        null,
      ),
  };
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('run.location.denied'),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
        if (action != null)
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              action();
            },
            child: const Text('Open settings'),
          ),
      ],
    ),
  );
}

/// Once per phone: battery saving may stop FITOS during a run.
Future<void> _askBatteryOnce(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(runSettingsProvider);
  if (settings.batteryAsked) return;
  final battery = ref.read(batteryAccessProvider);
  await ref.read(runSettingsProvider.notifier).markBatteryAsked();
  if (await battery.isUnrestricted() || !context.mounted) return;
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('run.battery'),
      title: const Text('Keep runs recording'),
      content: const Text(
        'Battery saving can stop FITOS when the screen is off, which would '
        'stop your run. In FITOS’s settings, open Battery and choose '
        'Unrestricted. You only need to do this once.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const ValueKey('run.battery.open'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
  if (open ?? false) await battery.openSettings();
}

/// The kind and the goal.
class RunSetupSheet extends ConsumerStatefulWidget {
  const RunSetupSheet({super.key});

  @override
  ConsumerState<RunSetupSheet> createState() => _RunSetupSheetState();
}

class _RunSetupSheetState extends ConsumerState<RunSetupSheet> {
  RunKind _kind = RunKind.outdoor;
  RunGoalKind _goal = RunGoalKind.free;
  double _distanceUnits = 5;
  int _minutes = 30;
  int _paceSeconds = 360;

  static const _distances = [1.0, 3.0, 5.0, 10.0, 21.1, 42.2];
  static const _times = [10, 20, 30, 45, 60, 90];

  RunGoal _goalValue(DistanceUnit unit) => switch (_goal) {
        RunGoalKind.free => const RunGoal.free(),
        RunGoalKind.distance =>
          RunGoal(_goal, (_distanceUnits * unit.metres).round()),
        RunGoalKind.time => RunGoal(_goal, _minutes * 60),
        // Kept per km on the wire.
        RunGoalKind.pace =>
          RunGoal(_goal, (_paceSeconds * 1000 / unit.metres).round()),
      };

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    Widget chip<T>(
      String label,
      T value,
      T group,
      ValueChanged<T> on, {
      Key? key,
    }) =>
        ChoiceChip(
          key: key,
          label: Text(label),
          selected: value == group,
          onSelected: (_) => setState(() => on(value)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New run', style: t.titleLarge),
          const SizedBox(height: FitSpacing.md),
          Text('WHERE', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: FitSpacing.sm,
            children: [
              chip(
                'Outdoor',
                RunKind.outdoor,
                _kind,
                (v) => _kind = v,
                key: const ValueKey('run.kind.outdoor'),
              ),
              chip(
                'Treadmill',
                RunKind.treadmill,
                _kind,
                (v) => _kind = v,
                key: const ValueKey('run.kind.treadmill'),
              ),
            ],
          ),
          if (_kind == RunKind.treadmill)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm),
              child: Text(
                'No GPS indoors: you type the distance from the treadmill at '
                'the end.',
                style: t.bodyMedium,
              ),
            ),
          const SizedBox(height: FitSpacing.lg),
          Text('GOAL', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: FitSpacing.sm,
            runSpacing: FitSpacing.sm,
            children: [
              for (final g in RunGoalKind.values)
                chip(
                  switch (g) {
                    RunGoalKind.free => 'Free run',
                    RunGoalKind.distance => 'Distance',
                    RunGoalKind.time => 'Time',
                    RunGoalKind.pace => 'Pace',
                  },
                  g,
                  _goal,
                  (v) => _goal = v,
                  key: ValueKey('run.goal.${g.name}'),
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
          if (_goal == RunGoalKind.distance)
            Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.sm,
              children: [
                for (final d in _distances)
                  chip(
                    d == 21.1
                        ? 'Half'
                        : d == 42.2
                            ? 'Marathon'
                            : '${d.toStringAsFixed(0)} ${unit.label}',
                    d,
                    _distanceUnits,
                    (v) => _distanceUnits = v,
                    key: ValueKey('run.goal.distance.$d'),
                  ),
              ],
            ),
          if (_goal == RunGoalKind.time)
            Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.sm,
              children: [
                for (final m in _times)
                  chip(
                    '$m min',
                    m,
                    _minutes,
                    (v) => _minutes = v,
                    key: ValueKey('run.goal.time.$m'),
                  ),
              ],
            ),
          if (_goal == RunGoalKind.pace)
            Row(
              children: [
                IconButton.outlined(
                  key: const ValueKey('run.goal.pace.faster'),
                  tooltip: 'Faster',
                  onPressed: _paceSeconds > 150
                      ? () => setState(() => _paceSeconds -= 5)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '${formatUnitPace(_paceSeconds.toDouble())} ${unit.paceLabel}',
                    key: const ValueKey('run.goal.pace.value'),
                    textAlign: TextAlign.center,
                    style: t.displaySmall,
                  ),
                ),
                IconButton.outlined(
                  key: const ValueKey('run.goal.pace.slower'),
                  tooltip: 'Slower',
                  onPressed: _paceSeconds < 1100
                      ? () => setState(() => _paceSeconds += 5)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          const SizedBox(height: FitSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('run.start'),
            onPressed: () =>
                Navigator.of(context).pop((_kind, _goalValue(unit))),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
