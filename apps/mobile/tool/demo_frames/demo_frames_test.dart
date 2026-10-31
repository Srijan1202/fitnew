// Beta 5.0.1 (owner): renders every exercise demo as frames, for the review
// page (not part of the suite: it lives outside test/). Run:
//   flutter test --update-goldens tool/demo_frames/demo_frames_test.dart
// Frames land in tool/demo_frames/out/<slug>/NNN.png (git-ignored).
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';
import 'package:fitos/features/exercise/presentation/widgets/exercise_demo_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fps = 20;
const width = 360.0;
const height = 400.0;

void main() {
  for (final MapEntry(key: slug, value: demo) in exerciseDemos.entries) {
    testWidgets(slug, (tester) async {
      final bounds = demoBounds(demo);
      const p = FitPalette.dark;
      await tester.binding.setSurfaceSize(const Size(width, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final frames = (demo.period * fps).ceil();
      for (var i = 0; i < frames; i++) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('frame'),
              child: ColoredBox(
                color: p.paper,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    painter: DemoPainter(
                      demo: demo,
                      figure: demo.at(i / fps),
                      bounds: bounds,
                      ink: p.ink,
                      dim: p.ink35,
                      accent: p.accent,
                      rule: p.rule,
                      paper: p.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('frame')),
          matchesGoldenFile('out/$slug/${i.toString().padLeft(3, '0')}.png'),
        );
      }
    });
  }
}
