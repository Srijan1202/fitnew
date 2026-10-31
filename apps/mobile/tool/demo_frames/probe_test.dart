// Prints where a demo's knee and hand are over a loop (tuning aid).
// ignore_for_file: avoid_print
import 'package:fitos/features/exercise/domain/demo/demo_rig.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe', () {
    for (final slug in ['conventional-deadlift', 'romanian-deadlift']) {
      final d = exerciseDemos[slug]!;
      print(slug);
      for (var t = 0.0; t < d.period; t += d.period / 16) {
        final f = d.at(t);
        print('  t=${t.toStringAsFixed(2)} knee=(${f[Joint.knee].dx.toStringAsFixed(2)}, '
            '${f[Joint.knee].dy.toStringAsFixed(2)}) hand=(${f[Joint.hand].dx.toStringAsFixed(2)}, '
            '${f[Joint.hand].dy.toStringAsFixed(2)}) hip=(${f[Joint.hip].dx.toStringAsFixed(2)}, '
            '${f[Joint.hip].dy.toStringAsFixed(2)})');
      }
    }
  });
}
