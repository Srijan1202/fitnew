/// Beta 3.6 (owner): steps day by day, for this week and the three before.
/// Read from the health source on the phone (never uploaded); this holds
/// the days and answers the questions the Steps screen asks of them.
class StepsHistory {
  StepsHistory({required this.today, required this.steps})
      : firstDay = _mondayOf(today).subtract(const Duration(days: 7 * 3));

  /// The local day today, as a date (UTC midnight, for arithmetic only).
  final DateTime today;

  /// Monday three weeks before this week's.
  final DateTime firstDay;

  /// Steps per day from [firstDay] to [today], oldest first; null = no data.
  final List<double?> steps;

  /// This week and the three before it.
  static const int weeks = 4;

  /// How many days to read for [today]: from [firstDay] through today.
  static int daysFor(DateTime today) =>
      today.difference(_mondayOf(today)).inDays + 1 + 7 * (weeks - 1);

  static DateTime _mondayOf(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day - (d.weekday - 1));

  /// Parses a local date (yyyy-mm-dd).
  static DateTime dateOf(String s) => DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(5, 7)),
        int.parse(s.substring(8, 10)),
      );

  /// The week [ago] weeks back (0 = this week), Monday first.
  StepsWeek week(int ago) {
    final monday = _mondayOf(today).subtract(Duration(days: 7 * ago));
    final days = <double?>[];
    var future = 7;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(today)) {
        future = future == 7 ? i : future;
        days.add(null);
        continue;
      }
      final index = day.difference(firstDay).inDays;
      days.add(index >= 0 && index < steps.length ? steps[index] : null);
    }
    return StepsWeek(monday: monday, days: days, futureFrom: future);
  }
}

/// Seven days of steps, Monday first.
class StepsWeek {
  const StepsWeek({
    required this.monday,
    required this.days,
    required this.futureFrom,
  });

  final DateTime monday;

  /// Steps per day; null = no data (or a day still to come).
  final List<double?> days;

  /// The first day still to come (7 when the week is over).
  final int futureFrom;

  /// Days of this week up to today.
  int get daysSoFar => futureFrom;

  Iterable<double> get _known => days.whereType<double>();

  bool get hasData => _known.isNotEmpty;

  int get total => _known.fold<double>(0, (a, b) => a + b).round();

  /// The daily average over the days with data; null when there are none.
  int? get average => hasData ? (total / _known.length).round() : null;

  /// The day with the most steps (its index, 0 = Monday); null when none.
  int? get bestDay {
    int? best;
    for (var i = 0; i < days.length; i++) {
      final v = days[i];
      if (v != null && (best == null || v > days[best]!)) best = i;
    }
    return best;
  }

  int daysAtGoal(int goal) => _known.where((v) => v >= goal).length;
}
