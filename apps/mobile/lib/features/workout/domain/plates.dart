/// Beta 6.4 (N3, owner Q2): which plates go on each side of a barbell, for
/// the bar and plates the person's gym has. Pure: kilograms in, plates out.
library;

/// Plates a gym may have, heaviest first (kg).
const List<double> kPlateSizes = [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5];

/// The set every person starts with: a 20 kg bar and the common plates.
const List<double> kStandardPlates = [25, 20, 15, 10, 5, 2.5, 1.25];
const double kStandardBarKg = 20;

/// Bar weights the settings offer (kg).
const List<double> kBarWeights = [10, 15, 20, 25];

class GymPlates {
  const GymPlates({required this.barKg, required this.plates});

  static const standard =
      GymPlates(barKg: kStandardBarKg, plates: kStandardPlates);

  factory GymPlates.fromJson(Map<String, dynamic> j) {
    final bar = (j['barKg'] as num?)?.toDouble() ?? kStandardBarKg;
    final plates = [
      for (final p in (j['plates'] as List<dynamic>?) ?? const [])
        if (kPlateSizes.contains((p as num).toDouble())) p.toDouble(),
    ];
    return GymPlates(
      barKg: kBarWeights.contains(bar) ? bar : kStandardBarKg,
      plates: plates.isEmpty ? kStandardPlates : _sorted(plates),
    );
  }

  final double barKg;

  /// Heaviest first, each size once (a gym has pairs of each).
  final List<double> plates;

  Map<String, dynamic> toJson() => {'barKg': barKg, 'plates': plates};

  GymPlates copyWith({double? barKg, List<double>? plates}) => GymPlates(
        barKg: barKg ?? this.barKg,
        plates: plates == null ? this.plates : _sorted(plates),
      );

  /// "20 kg bar · 7 plates".
  String get summary =>
      '${kgText(barKg)} kg bar · ${plates.length} ${plates.length == 1 ? 'plate' : 'plates'}';

  static List<double> _sorted(List<double> p) =>
      ({...p}.toList()..sort((a, b) => b.compareTo(a)));
}

/// What goes on: the plates on ONE side, heaviest first, and the total that
/// makes. [exact] when that is the weight asked for.
class PlateLoad {
  const PlateLoad({
    required this.perSide,
    required this.totalKg,
    required this.exact,
  });

  final List<double> perSide;
  final double totalKg;
  final bool exact;
}

/// The answer for [targetKg]: the load (the nearest makeable weight at or
/// below it when it cannot be made), and the nearest makeable weights below
/// and above when it cannot.
class PlateAnswer {
  const PlateAnswer({required this.load, this.below, this.above});

  final PlateLoad load;
  final double? below;
  final double? above;

  bool get exact => load.exact;
}

/// Quarter-kilograms, so every plate size is a whole number.
int _q(double kg) => (kg * 4).round();
double _kg(int q) => q / 4;

/// "62.5", "60", "1.25".
String kgText(double kg) {
  if (kg == kg.roundToDouble()) return kg.toStringAsFixed(0);
  final two = kg.toStringAsFixed(2);
  return two.endsWith('0') ? kg.toStringAsFixed(1) : two;
}

/// The fewest plates per side for every side weight up to [maxQ] quarter-kg
/// (null where none adds up), with the plate added last to rebuild them.
({List<int?> count, List<int> last}) _table(List<int> plates, int maxQ) {
  final count = List<int?>.filled(maxQ + 1, null);
  final last = List<int>.filled(maxQ + 1, 0);
  count[0] = 0;
  for (var w = 1; w <= maxQ; w++) {
    for (final p in plates) {
      if (p > w) continue;
      final before = count[w - p];
      if (before == null) continue;
      final c = count[w];
      if (c == null || before + 1 < c) {
        count[w] = before + 1;
        last[w] = p;
      }
    }
  }
  return (count: count, last: last);
}

List<double> _rebuild(List<int> last, int w) {
  final out = <double>[];
  for (var at = w; at > 0; at -= last[at]) {
    out.add(_kg(last[at]));
  }
  return out..sort((a, b) => b.compareTo(a));
}

/// Which plates make [targetKg] on [gym]'s bar, with the fewest plates.
/// Below the bar it is the bar alone (not exact).
PlateAnswer platesFor(double targetKg, GymPlates gym) {
  final bar = _q(gym.barKg);
  final plates = [for (final p in gym.plates) _q(p)];
  final target = _q(targetKg);
  if (target <= bar || plates.isEmpty) {
    final load =
        PlateLoad(perSide: const [], totalKg: gym.barKg, exact: target == bar);
    if (load.exact) return PlateAnswer(load: load);
    // Lighter than the bar: the bar is the nearest weight above.
    return target < bar
        ? PlateAnswer(load: load, above: gym.barKg)
        : PlateAnswer(load: load, below: gym.barKg);
  }
  // One side; an odd total cannot be split, so look either way of it.
  final side = (target - bar) ~/ 2;
  final reach = side + (plates.reduce((a, b) => a > b ? a : b));
  final t = _table(plates, reach);
  final exact = (target - bar).isEven && t.count[side] != null;
  int? lower;
  for (var w = side; w >= 0; w--) {
    if (t.count[w] != null) {
      lower = w;
      break;
    }
  }
  final low = lower ?? 0;
  final load = PlateLoad(
    perSide: _rebuild(t.last, low),
    totalKg: _kg(bar + 2 * low),
    exact: exact,
  );
  if (exact) return PlateAnswer(load: load);
  int? upper;
  for (var w = side + 1; w <= reach; w++) {
    if (t.count[w] != null) {
      upper = w;
      break;
    }
  }
  return PlateAnswer(
    load: load,
    below: _kg(bar + 2 * low),
    above: upper == null ? null : _kg(bar + 2 * upper),
  );
}
