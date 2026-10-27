import 'run_math.dart';
import 'track.dart';

/// Beta 4.0: kilometres (the default) or miles. Only how numbers are shown;
/// every figure stays in metres and seconds.
enum DistanceUnit {
  km,
  mi;

  double get metres => this == km ? 1000 : mileM;
  String get label => this == km ? 'km' : 'mi';
  String get paceLabel => this == km ? '/km' : '/mi';

  static DistanceUnit parse(String? s) => s == 'mi' ? mi : km;
}

/// "5.24" (two decimals under 100, one above).
String formatDistance(double metres, DistanceUnit unit) {
  final v = metres / unit.metres;
  return v >= 100 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
}

/// "1:05:09" or "25:09".
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return h > 0
      ? '$h:$mm:${r.toString().padLeft(2, '0')}'
      : '$mm:${r.toString().padLeft(2, '0')}';
}

/// A pace in seconds per km shown in the unit: "5:42"; "–:––" without one.
String formatPace(double? secPerKm, DistanceUnit unit) {
  if (secPerKm == null || !secPerKm.isFinite || secPerKm <= 0) return '–:––';
  final perUnit = jsRound(secPerKm * unit.metres / 1000);
  if (perUnit >= 100 * 60) return '–:––';
  return '${perUnit ~/ 60}:${(perUnit % 60).toString().padLeft(2, '0')}';
}

/// A pace already per unit (a split's own): "5:42".
String formatUnitPace(double secPerUnit) {
  final s = jsRound(secPerUnit);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Speed in km/h or mph: "10.6".
String formatSpeed(double? metresPerSecond, DistanceUnit unit) {
  if (metresPerSecond == null) return '–';
  return (metresPerSecond * 3600 / unit.metres).toStringAsFixed(1);
}
