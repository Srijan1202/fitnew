import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/steps_history.dart';
import '../controllers/health_providers.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _group(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

String _dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Beta 3.6 (owner): steps day by day. **Week**: a bar a day against the
/// goal, the total, the daily average, the best day and the days at goal,
/// with arrows to the three weeks before. **4 weeks**: the average a day of
/// each week. From Health Connect on the phone; never uploaded.
class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  bool _fourWeeks = false;
  int _ago = 0;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(stepsHistoryProvider);
    final goal = ref.watch(stepGoalProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('STEPS', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: FitBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(stepsHistoryProvider.future),
            child: ListView(
              key: const ValueKey('steps.list'),
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.lg,
                FitSpacing.screen,
                FitSpacing.xl,
              ),
              children: <Widget>[
                Text('Steps', style: textTheme.displayMedium),
                const SizedBox(height: FitSpacing.md),
                SegmentedButton<bool>(
                  key: const ValueKey('steps.range'),
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment(value: false, label: Text('Week')),
                    ButtonSegment(value: true, label: Text('4 weeks')),
                  ],
                  selected: {_fourWeeks},
                  onSelectionChanged: (s) => setState(() {
                    _fourWeeks = s.first;
                    _selected = null;
                  }),
                ),
                const SizedBox(height: FitSpacing.lg),
                history.when(
                  loading: () => Text(
                    'Reading Health Connect…',
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                  error: (_, __) => Text(
                    'Could not read your steps. Pull down to try again.',
                    key: const ValueKey('steps.error'),
                    style: textTheme.bodyMedium,
                  ),
                  data: (h) => h == null
                      ? _NotConnected(
                          onConnect: () => context.push(Routes.healthData),
                        )
                      : _fourWeeks
                          ? _FourWeeks(history: h, goal: goal)
                          : _week(context, h, goal),
                ),
                const SizedBox(height: FitSpacing.lg),
                Text(
                  'From Health Connect on this phone. FITOS reads it here; it is never uploaded.',
                  style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _week(BuildContext context, StepsHistory h, int goal) {
    final textTheme = Theme.of(context).textTheme;
    final w = h.week(_ago);
    final sunday = w.monday.add(const Duration(days: 6));
    final title = switch (_ago) {
      0 => 'This week',
      1 => 'Last week',
      _ => '${_dayMonth(w.monday)} – ${_dayMonth(sunday)}',
    };
    final selected = _selected;
    final best = w.bestDay;
    final todayIndex = _ago == 0 ? w.futureFrom - 1 : null;
    String line;
    if (selected != null && selected < w.futureFrom) {
      final v = w.days[selected];
      final day = w.monday.add(Duration(days: selected));
      line = '${_days[selected]} ${_dayMonth(day)} · '
          '${v == null ? 'no data' : '${_group(v.round())} steps'}';
    } else {
      line = w.hasData ? '${_group(w.total)} steps' : 'No steps recorded';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey('steps.earlier'),
              tooltip: 'Earlier week',
              onPressed: _ago < StepsHistory.weeks - 1
                  ? () => setState(() {
                        _ago++;
                        _selected = null;
                      })
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                title,
                key: const ValueKey('steps.title'),
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: const ValueKey('steps.later'),
              tooltip: 'Later week',
              onPressed: _ago > 0
                  ? () => setState(() {
                        _ago--;
                        _selected = null;
                      })
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Text(
          line,
          key: const ValueKey('steps.line'),
          style: textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FitSpacing.md),
        _Bars(
          keyPrefix: 'steps.day',
          values: w.days,
          labels: _days,
          comingFrom: w.futureFrom,
          goal: goal,
          highlight: todayIndex,
          selected: selected,
          onTap: (i) => setState(() => _selected = _selected == i ? null : i),
        ),
        const SizedBox(height: FitSpacing.lg),
        _Stats(
          items: <(String, String, String)>[
            ('steps.total', 'Total', _group(w.total)),
            (
              'steps.average',
              'Daily average',
              w.average == null ? '—' : _group(w.average!),
            ),
            (
              'steps.best',
              'Best day',
              best == null
                  ? '—'
                  : '${_days[best]} · ${_group(w.days[best]!.round())}',
            ),
            (
              'steps.atGoal',
              'Days at goal',
              '${w.daysAtGoal(goal)} of ${w.daysSoFar}',
            ),
          ],
        ),
      ],
    );
  }
}

class _FourWeeks extends StatelessWidget {
  const _FourWeeks({required this.history, required this.goal});

  final StepsHistory history;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Oldest first, this week last.
    final weeks = [
      for (var ago = StepsHistory.weeks - 1; ago >= 0; ago--) history.week(ago),
    ];
    final averages = [for (final w in weeks) w.average?.toDouble()];
    final now = weeks.last.average;
    final before = weeks[weeks.length - 2].average;
    final change = now == null || before == null ? null : now - before;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          now == null ? 'No steps this week yet' : '${_group(now)} a day',
          key: const ValueKey('steps.line'),
          style: textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (change != null)
          Text(
            change == 0
                ? 'The same as last week'
                : '${change > 0 ? '+' : '−'}${_group(change.abs())} on last week',
            key: const ValueKey('steps.change'),
            style: textTheme.bodyMedium?.copyWith(
              color: change >= 0 ? FitColors.pine : FitColors.ink60,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: FitSpacing.md),
        _Bars(
          keyPrefix: 'steps.week',
          values: averages,
          labels: [for (final w in weeks) _dayMonth(w.monday)],
          comingFrom: weeks.length,
          goal: goal,
          highlight: weeks.length - 1,
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'The average a day of each week, from Monday; this week so far.',
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Bars against the goal line: at goal in pine, under it in ink; a day
/// with no data is a dash, a day still to come is empty.
class _Bars extends StatelessWidget {
  const _Bars({
    required this.keyPrefix,
    required this.values,
    required this.labels,
    required this.comingFrom,
    required this.goal,
    this.highlight,
    this.selected,
    this.onTap,
  });

  final String keyPrefix;
  final List<double?> values;
  final List<String> labels;

  /// The first bar still to come.
  final int comingFrom;
  final int goal;
  final int? highlight;
  final int? selected;
  final ValueChanged<int>? onTap;

  static const double _height = 160;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = [
      goal.toDouble(),
      ...values.whereType<double>(),
    ].reduce((a, b) => a > b ? a : b);
    final scale = _height / (top * 1.1);
    final goalY = goal * scale;
    return SizedBox(
      height: _height + 28,
      child: Stack(
        children: <Widget>[
          // The goal line, labelled.
          Positioned(
            left: 0,
            right: 0,
            bottom: 28 + goalY,
            child: Container(
              key: ValueKey('$keyPrefix.goal'),
              height: 1,
              color: FitColors.ink35,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 28 + goalY + 2,
            child: Text(
              'Goal ${_group(goal)}',
              style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: InkWell(
                    key: ValueKey('$keyPrefix.$i'),
                    onTap: onTap == null || i >= comingFrom
                        ? null
                        : () => onTap!(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        _bar(i, scale),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 22,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: i == highlight
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: i == highlight
                                    ? FitColors.ink
                                    : FitColors.ink60,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(int i, double scale) {
    final v = values[i];
    if (i >= comingFrom) return const SizedBox(height: 0);
    if (v == null) {
      return Container(
        key: ValueKey('$keyPrefix.$i.none'),
        width: 18,
        height: 2,
        color: FitColors.ink35,
      );
    }
    final color = i == selected
        ? FitColors.accent
        : v >= goal
            ? FitColors.pine
            : FitColors.ink60;
    return Container(
      key: ValueKey('$keyPrefix.$i.bar'),
      width: 22,
      height: (v * scale).clamp(2, _height).toDouble(),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.items});

  final List<(String, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: FitSpacing.lg,
      runSpacing: FitSpacing.md,
      children: <Widget>[
        for (final (key, label, value) in items)
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
                ),
                Text(value, key: ValueKey(key), style: textTheme.titleMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('steps.notConnected'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Connect Health Connect and allow steps to see them day by day.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: FitSpacing.md),
        FilledButton(
          key: const ValueKey('steps.connect'),
          onPressed: onConnect,
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
