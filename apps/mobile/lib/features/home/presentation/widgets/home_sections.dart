import '../../../premium/presentation/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../../core/theme/tokens.dart';
import '../../../health/domain/entities/health.dart';
import '../../../recovery/domain/recovery.dart';
import '../../domain/home_context.dart';
import '../controllers/home_providers.dart';

part 'home_sections_health.dart';

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

  /// The largest display size (56 down to 30) at which [text] fits two lines
  /// without breaking a word; 30 if none does (then it ends in an ellipsis).
  static double greetingSize(
    String text,
    TextStyle? base,
    double maxWidth,
    TextScaler scaler,
  ) {
    const sizes = <double>[56, 48, 42, 36, 30];
    if (base == null || !maxWidth.isFinite) return sizes.first;
    for (final size in sizes) {
      final style = base.copyWith(fontSize: size);
      bool fits(String t, int lines) {
        final painter = TextPainter(
          text: TextSpan(text: t, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: lines,
        )..layout(maxWidth: maxWidth);
        final ok = !painter.didExceedMaxLines;
        painter.dispose();
        return ok;
      }

      if (fits(text, 2) && text.split(' ').every((w) => fits(w, 1))) {
        return size;
      }
    }
    return sizes.last;
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
                LayoutBuilder(
                  builder: (context, box) {
                    final text = name == null || name!.trim().isEmpty
                        ? HomeSections.greeting(hour)
                        : '${HomeSections.greeting(hour)}, ${name!.trim()}';
                    final base =
                        textTheme.displayMedium?.copyWith(color: FitColors.ink);
                    return Text(
                      text,
                      key: const ValueKey('home.greeting'),
                      // Shrinks to fit two lines rather than cutting a word
                      // ("Good afternoo…" with a long name).
                      style: base?.copyWith(
                        fontSize: HomeSections.greetingSize(
                          text,
                          base,
                          box.maxWidth,
                          MediaQuery.textScalerOf(context),
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
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
          // Phase 19: the user's picture, gold-rimmed when premium.
          const ProfileAvatarButton(),
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
      padding: EdgeInsets.symmetric(
        horizontal: fitGlass ? 14 : FitSpacing.screen,
        vertical: fitGlass ? 14 : FitSpacing.md,
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
          // Beta 4.8: two lines, so "Target 2,276 kcal · 106 g protein"
          // and "Health Connect is not installed" read whole.
          Text(
            line,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            maxLines: 2,
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

  /// ADR-029: separate glass tiles; the hairline grid on Paper.
  @override
  Widget build(BuildContext context) => FitTileGrid(tiles: blocks);
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

    // Active calories. Beta 3.2: a workout logged in FITOS adds what Health
    // Connect did not already count (an estimate, so "≈").
    String kcalValue;
    String kcalLine;
    var kcalMuted = false;
    final energy = c.activeEnergy;
    if (energy != null && energy.fromWorkouts > 0) {
      kcalValue = '≈ ${HomeSections.group(energy.total)} kcal';
      final fromHealth = energy.fromHealth;
      kcalLine = fromHealth == null
          ? "From today's workout (estimate)"
          : '${HomeSections.group(fromHealth)} phone/watch + '
              '${HomeSections.group(energy.fromWorkouts)} workouts';
    } else if (active != null && active.isAvailable) {
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

    // Food — the server's day (Phase 8), "about N" when it holds estimates
    // (beta 3.7); never a zero for "not logged".
    final t = c.targets;
    final n = c.nutrition;
    String span(int? low, int? high, {bool group = false}) {
      String f(int v) => group ? HomeSections.group(v) : '$v';
      final hi = high ?? 0;
      final lo = low ?? hi;
      return lo == hi ? f(hi) : 'about ${f(((lo + hi) / 2).round())}';
    }

    final kcalEaten = span(n.kcalLow, n.kcal, group: true);
    final proteinEaten = span(n.proteinLow, n.proteinG);
    final foodValue = !n.logged
        ? 'Not logged yet'
        : t == null
            ? '$kcalEaten kcal'
            : '$kcalEaten / ${HomeSections.group(t.kcal)} kcal';
    final foodLine = t == null
        ? (n.logged
            ? '$proteinEaten g protein · no targets yet'
            : 'No targets yet')
        : n.logged
            ? '$proteinEaten / ${t.proteinG} g protein'
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
    } else if (today.skipped) {
      // ADR-030.
      workoutValue = 'Skipped';
      workoutLine = 'Your week moved a day';
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
          // Beta 3.6: the week day by day.
          onTap: () => buildContext.push(Routes.steps),
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
