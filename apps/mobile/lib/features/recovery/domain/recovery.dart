/// Wire shapes of `@fitos/contracts` recovery.ts (Phase 13, ADR-019). The
/// readiness score is the server's, computed on read (§18, §30): the app
/// shows it and never computes a penalty, a band or a score itself.
/// Hand-written (ADR-004); the conformance test keeps them in step.
library;

/// §18's bands, as the server names them.
enum ReadinessBand {
  ready('ready', 'Ready'),
  advisory('advisory', 'A little under par'),
  reduce('reduce', 'Go lighter'),
  rest('rest', 'Low');

  const ReadinessBand(this.wire, this.label);
  final String wire;
  final String label;

  static ReadinessBand fromWire(String w) =>
      values.firstWhere((b) => b.wire == w, orElse: () => ready);
}

/// §18's five components.
enum ReadinessComponentKey {
  sleep('sleep', 'Sleep'),
  soreness('soreness', 'Soreness'),
  energy('energy', 'Energy'),
  performance('performance', 'Training'),
  adherence('adherence', 'Nutrition');

  const ReadinessComponentKey(this.wire, this.label);
  final String wire;
  final String label;

  static ReadinessComponentKey fromWire(String w) =>
      values.firstWhere((k) => k.wire == w);
}

/// The four 1–5 questions of the check-in, with the words at each end.
enum RecoveryScale {
  sleepQuality('sleepQuality', 'Sleep quality', 'Poor', 'Great'),
  soreness('soreness', 'Soreness', 'None', 'Very sore'),
  energy('energy', 'Energy', 'Drained', 'Great'),
  stress('stress', 'Stress', 'Calm', 'Very stressed');

  const RecoveryScale(this.wire, this.label, this.low, this.high);
  final String wire;
  final String label;

  /// What 1 means.
  final String low;

  /// What 5 means.
  final String high;
}

double? _dn(Object? v) => v == null ? null : (v as num).toDouble();
int? _in(Object? v) => v == null ? null : (v as num).toInt();

/// One day's check-in (`recovery_logs`), always `source: manual`.
class RecoveryLog {
  const RecoveryLog({
    required this.date,
    this.sleepHours,
    this.sleepQuality,
    this.soreness,
    this.energy,
    this.stress,
    this.source = 'manual',
  });

  factory RecoveryLog.fromJson(Map<String, dynamic> j) => RecoveryLog(
        date: j['date'] as String,
        sleepHours: _dn(j['sleepHours']),
        sleepQuality: _in(j['sleepQuality']),
        soreness: _in(j['soreness']),
        energy: _in(j['energy']),
        stress: _in(j['stress']),
        source: j['source'] as String,
      );

  final String date;
  final double? sleepHours;
  final int? sleepQuality;
  final int? soreness;
  final int? energy;
  final int? stress;
  final String source;

  int? scale(RecoveryScale s) => switch (s) {
        RecoveryScale.sleepQuality => sleepQuality,
        RecoveryScale.soreness => soreness,
        RecoveryScale.energy => energy,
        RecoveryScale.stress => stress,
      };

  Map<String, dynamic> toJson() => {
        'date': date,
        'sleepHours': sleepHours,
        'sleepQuality': sleepQuality,
        'soreness': soreness,
        'energy': energy,
        'stress': stress,
        'source': source,
      };
}

class ReadinessComponent {
  const ReadinessComponent({
    required this.key,
    required this.penalty,
    required this.max,
    required this.available,
  });

  factory ReadinessComponent.fromJson(Map<String, dynamic> j) =>
      ReadinessComponent(
        key: ReadinessComponentKey.fromWire(j['key'] as String),
        penalty: (j['penalty'] as num).toInt(),
        max: (j['max'] as num).toInt(),
        available: j['available'] as bool,
      );

  final ReadinessComponentKey key;
  final int penalty;
  final int max;

  /// False when its input was missing: nothing was guessed.
  final bool available;

  Map<String, dynamic> toJson() => {
        'key': key.wire,
        'penalty': penalty,
        'max': max,
        'available': available,
      };
}

class Readiness {
  const Readiness({
    required this.score,
    required this.band,
    required this.advice,
    required this.components,
    required this.lowDays,
  });

  factory Readiness.fromJson(Map<String, dynamic> j) => Readiness(
        score: (j['score'] as num).toInt(),
        band: ReadinessBand.fromWire(j['band'] as String),
        advice: j['advice'] as String,
        components: [
          for (final c in j['components'] as List)
            ReadinessComponent.fromJson(c as Map<String, dynamic>),
        ],
        lowDays: (j['lowDays'] as num).toInt(),
      );

  final int score;
  final ReadinessBand band;

  /// The server's words for the band (§18's effect; never a diagnosis).
  final String advice;
  final List<ReadinessComponent> components;

  /// Local days running under 35 (three escalate to a deload check).
  final int lowDays;

  Map<String, dynamic> toJson() => {
        'score': score,
        'band': band.wire,
        'advice': advice,
        'components': [for (final c in components) c.toJson()],
        'lowDays': lowDays,
      };
}

/// `GET /v1/recovery/today`.
class RecoveryToday {
  const RecoveryToday({required this.date, this.log, this.readiness});

  factory RecoveryToday.fromJson(Map<String, dynamic> j) => RecoveryToday(
        date: j['date'] as String,
        log: j['log'] == null
            ? null
            : RecoveryLog.fromJson(j['log'] as Map<String, dynamic>),
        readiness: j['readiness'] == null
            ? null
            : Readiness.fromJson(j['readiness'] as Map<String, dynamic>),
      );

  final String date;
  final RecoveryLog? log;

  /// Null until today's check-in exists.
  final Readiness? readiness;

  Map<String, dynamic> toJson() => {
        'date': date,
        'log': log?.toJson(),
        'readiness': readiness?.toJson(),
      };
}

/// `POST /v1/recovery/log` body: the day's check-in is REPLACED by what is
/// sent, so every question is sent — null when it was left unanswered.
class LogRecoveryRequest {
  const LogRecoveryRequest({
    this.date,
    this.sleepHours,
    this.sleepQuality,
    this.soreness,
    this.energy,
    this.stress,
  });

  /// The local date; null = today on the server's clock in the user's zone.
  final String? date;
  final double? sleepHours;
  final int? sleepQuality;
  final int? soreness;
  final int? energy;
  final int? stress;

  bool get isEmpty =>
      sleepHours == null &&
      sleepQuality == null &&
      soreness == null &&
      energy == null &&
      stress == null;

  Map<String, dynamic> toJson() => {
        if (date != null) 'date': date,
        'sleepHours': sleepHours,
        'sleepQuality': sleepQuality,
        'soreness': soreness,
        'energy': energy,
        'stress': stress,
      };
}

/// What a save returned.
class SavedCheckIn {
  const SavedCheckIn({required this.log, required this.created});

  final RecoveryLog log;

  /// 201 (a new day) vs 200 (replaced).
  final bool created;
}
