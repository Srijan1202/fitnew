import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/location_source.dart';
import '../../domain/race.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';
import '../widgets/session_builder.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';

/// Beta 4.0 (ADR-038): starting a run — choose the kind and the goal, get
/// location (and, once, the battery setting), then the live screen.

/// Opens the setup sheet and, on Start, starts the run.
Future<void> startRunFlow(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<RunChoice>(
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
  final RunChoice(:kind, :goal, :workout) = choice;
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
  await recorder.start(kind: kind, goal: goal, workout: workout);
  if (context.mounted) await context.push(Routes.runLive);
}

/// What the setup sheet chose.
class RunChoice {
  const RunChoice(this.kind, this.goal, [this.workout]);

  final RunKind kind;
  final RunGoal goal;

  /// Beta 4.1: a session or sprints; null for a steady run.
  final RunWorkout? workout;
}

/// Beta 4.1 (ADR-039): a sprint session — warm-up, [count] reps of
/// [distanceM] all out from a standing start, [restSeconds] standing between,
/// cool-down. Built from the runner's three choices (no rule to apply).
RunWorkout sprintSession(int count, int distanceM, int restSeconds) {
  final steps = <WorkoutStep>[
    const WorkoutStep(kind: StepKind.warmup, seconds: 600, effort: 'easy'),
    for (var i = 1; i <= count; i++) ...[
      WorkoutStep(
        kind: StepKind.work,
        distanceM: distanceM.toDouble(),
        effort: 'all out',
        repIndex: i,
        repOf: count,
      ),
      if (i < count)
        WorkoutStep(
          kind: StepKind.recover,
          seconds: restSeconds,
          effort: 'stand',
          repIndex: i,
          repOf: count,
        ),
    ],
    const WorkoutStep(kind: StepKind.cooldown, seconds: 300, effort: 'easy'),
  ];
  return RunWorkout(name: 'Sprints: $count × $distanceM m', steps: steps);
}

enum _Type { steady, session, sprints }

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

/// Beta 4.1: starts the plan's run (its session, its targets) after the same
/// location and battery checks as any outdoor run.
Future<void> startPlannedRun(
  BuildContext context,
  WidgetRef ref,
  PlannedRun planned,
) async {
  final recorder = ref.read(runRecorderProvider.notifier);
  if (ref.read(runRecorderProvider) != null) {
    await context.push(Routes.runLive);
    return;
  }
  final access = await recorder.access();
  if (!context.mounted) return;
  if (access != LocationAccess.granted) {
    await _explainLocation(context, ref, access);
    return;
  }
  await _askBatteryOnce(context, ref);
  if (!context.mounted) return;
  // Beta 4.9 (owner): the plan's race is run in race mode — its distance at
  // its race pace, even splits.
  final raceTarget = planned.kind == 'race' && planned.distanceM != null
      ? planned.seconds ??
          (planned.pace == null
              ? null
              : (planned.distanceM! / 1000 * planned.pace!.middle).round())
      : null;
  final goal = planned.structured
      ? const RunGoal.free()
      : raceTarget != null
          ? RunGoal.race(planned.distanceM!.round(), raceTarget, RaceSplit.even)
          : planned.distanceM != null
              ? RunGoal(RunGoalKind.distance, planned.distanceM!.round())
              : planned.seconds != null
                  ? RunGoal(RunGoalKind.time, planned.seconds)
                  : const RunGoal.free();
  await recorder.start(kind: RunKind.outdoor, goal: goal, planned: planned);
  if (context.mounted) await context.push(Routes.runLive);
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
  _Type _type = _Type.steady;
  String? _presetId;
  int _reps = 6;
  int _sprintM = 100;
  int _rest = 120;
  RunGoalKind _goal = RunGoalKind.free;
  double _distanceUnits = 5;
  int _minutes = 30;
  int _paceSeconds = 360;

  static const _distances = [1.0, 3.0, 5.0, 10.0, 21.1, 42.2];
  static const _times = [10, 20, 30, 45, 60, 90];

  /// Beta 4.9 (owner): race mode — the distance, a target time, the split.
  static const _races = {
    5000: '5K',
    10000: '10K',
    21097: 'Half',
    42195: 'Marathon',
  };
  static const _raceDefaults = {
    5000: 1800,
    10000: 3900,
    21097: 8100,
    42195: 17100,
  };
  int _raceM = 5000;
  RaceSplit _split = RaceSplit.even;
  final _raceH = TextEditingController(text: '0');
  final _raceMin = TextEditingController(text: '30');
  final _raceS = TextEditingController(text: '0');

  int get _raceSeconds {
    final s = (int.tryParse(_raceH.text) ?? 0) * 3600 +
        (int.tryParse(_raceMin.text) ?? 0) * 60 +
        (int.tryParse(_raceS.text) ?? 0);
    return s >= 120 ? s : _raceDefaults[_raceM]!;
  }

  void _pickRace(int metres) {
    final t = _raceDefaults[metres]!;
    _raceM = metres;
    _raceH.text = '${t ~/ 3600}';
    _raceMin.text = '${(t % 3600) ~/ 60}';
    _raceS.text = '${t % 60}';
  }

  @override
  void dispose() {
    _raceH.dispose();
    _raceMin.dispose();
    _raceS.dispose();
    super.dispose();
  }

  RunGoal _goalValue(DistanceUnit unit) => switch (_goal) {
        RunGoalKind.free => const RunGoal.free(),
        RunGoalKind.distance =>
          RunGoal(_goal, (_distanceUnits * unit.metres).round()),
        RunGoalKind.time => RunGoal(_goal, _minutes * 60),
        // Kept per km on the wire.
        RunGoalKind.pace =>
          RunGoal(_goal, (_paceSeconds * 1000 / unit.metres).round()),
        RunGoalKind.race => RunGoal.race(_raceM, _raceSeconds, _split),
      };

  /// The chosen session: a ready-made one, or (`mine:<i>`) one of yours.
  RunWorkout? get _preset {
    final id = _presetId;
    if (id == null) return null;
    if (id.startsWith('mine:')) {
      final mine = ref.read(myWorkoutsProvider).value ?? const [];
      final i = int.tryParse(id.substring(5));
      return i == null || i >= mine.length ? null : mine[i];
    }
    final presets = ref.read(workoutPresetsProvider).value?.presets;
    if (presets == null) return null;
    for (final p in presets) {
      if (p.id == id) return p.workout;
    }
    return null;
  }

  Future<void> _build(BuildContext context) async {
    final w = await showModalBottomSheet<RunWorkout>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SessionBuilderSheet(
        zones: ref.read(workoutPresetsProvider).value?.zones,
        unit: ref.read(runSettingsProvider).unit,
      ),
    );
    if (w == null || !mounted) return;
    final i = await ref.read(myWorkoutsProvider.notifier).add(w);
    if (mounted) setState(() => _presetId = 'mine:$i');
  }

  /// Beta 4.9: the race's distance, target time and split, with its pacing.
  List<Widget> _raceSetup(BuildContext context, DistanceUnit unit) {
    final t = Theme.of(context).textTheme;
    Widget box(TextEditingController c, String label, String key) => Expanded(
          child: TextField(
            key: ValueKey(key),
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: label, hintText: '0'),
            onChanged: (_) => setState(() {}),
          ),
        );
    final plan = RacePlan(
      distanceM: _raceM.toDouble(),
      targetSeconds: _raceSeconds,
      split: _split,
    );
    String pace(double secPerKm) =>
        '${formatPace(secPerKm, unit)} ${unit.paceLabel}';
    return [
      Wrap(
        spacing: FitSpacing.sm,
        runSpacing: FitSpacing.sm,
        children: [
          for (final e in _races.entries)
            ChoiceChip(
              key: ValueKey('run.goal.race.${e.key}'),
              label: Text(e.value),
              selected: _raceM == e.key,
              onSelected: (_) => setState(() => _pickRace(e.key)),
            ),
        ],
      ),
      const SizedBox(height: FitSpacing.md),
      Text('TARGET TIME', style: t.labelSmall),
      const SizedBox(height: FitSpacing.xs),
      Row(
        children: [
          box(_raceH, 'Hours', 'run.goal.race.h'),
          const SizedBox(width: FitSpacing.sm),
          box(_raceMin, 'Min', 'run.goal.race.m'),
          const SizedBox(width: FitSpacing.sm),
          box(_raceS, 'Sec', 'run.goal.race.s'),
        ],
      ),
      const SizedBox(height: FitSpacing.md),
      SegmentedButton<RaceSplit>(
        key: const ValueKey('run.goal.race.split'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: RaceSplit.even, label: Text('Even')),
          ButtonSegment(value: RaceSplit.negative, label: Text('Negative')),
        ],
        selected: {_split},
        onSelectionChanged: (s) => setState(() => _split = s.single),
      ),
      const SizedBox(height: FitSpacing.sm),
      Text(
        _split == RaceSplit.even
            ? 'Even: ${pace(plan.evenPace)} the whole way.'
            : 'Negative: ${pace(plan.paceAt(0))} for the first half, '
                '${pace(plan.paceAt(plan.distanceM))} for the second.',
        key: const ValueKey('run.goal.race.plan'),
        style: t.bodyMedium,
      ),
    ];
  }

  RunChoice _choice(DistanceUnit unit) => switch (_type) {
        _Type.steady => RunChoice(_kind, _goalValue(unit)),
        _Type.session =>
          RunChoice(RunKind.outdoor, const RunGoal.free(), _preset),
        _Type.sprints => RunChoice(
            RunKind.outdoor,
            const RunGoal.free(),
            sprintSession(_reps, _sprintM, _rest),
          ),
      };

  List<Widget> _sessions(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(workoutPresetsProvider);
    final presets = async.value?.presets;
    final mine = ref.watch(myWorkoutsProvider).value ?? const <RunWorkout>[];
    return [
      const SizedBox(height: FitSpacing.md),
      if (presets == null)
        Text(
          async.isLoading
              ? 'Loading the sessions…'
              : 'The ready-made sessions need a connection the first time. '
                  'Yours are on this phone.',
          style: t.bodyMedium,
        )
      else if (async.value?.zones == null)
        Padding(
          padding: const EdgeInsets.only(bottom: FitSpacing.sm),
          child: Text(
            'Paced by effort. With a running plan, every rep gets your pace.',
            style: t.bodyMedium,
          ),
        ),
      RadioGroup<String>(
        groupValue: _presetId,
        onChanged: (v) => setState(() => _presetId = v),
        child: Column(
          children: [
            for (final p in presets ?? const <WorkoutPreset>[])
              RadioListTile<String>(
                key: ValueKey('run.session.${p.id}'),
                value: p.id,
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(p.about),
              ),
            for (var i = 0; i < mine.length; i++)
              RadioListTile<String>(
                key: ValueKey('run.session.mine.$i'),
                value: 'mine:$i',
                contentPadding: EdgeInsets.zero,
                title: Text(mine[i].name),
                subtitle: const Text('Yours'),
                secondary: IconButton(
                  key: ValueKey('run.session.mine.delete.$i'),
                  tooltip: 'Delete this session',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (_presetId?.startsWith('mine:') ?? false) {
                      setState(() => _presetId = null);
                    }
                    await ref.read(myWorkoutsProvider.notifier).removeAt(i);
                  },
                ),
              ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('run.session.build'),
          onPressed: () => _build(context),
          icon: const Icon(Icons.add),
          label: const Text('Build your own'),
        ),
      ),
    ];
  }

  List<Widget> _sprints(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget row(
      String label,
      List<int> values,
      int current,
      ValueChanged<int> on,
      String key,
      String Function(int) word,
    ) =>
        Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 56, child: Text(label, style: t.bodyMedium)),
              for (final v in values)
                ChoiceChip(
                  key: ValueKey('run.sprint.$key.$v'),
                  label: Text(word(v)),
                  selected: current == v,
                  onSelected: (_) => setState(() => on(v)),
                ),
            ],
          ),
        );
    return [
      row(
        'Reps',
        const [4, 6, 8, 10],
        _reps,
        (v) => _reps = v,
        'reps',
        (v) => '$v',
      ),
      row(
        'Distance',
        const [60, 100, 200, 400],
        _sprintM,
        (v) => _sprintM = v,
        'm',
        (v) => '$v m',
      ),
      row(
        'Rest',
        const [60, 90, 120, 180],
        _rest,
        (v) => _rest = v,
        'rest',
        (v) => v % 60 == 0 ? '${v ~/ 60} min' : '$v s',
      ),
      Padding(
        padding: const EdgeInsets.only(top: FitSpacing.sm),
        child: Text(
          'Stand still for the countdown; each rep starts on Go. Phone GPS is '
          'good to a few metres, so a 100 m time can be half a second out; '
          '400 m is far closer.',
          style: t.bodyMedium,
        ),
      ),
    ];
  }

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
          Text('RUN', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: FitSpacing.sm,
            children: [
              chip(
                'Steady',
                _Type.steady,
                _type,
                (v) => _type = v,
                key: const ValueKey('run.type.steady'),
              ),
              chip(
                'Session',
                _Type.session,
                _type,
                (v) {
                  _type = v;
                  _kind = RunKind.outdoor;
                },
                key: const ValueKey('run.type.session'),
              ),
              chip(
                'Sprints',
                _Type.sprints,
                _type,
                (v) {
                  _type = v;
                  _kind = RunKind.outdoor;
                },
                key: const ValueKey('run.type.sprints'),
              ),
            ],
          ),
          if (_type == _Type.session) ..._sessions(context),
          if (_type == _Type.sprints) ..._sprints(context),
          if (_type == _Type.steady) ...[
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
                      RunGoalKind.race => 'Race',
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
            if (_goal == RunGoalKind.race) ..._raceSetup(context, unit),
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
          ],
          const SizedBox(height: FitSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('run.start'),
            onPressed: _type == _Type.session && _preset == null
                ? null
                : () => Navigator.of(context).pop(_choice(unit)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
