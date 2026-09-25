/// Wire shapes of `@fitos/contracts` progress.ts (Phase 12, ADR-018). Every
/// number is the server's, computed on read from the user's own records;
/// the app draws them and never computes a trend, a rate or a percentage.
/// Hand-written (ADR-004); the conformance test keeps them in step.
library;

enum ProgressWindow {
  d30('30d', '30 days'),
  d90('90d', '90 days');

  const ProgressWindow(this.wire, this.label);
  final String wire;
  final String label;

  static ProgressWindow fromWire(String w) =>
      values.firstWhere((v) => v.wire == w, orElse: () => d30);
}

enum MeasurementSite {
  waist('waist', 'Waist'),
  chest('chest', 'Chest'),
  arm('arm', 'Arm'),
  thigh('thigh', 'Thigh'),
  hip('hip', 'Hip');

  const MeasurementSite(this.wire, this.label);
  final String wire;
  final String label;

  static MeasurementSite fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

double _d(Object? v) => (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();

class WeightPoint {
  const WeightPoint({
    required this.date,
    required this.rawKg,
    required this.trendKg,
  });

  factory WeightPoint.fromJson(Map<String, dynamic> j) => WeightPoint(
        date: j['date'] as String,
        rawKg: _d(j['rawKg']),
        trendKg: _d(j['trendKg']),
      );

  final String date;
  final double rawKg;
  final double trendKg;

  Map<String, dynamic> toJson() =>
      {'date': date, 'rawKg': rawKg, 'trendKg': trendKg};
}

class WeightProgress {
  const WeightProgress({
    required this.points,
    required this.currentTrendKg,
    required this.weeklyChangeKg,
    required this.daysOfData,
    required this.isReliable,
    required this.windowChangeKg,
    required this.windowChangeDays,
  });

  factory WeightProgress.fromJson(Map<String, dynamic> j) => WeightProgress(
        points: [
          for (final p in j['points'] as List<dynamic>)
            WeightPoint.fromJson(p as Map<String, dynamic>),
        ],
        currentTrendKg: _dn(j['currentTrendKg']),
        weeklyChangeKg: _dn(j['weeklyChangeKg']),
        daysOfData: j['daysOfData'] as int,
        isReliable: j['isReliable'] as bool,
        windowChangeKg: _dn(j['windowChangeKg']),
        windowChangeDays: j['windowChangeDays'] as int?,
      );

  final List<WeightPoint> points;

  /// The headline (§13.2).
  final double? currentTrendKg;

  /// kg/week; null before the 10-day reliability gate.
  final double? weeklyChangeKg;
  final int daysOfData;
  final bool isReliable;

  /// Over ≥ 7 days only; null otherwise (never day-over-day).
  final double? windowChangeKg;
  final int? windowChangeDays;

  Map<String, dynamic> toJson() => {
        'points': [for (final p in points) p.toJson()],
        'currentTrendKg': currentTrendKg,
        'weeklyChangeKg': weeklyChangeKg,
        'daysOfData': daysOfData,
        'isReliable': isReliable,
        'windowChangeKg': windowChangeKg,
        'windowChangeDays': windowChangeDays,
      };
}

class SiteProgress {
  const SiteProgress({
    required this.site,
    required this.latestDate,
    required this.latestCm,
    required this.changeCm,
    required this.changeDays,
  });

  factory SiteProgress.fromJson(Map<String, dynamic> j) {
    final latest = j['latest'] as Map<String, dynamic>;
    return SiteProgress(
      site: MeasurementSite.fromWire(j['site'] as String),
      latestDate: latest['date'] as String,
      latestCm: _d(latest['valueCm']),
      changeCm: _dn(j['changeCm']),
      changeDays: j['changeDays'] as int?,
    );
  }

  final MeasurementSite site;
  final String latestDate;
  final double latestCm;
  final double? changeCm;
  final int? changeDays;

  Map<String, dynamic> toJson() => {
        'site': site.wire,
        'latest': {'date': latestDate, 'valueCm': latestCm},
        'changeCm': changeCm,
        'changeDays': changeDays,
      };
}

class PrRecord {
  const PrRecord({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.prType,
    required this.value,
    required this.previous,
    required this.reason,
    required this.achievedOn,
  });

  factory PrRecord.fromJson(Map<String, dynamic> j) => PrRecord(
        id: j['id'] as String,
        exerciseId: j['exerciseId'] as String,
        exerciseName: j['exerciseName'] as String,
        prType: j['prType'] as String,
        value: _d(j['value']),
        previous: _d(j['previous']),
        reason: j['reason'] as String,
        achievedOn: j['achievedOn'] as String,
      );

  final String id;
  final String exerciseId;
  final String exerciseName;
  final String prType;
  final double value;
  final double previous;

  /// The record's own words (server).
  final String reason;
  final String achievedOn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'prType': prType,
        'value': value,
        'previous': previous,
        'reason': reason,
        'achievedOn': achievedOn,
      };
}

class BestLift {
  const BestLift({
    required this.exerciseId,
    required this.exerciseName,
    required this.estimated1RmKg,
    required this.weightKg,
    required this.reps,
    required this.date,
  });

  factory BestLift.fromJson(Map<String, dynamic> j) => BestLift(
        exerciseId: j['exerciseId'] as String,
        exerciseName: j['exerciseName'] as String,
        estimated1RmKg: _d(j['estimated1RmKg']),
        weightKg: _d(j['weightKg']),
        reps: j['reps'] as int,
        date: j['date'] as String,
      );

  final String exerciseId;
  final String exerciseName;

  /// Epley — a display figure, never a prescription.
  final double estimated1RmKg;
  final double weightKg;
  final int reps;
  final String date;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'estimated1RmKg': estimated1RmKg,
        'weightKg': weightKg,
        'reps': reps,
        'date': date,
      };
}

class AdherenceCount {
  const AdherenceCount({
    required this.met,
    required this.of,
    required this.percent,
  });

  factory AdherenceCount.fromJson(Map<String, dynamic> j) => AdherenceCount(
        met: j['met'] as int,
        of: j['of'] as int,
        percent: j['percent'] as int?,
      );

  final int met;
  final int of;
  final int? percent;

  Map<String, dynamic> toJson() => {'met': met, 'of': of, 'percent': percent};
}

class Adherence {
  const Adherence({
    required this.protein,
    required this.calories,
    required this.loggedDays,
    required this.daysWithoutTarget,
  });

  factory Adherence.fromJson(Map<String, dynamic> j) => Adherence(
        protein: AdherenceCount.fromJson(j['protein'] as Map<String, dynamic>),
        calories:
            AdherenceCount.fromJson(j['calories'] as Map<String, dynamic>),
        loggedDays: j['loggedDays'] as int,
        daysWithoutTarget: j['daysWithoutTarget'] as int,
      );

  final AdherenceCount protein;
  final AdherenceCount calories;
  final int loggedDays;
  final int daysWithoutTarget;

  Map<String, dynamic> toJson() => {
        'protein': protein.toJson(),
        'calories': calories.toJson(),
        'loggedDays': loggedDays,
        'daysWithoutTarget': daysWithoutTarget,
      };
}

class WeekConsistency {
  const WeekConsistency({
    required this.isoWeek,
    required this.completed,
    required this.planned,
  });

  factory WeekConsistency.fromJson(Map<String, dynamic> j) => WeekConsistency(
        isoWeek: j['isoWeek'] as String,
        completed: j['completed'] as int,
        planned: j['planned'] as int,
      );

  final String isoWeek;
  final int completed;
  final int planned;

  Map<String, dynamic> toJson() =>
      {'isoWeek': isoWeek, 'completed': completed, 'planned': planned};
}

class Consistency {
  const Consistency({
    required this.weeks,
    required this.completed,
    required this.planned,
    required this.percent,
  });

  factory Consistency.fromJson(Map<String, dynamic> j) => Consistency(
        weeks: [
          for (final w in j['weeks'] as List<dynamic>)
            WeekConsistency.fromJson(w as Map<String, dynamic>),
        ],
        completed: j['completed'] as int,
        planned: j['planned'] as int?,
        percent: j['percent'] as int?,
      );

  final List<WeekConsistency> weeks;
  final int completed;

  /// Null without a programme.
  final int? planned;
  final int? percent;

  Map<String, dynamic> toJson() => {
        'weeks': [for (final w in weeks) w.toJson()],
        'completed': completed,
        'planned': planned,
        'percent': percent,
      };
}

/// `GET /v1/progress/summary`.
class ProgressSummary {
  const ProgressSummary({
    required this.window,
    required this.today,
    required this.from,
    required this.weight,
    required this.measurements,
    required this.prs,
    required this.bestLifts,
    required this.adherence,
    required this.consistency,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> j) => ProgressSummary(
        window: ProgressWindow.fromWire(j['window'] as String),
        today: j['today'] as String,
        from: j['from'] as String,
        weight: WeightProgress.fromJson(j['weight'] as Map<String, dynamic>),
        measurements: [
          for (final m in j['measurements'] as List<dynamic>)
            SiteProgress.fromJson(m as Map<String, dynamic>),
        ],
        prs: [
          for (final p in j['prs'] as List<dynamic>)
            PrRecord.fromJson(p as Map<String, dynamic>),
        ],
        bestLifts: [
          for (final b in j['bestLifts'] as List<dynamic>)
            BestLift.fromJson(b as Map<String, dynamic>),
        ],
        adherence: Adherence.fromJson(j['adherence'] as Map<String, dynamic>),
        consistency:
            Consistency.fromJson(j['consistency'] as Map<String, dynamic>),
      );

  final ProgressWindow window;
  final String today;
  final String from;
  final WeightProgress weight;
  final List<SiteProgress> measurements;
  final List<PrRecord> prs;
  final List<BestLift> bestLifts;
  final Adherence adherence;
  final Consistency consistency;

  Map<String, dynamic> toJson() => {
        'window': window.wire,
        'today': today,
        'from': from,
        'weight': weight.toJson(),
        'measurements': [for (final m in measurements) m.toJson()],
        'prs': [for (final p in prs) p.toJson()],
        'bestLifts': [for (final b in bestLifts) b.toJson()],
        'adherence': adherence.toJson(),
        'consistency': consistency.toJson(),
      };
}

/// `POST /v1/progress/weight` body.
class LogWeightRequest {
  const LogWeightRequest({required this.weightKg, this.date});

  final double weightKg;

  /// The local date; null = today on the server's clock in the user's zone.
  final String? date;

  Map<String, dynamic> toJson() =>
      {'weightKg': weightKg, if (date != null) 'date': date};
}

/// `POST /v1/progress/measurement` body.
class LogMeasurementRequest {
  const LogMeasurementRequest({
    required this.site,
    required this.valueCm,
    this.date,
  });

  final MeasurementSite site;
  final double valueCm;
  final String? date;

  Map<String, dynamic> toJson() =>
      {'site': site.wire, 'valueCm': valueCm, if (date != null) 'date': date};
}

/// A saved reading, as the server answered (201 new, 200 replaced).
class SavedReading {
  const SavedReading({
    required this.date,
    required this.value,
    this.site,
    this.created = true,
  });

  final String date;
  final double value;
  final MeasurementSite? site;
  final bool created;
}
