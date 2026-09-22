import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../health/domain/entities/health.dart';
import '../../domain/home_context.dart';
import '../controllers/home_providers.dart';

/// Shared formatting for the Home sections. Display only.
class HomeSections {
  const HomeSections._();

  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String group(num n) {
    final s = n.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  static String hm(num minutes) {
    final m = minutes.round();
    return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }

  static String kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// "Tuesday · 22 September".
  static String longDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return '${weekdays[d.weekday - 1]} · ${d.day} ${months[d.month - 1]}';
  }

  /// "Today", "Yesterday", "18 Sep" — for a measurement's own time.
  static String recorded(String? iso, String today) {
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return '';
    final t = DateTime.tryParse(today);
    if (t == null) return '';
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final diff = DateTime(t.year, t.month, t.day).difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return 'Last recorded ${day.day} ${months[day.month - 1].substring(0, 3)}';
  }

  /// "just now", "4 min ago", "2 h ago".
  static String ago(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return 'recently';
    final d = DateTime.now().toUtc().difference(at.toUtc());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String greeting(int hour) {
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Greeting, date, a way to the profile. Compact.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.hour,
    required this.date,
    this.name,
    super.key,
  });

  final int hour;
  final String date;

  /// Null → the greeting stands alone (never "User" or a placeholder).
  final String? name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.sm,
        FitSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name == null || name!.trim().isEmpty
                      ? HomeSections.greeting(hour)
                      : '${HomeSections.greeting(hour)}, ${name!.trim()}',
                  key: const ValueKey('home.greeting'),
                  style:
                      textTheme.displayMedium?.copyWith(color: FitColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  HomeSections.longDate(date),
                  key: const ValueKey('home.date'),
                  style: textTheme.bodyLarge?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('home.profile'),
            onPressed: () => context.push(Routes.profile),
            icon: const Icon(Icons.person_outline, color: FitColors.ink),
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// While the first answers are in flight: paper2 blocks, nothing invented.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('home.skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
      child: Container(height: 160, color: FitColors.paper2),
    );
  }
}

/// A metric block: eyebrow, the number in the display face (or the
/// reason there is none), a line under it. Two per row on a hairline grid.
class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.value,
    required this.line,
    this.valueKey,
    this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final String line;
  final Key? valueKey;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FitSpacing.screen,
        vertical: FitSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text(
            value,
            key: valueKey,
            style: (muted ? textTheme.titleMedium : textTheme.displaySmall)
                ?.copyWith(color: muted ? FitColors.ink60 : FitColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            line,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.blocks});

  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < blocks.length; i += 2) {
      rows
        ..add(const Divider(color: FitColors.rule, height: 1))
        ..add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: blocks[i]),
                const VerticalDivider(color: FitColors.rule, width: 1),
                Expanded(
                  child: i + 1 < blocks.length
                      ? blocks[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
    }
    rows.add(const Divider(color: FitColors.rule, height: 1));
    return Column(children: rows);
  }
}

/// Steps · Active calories · Food · Workout.
class TodayMetrics extends StatelessWidget {
  const TodayMetrics({required this.context, super.key});

  final HomeContext context;

  @override
  Widget build(BuildContext buildContext) {
    final c = context;
    final h = c.health;
    final steps = h?.steps;
    final active = h?.activeCalories;

    // Steps.
    String stepsValue;
    String stepsLine;
    var stepsMuted = false;
    if (steps != null && steps.isAvailable) {
      final n = steps.value!.round();
      stepsValue = HomeSections.group(n);
      final pct = (n * 100 / c.stepGoal).round();
      stepsLine = '$pct% of ${HomeSections.group(c.stepGoal)}';
    } else {
      stepsValue =
          (steps?.availability ?? HealthAvailability.unsupported).blockText;
      stepsLine = c.healthUnsupported
          ? 'Health Connect is not on this phone'
          : 'Goal ${HomeSections.group(c.stepGoal)}';
      stepsMuted = true;
    }

    // Active calories.
    String kcalValue;
    String kcalLine;
    var kcalMuted = false;
    if (active != null && active.isAvailable) {
      kcalValue = '${HomeSections.group(active.value!)} kcal';
      final total = h!.totalCalories;
      kcalLine = total.isAvailable
          ? '${HomeSections.group(total.value!)} kcal in total'
          : 'Active energy today';
    } else {
      kcalValue =
          (active?.availability ?? HealthAvailability.unsupported).blockText;
      kcalLine = 'Active energy today';
      kcalMuted = true;
    }

    // Food — Phase 8 fills it; never a zero.
    final t = c.targets;
    final foodValue = c.nutrition.logged
        ? '${HomeSections.group(c.nutrition.kcal ?? 0)} / ${HomeSections.group(t?.kcal ?? 0)} kcal'
        : 'Not logged yet';
    final foodLine = t == null
        ? 'No targets yet'
        : c.nutrition.logged
            ? '${c.nutrition.proteinG ?? 0} / ${t.proteinG} g protein'
            : 'Target ${HomeSections.group(t.kcal)} kcal · ${t.proteinG} g protein';

    // Workout.
    final active0 = c.activeSession;
    final today = c.today;
    String workoutValue;
    String workoutLine;
    if (active0 != null) {
      workoutValue = active0.name;
      workoutLine = 'In progress · ${active0.workingSetsLogged} sets';
    } else if (c.completedToday != null || today?.completedSessionId != null) {
      workoutValue = c.completedToday?.name ?? today?.sessionName ?? 'Session';
      workoutLine = 'Completed';
    } else if (today == null) {
      workoutValue = '—';
      workoutLine = 'Could not load today';
    } else if (today.isRest) {
      workoutValue = 'Rest';
      workoutLine =
          today.programId == null ? 'No programme yet' : 'Nothing planned';
    } else {
      workoutValue = today.sessionName ?? 'Session';
      workoutLine = 'Ready · ${today.exercises.length} movements';
    }

    return _Grid(
      blocks: <Widget>[
        _Block(
          label: 'Steps',
          value: stepsValue,
          line: stepsLine,
          valueKey: const ValueKey('home.steps'),
          muted: stepsMuted,
          onTap: () => buildContext.push(Routes.healthData),
        ),
        _Block(
          label: 'Active calories',
          value: kcalValue,
          line: kcalLine,
          valueKey: const ValueKey('home.activeCalories'),
          muted: kcalMuted,
          onTap: () => buildContext.push(Routes.healthData),
        ),
        _Block(
          label: 'Food',
          value: foodValue,
          line: foodLine,
          valueKey: const ValueKey('home.food'),
          muted: !c.nutrition.logged,
          onTap: () => buildContext.go(Routes.nutrition),
        ),
        _Block(
          label: 'Workout',
          value: workoutValue,
          line: workoutLine,
          valueKey: const ValueKey('home.workout'),
          muted: today == null,
          onTap: () => buildContext.go(Routes.plan),
        ),
      ],
    );
  }
}

/// Sleep · Resting heart rate, or one honest line.
class RecoverySection extends StatelessWidget {
  const RecoverySection({required this.context, super.key});

  final HomeContext context;

  @override
  Widget build(BuildContext buildContext) {
    final textTheme = Theme.of(buildContext).textTheme;
    final c = context;
    final h = c.health;
    final sleep = h?.sleep;
    final rhr = h?.restingHeartRate;
    bool readable(HealthMetric? m) =>
        m != null &&
        (m.availability == HealthAvailability.available ||
            m.availability == HealthAvailability.noData ||
            m.availability == HealthAvailability.temporarilyUnavailable);
    final anyGranted = readable(sleep) || readable(rhr);
    if (!anyGranted) {
      final unsupported = c.healthUnsupported;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              unsupported
                  ? 'Recovery metrics need Health Connect, which is not on this phone.'
                  : c.healthConnected
                      ? 'Allow sleep and heart-rate data to see recovery metrics.'
                      : 'Connect Health data to see recovery metrics.',
              key: const ValueKey('home.recovery.empty'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            if (!unsupported)
              TextButton(
                key: const ValueKey('home.recovery.connect'),
                onPressed: () => buildContext.push(Routes.healthData),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Connect Health data →'),
              ),
          ],
        ),
      );
    }
    final sl = sleep!;
    final hr = rhr!;
    return _Grid(
      blocks: <Widget>[
        _Block(
          label: 'Sleep',
          value: sl.isAvailable
              ? HomeSections.hm(sl.value!)
              : sl.availability.blockText,
          line: 'Last night',
          valueKey: const ValueKey('home.sleep'),
          muted: !sl.isAvailable,
          onTap: () => buildContext.push(Routes.healthData),
        ),
        _Block(
          label: 'Resting HR',
          value: hr.isAvailable
              ? '${hr.value!.round()} bpm'
              : hr.availability.blockText,
          line: hr.isAvailable
              ? HomeSections.recorded(hr.start, c.date)
              : 'Resting heart rate',
          valueKey: const ValueKey('home.rhr'),
          muted: !hr.isAvailable,
          onTap: () => buildContext.push(Routes.healthData),
        ),
      ],
    );
  }
}

/// Weight · Body fat · BMR with the measurement's own date.
class BodySection extends StatelessWidget {
  const BodySection({required this.context, super.key});

  final HomeContext context;

  @override
  Widget build(BuildContext buildContext) {
    final c = context;
    final h = c.health!;
    _Block block(
      String label,
      HealthMetric m,
      String Function(double) fmt,
      String k,
    ) =>
        _Block(
          label: label,
          value: m.isAvailable ? fmt(m.value!) : m.availability.blockText,
          line: m.isAvailable ? HomeSections.recorded(m.start, c.date) : label,
          valueKey: ValueKey(k),
          muted: !m.isAvailable,
          onTap: () => buildContext.push(Routes.healthData),
        );
    return _Grid(
      blocks: <Widget>[
        block(
          'Weight',
          h.weight,
          (v) => '${HomeSections.kg(v)} kg',
          'home.weight',
        ),
        block(
          'Body fat',
          h.bodyFat,
          (v) => '${HomeSections.kg(v)}%',
          'home.bodyFat',
        ),
        if (h.bmr.availability != HealthAvailability.permissionDenied)
          block(
            'BMR',
            h.bmr,
            (v) => '${HomeSections.group(v)} kcal/day',
            'home.bmr',
          ),
      ],
    );
  }
}

/// Training · Movement · Sleep as "n / m" with seven dots each.
class WeekSection extends StatelessWidget {
  const WeekSection({required this.week, super.key});

  final WeekContext week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(String label, int done, int total, String key) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Text(label, style: textTheme.titleMedium),
              ),
              Expanded(
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < total; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i < done ? FitColors.ink : Colors.transparent,
                          border: Border.all(
                            color: i < done ? FitColors.ink : FitColors.ink35,
                          ),
                          borderRadius: const BorderRadius.all(FitRadius.small),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$done / $total',
                key: ValueKey(key),
                style: textTheme.titleMedium,
              ),
            ],
          ),
        );
    return Column(
      children: <Widget>[
        const Divider(color: FitColors.rule, height: 1),
        if (week.trainingPlanned > 0)
          row(
            'Training',
            week.trainingDone,
            week.trainingPlanned,
            'home.week.training',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FitSpacing.screen,
              vertical: FitSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text('Training', style: textTheme.titleMedium),
                ),
                Expanded(
                  child: Text(
                    'No programme yet',
                    key: const ValueKey('home.week.training'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ),
              ],
            ),
          ),
        if (week.movementDays != null)
          row('Movement', week.movementDays!, 7, 'home.week.movement'),
        if (week.sleepDays != null)
          row('Sleep', week.sleepDays!, 7, 'home.week.sleep'),
        const Divider(color: FitColors.rule, height: 1),
      ],
    );
  }
}
