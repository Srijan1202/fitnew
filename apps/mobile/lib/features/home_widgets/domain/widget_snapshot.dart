import '../../home/data/streak_api.dart';
import '../../nutrition/domain/entities/food_log.dart';
import '../../nutrition/presentation/widgets/eat_widgets.dart';
import '../../running/domain/units.dart';
import '../../running/domain/workout.dart';
import '../../training/domain/entities/program.dart';

/// Beta 5.0 (owner): what the home-screen widgets show, written by the app
/// whenever it changes and read by the native widgets (HomeWidgets.kt).
/// Pure: every figure is already worded here, so the widgets only pick the
/// right day — after midnight they show the new day from [week] and the
/// targets, without the app.
///
/// Version 1, JSON:
/// ```
/// { v, signedIn, date,
///   food: { date, leftValue, leftCaption, protein, kcalTarget, proteinTarget,
///           eatenShare, over, loggedAt },
///   week: [ { date, kind: workout|run|rest|none, title, detail, done } ×7 ],
///   streak: { current, todayCounted, days: [ { date, status } ×14 ] } }
/// ```
abstract final class WidgetSnapshot {
  static const version = 1;

  /// Signed out: the widgets say so and show nothing.
  static Map<String, Object?> signedOut() => {'v': version, 'signedIn': false};

  static Map<String, Object?> build({
    required String today,
    required NutritionDay? food,
    required Program? program,
    required RunningPlan? runningPlan,
    required Streak? streak,
    required bool workoutDoneToday,
    required DistanceUnit unit,
  }) =>
      {
        'v': version,
        'signedIn': true,
        'date': today,
        if (food != null && food.date == today) 'food': _food(food),
        'week': [
          for (var i = 0; i < 7; i++)
            _day(
              addDays(today, i),
              program,
              runningPlan,
              unit,
              doneGym: i == 0 && workoutDoneToday,
            ),
        ],
        if (streak != null) 'streak': _streak(streak),
      };

  static Map<String, Object?> _food(NutritionDay d) {
    final r = d.remaining;
    final t = d.totals;
    final kcal = r?.kcal;
    final hero = kcal == null ? null : EatFormat.heroKcal(kcal);
    final eaten = (t.kcalLow + t.kcalHigh) / 2;
    final last = d.logs.isEmpty
        ? null
        : d.logs
            .map((l) => l.loggedAt)
            .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    return {
      'date': d.date,
      'leftValue': hero?.value ?? '–',
      'leftCaption': hero?.caption ?? 'Set your targets in FITOS',
      'protein':
          r == null ? null : 'Protein ${EatFormat.proteinShort(r.protein)}',
      'kcalTarget': kcal?.target.round(),
      'proteinTarget': r?.protein.target.round(),
      'eatenShare': kcal == null || kcal.target <= 0
          ? 0
          : (eaten / kcal.target).clamp(0, 1.5),
      'over': kcal?.state == RemainingState.over,
      'loggedAt': last,
    };
  }

  static Map<String, Object?> _day(
    String date,
    Program? program,
    RunningPlan? plan,
    DistanceUnit unit, {
    required bool doneGym,
  }) {
    final run = plan?.runs
        .where((r) => r.date == date && r.status != PlannedRunStatus.skipped)
        .firstOrNull;
    if (run != null) {
      final km = run.distanceM == null
          ? null
          : '${formatDistance(run.distanceM!, unit)} ${unit.label}';
      return {
        'date': date,
        'kind': 'run',
        'title': run.title,
        'detail': [
          if (km != null) km,
          if (run.seconds != null) formatDuration(run.seconds!),
        ].join(' · '),
        'done': run.status == PlannedRunStatus.done,
      };
    }
    final weekday = DateTime.parse(date).weekday;
    final day = program?.days.where((d) => d.dayOfWeek == weekday).firstOrNull;
    if (day == null || day.isRest) {
      return {
        'date': date,
        'kind': program == null ? 'none' : 'rest',
        'title': program == null ? 'No plan yet' : 'Rest day',
        'detail': program == null ? 'Make one in FITOS' : 'Recover well',
        'done': false,
      };
    }
    final n = day.exercises.length;
    return {
      'date': date,
      'kind': 'workout',
      'title': day.sessionName,
      'detail':
          '$n exercise${n == 1 ? '' : 's'} · about ${day.estimatedMinutes} min',
      'done': doneGym,
    };
  }

  static Map<String, Object?> _streak(Streak s) {
    final days = s.calendar.isNotEmpty ? s.calendar : s.days;
    final last = days.length > 14 ? days.sublist(days.length - 14) : days;
    return {
      'current': s.current,
      'todayCounted': s.todayCounted,
      'days': [
        for (final d in last) {'date': d.date, 'status': d.status.name},
      ],
    };
  }

  /// [date] (yyyy-mm-dd) plus [n] days.
  static String addDays(String date, int n) {
    final d = DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(5, 7)),
      int.parse(date.substring(8, 10)),
    ).add(Duration(days: n));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// What a widget tap asks for (`fitos://widget/<target>`).
enum WidgetTarget {
  food,
  training,
  workout,
  run,
  weight,
  streak;

  static WidgetTarget? fromLink(String? link) {
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null || uri.scheme != 'fitos' || uri.host != 'widget') {
      return null;
    }
    final name = uri.pathSegments.firstOrNull;
    return values.where((v) => v.name == name).firstOrNull;
  }
}

/// The meal a widget's "Log food" opens on, by the hour.
MealSlot slotAt(int hour) => hour < 11
    ? MealSlot.breakfast
    : hour < 16
        ? MealSlot.lunch
        : hour < 19
            ? MealSlot.snacks
            : MealSlot.dinner;
