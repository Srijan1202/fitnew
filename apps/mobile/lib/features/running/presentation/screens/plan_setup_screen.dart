import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../training/presentation/controllers/program_controller.dart';
import '../controllers/running_providers.dart';

/// Beta 4.1 (ADR-039): choosing a running plan — the distance, where you
/// start from (a recent race, a goal time, or from zero for the 5K), the
/// days you run and which is the long one. The server builds it.
class PlanSetupScreen extends ConsumerStatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  ConsumerState<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

const _goals = {
  '5k': '5K',
  '10k': '10K',
  'half': 'Half marathon',
  'marathon': 'Marathon',
};
const _weeks = {'5k': 8, '10k': 8, 'half': 12, 'marathon': 16};
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

enum _From { race, goal, zero }

class _PlanSetupScreenState extends ConsumerState<PlanSetupScreen> {
  String _goal = '10k';
  _From _from = _From.race;
  String _raceDistance = '5k';
  final _time = TextEditingController();
  int _days = 3;
  final Set<int> _weekdays = {2, 4, 7};
  int _longRun = 7;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  /// "25:30" or "1:52:10" → seconds; null when it is not a time.
  static int? parseTime(String text) {
    final parts = text.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final n = parts.map(int.tryParse).toList();
    if (n.any((x) => x == null || x < 0)) return null;
    if (n.skip(1).any((x) => x! > 59)) return null;
    final secs =
        n.length == 2 ? n[0]! * 60 + n[1]! : n[0]! * 3600 + n[1]! * 60 + n[2]!;
    return secs > 0 ? secs : null;
  }

  void _toggleDay(int d) => setState(() {
        if (_weekdays.contains(d)) {
          if (_weekdays.length > 1) _weekdays.remove(d);
        } else {
          _weekdays.add(d);
        }
        if (!_weekdays.contains(_longRun)) {
          _longRun = _weekdays.reduce((a, b) => a > b ? a : b);
        }
      });

  Future<void> _make() async {
    if (_weekdays.length != _days) {
      setState(() => _error = 'Choose $_days days.');
      return;
    }
    final seconds = _from == _From.zero ? null : parseTime(_time.text);
    if (_from != _From.zero && seconds == null) {
      setState(() => _error = 'Type the time as mm:ss or h:mm:ss.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'goal': _goal,
      'level': _from == _From.zero ? 'beginner' : 'runner',
      'race': _from == _From.race
          ? {'distance': _raceDistance, 'seconds': seconds}
          : null,
      'goalSeconds': _from == _From.goal ? seconds : null,
      'daysPerWeek': _days,
      'weekdays': (_weekdays.toList()..sort()),
      'longRunWeekday': _longRun,
    };
    final result = await ref.read(runningApiProvider).createPlan(body);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(currentPlanProvider);
        ref.invalidate(workoutPresetsProvider);
        context.pop();
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure is Offline
              ? 'You are offline. A plan is made on the server; try again with a connection.'
              : failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gymDays = ref
            .watch(programControllerProvider)
            .value
            ?.days
            .where((d) => !d.isRest)
            .map((d) => d.dayOfWeek)
            .toSet() ??
        const <int>{};
    final overlap = _weekdays.intersection(gymDays).toList()..sort();
    final beginnerOk = _goal == '5k';
    if (!beginnerOk && _from == _From.zero) _from = _From.race;
    if (_from == _From.zero && _days != 3) _days = 3;
    Widget chip(String label, bool on, VoidCallback tap, {Key? key}) =>
        ChoiceChip(
          key: key,
          label: Text(label),
          selected: on,
          onSelected: (_) => setState(tap),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('New running plan')),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('plan.setup.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            Text('DISTANCE', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.sm,
              children: [
                for (final g in _goals.entries)
                  chip(
                    '${g.value} · ${_weeks[g.key]} weeks',
                    _goal == g.key,
                    () => _goal = g.key,
                    key: ValueKey('plan.goal.${g.key}'),
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.lg),
            Text('WHERE YOU START', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.sm,
              runSpacing: FitSpacing.sm,
              children: [
                chip(
                  'A recent race or time trial',
                  _from == _From.race,
                  () => _from = _From.race,
                  key: const ValueKey('plan.from.race'),
                ),
                chip(
                  'A goal time',
                  _from == _From.goal,
                  () => _from = _From.goal,
                  key: const ValueKey('plan.from.goal'),
                ),
                if (beginnerOk)
                  chip(
                    'From zero (run/walk)',
                    _from == _From.zero,
                    () => _from = _From.zero,
                    key: const ValueKey('plan.from.zero'),
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.sm),
            if (_from == _From.race) ...[
              Wrap(
                spacing: FitSpacing.sm,
                children: [
                  for (final g in _goals.entries)
                    chip(
                      g.value,
                      _raceDistance == g.key,
                      () => _raceDistance = g.key,
                      key: ValueKey('plan.race.${g.key}'),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.sm),
            ],
            if (_from != _From.zero)
              TextField(
                key: const ValueKey('plan.time'),
                controller: _time,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
                ],
                decoration: InputDecoration(
                  labelText: _from == _From.race
                      ? 'Your time (mm:ss or h:mm:ss)'
                      : 'Goal time for the ${_goals[_goal]}',
                  helperText: _from == _From.race
                      ? 'FITOS works out your paces from it.'
                      : 'Paces are set for this goal: be honest with yourself.',
                ),
              )
            else
              Text(
                'Eight weeks of run/walk, three days a week, up to 30 '
                'minutes of running and a 5K. No paces: run at a pace you '
                'could talk at.',
                style: t.bodyMedium,
              ),
            const SizedBox(height: FitSpacing.lg),
            Text('RUNS A WEEK', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.sm,
              children: [
                for (final n in _from == _From.zero ? [3] : [3, 4, 5])
                  chip(
                    '$n',
                    _days == n,
                    () => _days = n,
                    key: ValueKey('plan.days.$n'),
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.md),
            Text(
              'WHICH DAYS (${_weekdays.length} of $_days)',
              style: t.labelSmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    key: ValueKey('plan.day.$d'),
                    label: Text(_dayNames[d - 1]),
                    selected: _weekdays.contains(d),
                    onSelected: (_) => _toggleDay(d),
                  ),
              ],
            ),
            if (overlap.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(
                  'Gym too on ${overlap.map((d) => _dayNames[d - 1]).join(', ')}: '
                  'allowed, but a hard run and a hard gym session on one day '
                  'add up.',
                  key: const ValueKey('plan.overlap'),
                  style: t.bodyMedium?.copyWith(color: FitColors.amber),
                ),
              ),
            const SizedBox(height: FitSpacing.md),
            Text('LONG RUN ON', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: 6,
              children: [
                for (final d in (_weekdays.toList()..sort()))
                  chip(
                    _dayNames[d - 1],
                    _longRun == d,
                    () => _longRun = d,
                    key: ValueKey('plan.long.$d'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.md),
                child: Text(
                  _error!,
                  key: const ValueKey('plan.error'),
                  style: t.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
              ),
            const SizedBox(height: FitSpacing.lg),
            FilledButton(
              key: const ValueKey('plan.make'),
              onPressed: _saving ? null : _make,
              child: Text(_saving ? 'Making your plan…' : 'Make my plan'),
            ),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Starting today. Making a new plan stops the one you have; its '
              'done runs stay in your history.',
              style: t.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
