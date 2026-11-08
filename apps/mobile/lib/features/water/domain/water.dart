/// Beta 6.0 (F7, ADR-059): a day's water and its target, as the server
/// gives it (`/v1/water`). [unsynced] is the phone's: a total it holds that
/// the server does not have yet.
class WaterDay {
  const WaterDay({
    required this.date,
    required this.ml,
    required this.targetMl,
    required this.fromWeight,
    this.unsynced = false,
  });

  factory WaterDay.fromJson(Map<String, dynamic> j) => WaterDay(
        date: j['date'] as String,
        ml: (j['ml'] as num).toInt(),
        targetMl: (j['targetMl'] as num).toInt(),
        fromWeight: j['fromWeight'] as bool,
      );

  final String date;
  final int ml;
  final int targetMl;
  final bool fromWeight;
  final bool unsynced;

  Map<String, dynamic> toJson() => {
        'date': date,
        'ml': ml,
        'targetMl': targetMl,
        'fromWeight': fromWeight,
      };

  WaterDay copyWith({int? ml, bool? unsynced}) => WaterDay(
        date: date,
        ml: ml ?? this.ml,
        targetMl: targetMl,
        fromWeight: fromWeight,
        unsynced: unsynced ?? this.unsynced,
      );

  /// 0 to 1, for the bar.
  double get share => targetMl <= 0 ? 0 : (ml / targetMl).clamp(0, 1);

  int get glassesLeft =>
      ml >= targetMl ? 0 : ((targetMl - ml) / kWaterGlassMl).ceil();
}

/// One glass, and the most a day holds (the server's WATER_MAX_ML).
const int kWaterGlassMl = 250;
const int kWaterMaxMl = 10000;

/// The target without a weigh-in (core's WATER_DEFAULT_TARGET_ML).
const int kWaterDefaultTargetMl = 2500;

/// "750 ml", "1.25 L", "2 L".
String waterAmount(int ml) {
  if (ml < 1000) return '$ml ml';
  final litres = ml / 1000;
  var s = litres.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '$s L';
}
