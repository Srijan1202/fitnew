// Lists every demo moment that breaks the suite's rig checks (tuning aid).
// ignore_for_file: avoid_print
import 'package:fitos/features/exercise/domain/demo/demo_rig.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reach', () {
    for (final MapEntry(key: slug, value: demo) in exerciseDemos.entries) {
      final bad = <String>{};
      for (var t = 0.0; t < demo.period; t += demo.period / 60) {
        final pose = demo.poseAt(t);
        final f = demo.solve(pose);
        if (f.lowest <= -0.02) bad.add('floor ${f.lowest.toStringAsFixed(3)}');
        if (pose.hands != null) {
          final target = pose.handsFrom == null
              ? pose.hands!
              : f[pose.handsFrom!] + pose.hands!;
          final miss = (f[Joint.hand] - target).distance;
          if (miss >= 0.01) bad.add('hands ${miss.toStringAsFixed(3)}');
        }
        if (pose.feet != null && demo.view == DemoView.side) {
          final miss = (f[Joint.ankle] - pose.feet!).distance;
          if (miss >= 0.01) bad.add('feet ${miss.toStringAsFixed(3)}');
        }
      }
      if (bad.isNotEmpty) print('$slug: ${bad.take(4).join(', ')}');
    }
  });
}
