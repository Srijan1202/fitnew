import '../../../core/theme/tokens.dart';
import '../../nutrition/domain/entities/food_log.dart';
import '../domain/today.dart';
import 'package:flutter/painting.dart' show Color;

/// How Home words a server TODAY action beyond the server's own headline
/// and detail: the eyebrow, the primary button, and the facts in the "why"
/// sheet. Everything is read from the action's structured reason (D3) —
/// nothing here decides or computes an action.
abstract final class TodayWords {
  static String eyebrow(TodayKind k) => switch (k) {
        TodayKind.deload => 'DELOAD',
        TodayKind.injuredLimitation => 'TRAIN · LIMITATION',
        TodayKind.startWorkout ||
        TodayKind.progressLoad ||
        TodayKind.muscleNeglected =>
          'TRAIN',
        TodayKind.eatProtein || TodayKind.eatMeal => 'EAT',
        TodayKind.restDay => 'REST DAY',
        TodayKind.celebratePr => 'RECORD',
        TodayKind.logWeight => 'BODY',
      };

  /// Semantic colour only where it carries meaning (§6.2).
  static Color eyebrowColor(TodayKind k) => switch (k) {
        TodayKind.deload || TodayKind.injuredLimitation => FitColors.amber,
        TodayKind.celebratePr => FitColors.pine,
        _ => FitColors.ink60,
      };

  /// The primary button: the flow the action leads into.
  static String primary(TodayAction a, {required bool messConfigured}) =>
      switch (a.kind!) {
        TodayKind.deload => 'Review the lighter week',
        TodayKind.injuredLimitation => 'See the swap',
        TodayKind.startWorkout => 'Start workout',
        TodayKind.eatProtein || TodayKind.eatMeal => messConfigured
            ? 'What to eat'
            : 'Log ${MealSlot.fromWire(a.subjectKey).label.toLowerCase()}',
        TodayKind.progressLoad => "Open today's session",
        TodayKind.muscleNeglected || TodayKind.restDay => 'Open your plan',
        TodayKind.celebratePr => 'See the record',
        TodayKind.logWeight => 'Log weight',
      };

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _range(num lo, num hi) =>
      _num(lo) == _num(hi) ? _num(lo) : '${_num(lo)}–${_num(hi)}';

  static String _label(String s) => s.replaceAll('-', ' ');

  static String _title(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _list(List<String> xs) => xs.length <= 1
      ? xs.join()
      : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

  static String _date(String iso) {
    const months = [
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
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day} ${months[d.month - 1]}';
  }

  /// The reason's values as labelled facts, per code. Unknown codes (a
  /// newer server) show none rather than guess.
  static List<(String, String)> facts(TodayReason r) {
    final v = r.values;
    String s(String k) => '${v[k]}';
    num n(String k) => v[k] as num;
    return switch (r.code) {
      'deload-offered' => [
          (
            'Signal',
            v['trigger'] == 'mrv'
                ? 'A muscle is at the most volume you can recover from'
                : 'Reps falling at the same load on your main lifts',
          ),
        ],
      'exercise-contraindicated' => [
          (
            'Limitation',
            _list([for (final p in v['bodyParts'] as List) _label('$p')]),
          ),
          ('Instead of', s('exerciseName')),
          ('Swap', s('alternativeName')),
          if (n('affectedCount') > 1)
            ('Lifts affected today', _num(n('affectedCount'))),
        ],
      'session-scheduled' => [
          ('Session', s('sessionName')),
          ('Movements', _num(n('exerciseCount'))),
          ('About', '${_num(n('minutes'))} min'),
        ],
      'protein-behind' => [
          ('Meal', _title(s('slot'))),
          (
            'Protein so far',
            '${_range(n('proteinLow'), n('proteinHigh'))} of ${_num(n('proteinTarget'))} g',
          ),
          ('Left today', '${_range(n('kcalLeftLow'), n('kcalLeftHigh'))} kcal'),
        ],
      'meal-remaining' => [
          ('Meal', _title(s('slot'))),
          ('Left today', '${_range(n('kcalLeftLow'), n('kcalLeftHigh'))} kcal'),
          (
            'Protein left',
            '${_range(n('proteinLeftLow'), n('proteinLeftHigh'))} g',
          ),
        ],
      'load-increase-due' => [
          ('Lift', s('exerciseName')),
          (
            'Next',
            v['weightKg'] == null
                ? '${s('repTarget')} reps'
                : '${_num(n('weightKg'))} kg × ${s('repTarget')}',
          ),
        ],
      'muscle-untrained' => [
          ('Muscle', _title(_label(s('muscle')))),
          (
            'Last worked',
            v['daysSince'] == null
                ? 'Not yet this block'
                : '${_num(n('daysSince'))} days ago',
          ),
        ],
      'rest-day' => [
          if (v['nextSessionName'] != null)
            (
              'Next session',
              '${s('nextSessionName')} on ${_date(s('nextSessionDate'))}',
            ),
          if (v['kcalTarget'] != null)
            (
              'Targets',
              '${_num(n('kcalTarget'))} kcal · ${_num(n('proteinTarget'))} g protein',
            ),
          if (v['hasProgramme'] == false) ('Programme', 'None yet'),
        ],
      'pr-today' => [
          ('Lift', s('exerciseName')),
          if (n('count') > 1) ('Records today', _num(n('count'))),
        ],
      'weigh-in-due' => [
          (
            'Last weigh-in',
            v['daysSinceWeighIn'] == null
                ? 'None yet'
                : '${_num(n('daysSinceWeighIn'))} days ago',
          ),
        ],
      _ => const [],
    };
  }
}
