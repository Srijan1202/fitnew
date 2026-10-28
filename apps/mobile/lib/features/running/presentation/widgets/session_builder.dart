import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';

/// Beta 4.1 (ADR-039 C2): build your own interval session — the reps, each
/// rep a distance or a time, at a pace from the plan's zones (or an effort
/// without a plan), the recovery jog, and a warm-up and cool-down. Pops the
/// session; the setup sheet keeps it on the phone.
class SessionBuilderSheet extends StatefulWidget {
  const SessionBuilderSheet({
    required this.zones,
    required this.unit,
    super.key,
  });

  /// The running plan's paces; null without a plan (effort words then).
  final PaceZones? zones;
  final DistanceUnit unit;

  @override
  State<SessionBuilderSheet> createState() => _SessionBuilderSheetState();
}

enum _By { distance, time }

class _SessionBuilderSheetState extends State<SessionBuilderSheet> {
  int _reps = 6;
  _By _by = _By.distance;
  int _metres = 400;
  int _seconds = 120;
  String _effort = 'interval';
  int _recover = 90;
  int _warm = 600;
  int _cool = 300;

  /// The pace zones a rep can be run at, by key.
  Map<String, (String, int)> get _paces {
    final z = widget.zones;
    if (z == null) return const {};
    return {
      'repetition': ('Repetition', z.repetition),
      'interval': ('Interval', z.interval),
      'threshold': ('Threshold', z.threshold),
    };
  }

  static const _efforts = {
    'interval': 'Hard',
    'threshold': 'Steady-hard',
    'all out': 'All out',
  };

  String get _name => _by == _By.distance
      ? '$_reps × ${_metres >= 1000 ? '${_metres / 1000} km'.replaceAll('.0 ', ' ') : '$_metres m'}'
      : '$_reps × ${_seconds ~/ 60} min';

  /// The session as the runner chose it.
  RunWorkout build_() {
    final pace = _paces[_effort];
    final effort = switch (_effort) {
      'interval' => 'hard',
      'threshold' => 'steady-hard',
      'repetition' => 'fast',
      _ => 'all out',
    };
    return RunWorkout(
      name: _name,
      steps: [
        if (_warm > 0)
          WorkoutStep(kind: StepKind.warmup, seconds: _warm, effort: 'easy'),
        for (var i = 1; i <= _reps; i++) ...[
          WorkoutStep(
            kind: StepKind.work,
            distanceM: _by == _By.distance ? _metres.toDouble() : null,
            seconds: _by == _By.time ? _seconds : null,
            pace: pace == null ? null : PaceRange(pace.$2 - 5, pace.$2 + 5),
            effort: effort,
            repIndex: i,
            repOf: _reps,
          ),
          if (i < _reps)
            WorkoutStep(
              kind: StepKind.recover,
              seconds: _recover,
              effort: 'jog',
              repIndex: i,
              repOf: _reps,
            ),
        ],
        if (_cool > 0)
          WorkoutStep(kind: StepKind.cooldown, seconds: _cool, effort: 'easy'),
      ],
    );
  }

  Widget _row<T>(
    String label,
    List<T> values,
    T current,
    ValueChanged<T> on,
    String key,
    String Function(T) word,
  ) =>
      Padding(
        padding: const EdgeInsets.only(top: FitSpacing.sm),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            for (final v in values)
              ChoiceChip(
                key: ValueKey('session.build.$key.$v'),
                label: Text(word(v)),
                selected: current == v,
                onSelected: (_) => setState(() => on(v)),
              ),
          ],
        ),
      );

  static String _min(int s) => s == 0 ? 'None' : '${s ~/ 60} min';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paces = _paces;
    final efforts = paces.isEmpty
        ? _efforts
        : {
            for (final e in paces.entries)
              e.key:
                  '${e.value.$1} ${formatPace(e.value.$2.toDouble(), widget.unit)}',
          };
    if (!efforts.containsKey(_effort)) _effort = efforts.keys.first;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('session.build.list'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('BUILD A SESSION', style: t.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text(
              _name,
              key: const ValueKey('session.build.name'),
              style: t.titleLarge,
            ),
            _row(
              'Reps',
              const [3, 4, 5, 6, 8, 10, 12],
              _reps,
              (v) => _reps = v,
              'reps',
              (v) => '$v',
            ),
            _row(
              'Each rep',
              _By.values,
              _by,
              (v) => _by = v,
              'by',
              (v) => v == _By.distance ? 'Distance' : 'Time',
            ),
            if (_by == _By.distance)
              _row(
                'Distance',
                const [200, 400, 800, 1000, 1600],
                _metres,
                (v) => _metres = v,
                'm',
                (v) => v >= 1000
                    ? '${v / 1000} km'.replaceAll('.0 ', ' ')
                    : '$v m',
              )
            else
              _row(
                'Time',
                const [60, 120, 180, 300],
                _seconds,
                (v) => _seconds = v,
                's',
                (v) => '${v ~/ 60} min',
              ),
            _row(
              paces.isEmpty ? 'Effort' : 'Pace',
              efforts.keys.toList(),
              _effort,
              (v) => _effort = v,
              'effort',
              (v) => efforts[v]!,
            ),
            _row(
              'Recover',
              const [60, 90, 120, 180],
              _recover,
              (v) => _recover = v,
              'recover',
              (v) => v % 60 == 0 ? '${v ~/ 60} min jog' : '$v s jog',
            ),
            _row(
              'Warm-up',
              const [0, 300, 600, 900],
              _warm,
              (v) => _warm = v,
              'warm',
              _min,
            ),
            _row(
              'Cool-down',
              const [0, 300, 600],
              _cool,
              (v) => _cool = v,
              'cool',
              _min,
            ),
            if (paces.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(
                  'Paced by effort. With a running plan, every rep gets your pace.',
                  style: t.bodyMedium,
                ),
              ),
            const SizedBox(height: FitSpacing.lg),
            FilledButton(
              key: const ValueKey('session.build.save'),
              onPressed: () => Navigator.of(context).pop(build_()),
              child: const Text('Save session'),
            ),
          ],
        ),
      ),
    );
  }
}
