// Beta 5.6: one strip of a demo's loop per slug, for redrawing demos (not
// part of the suite: it lives outside test/). The slugs come from
// tool/demo_frames/sheet_slugs.txt (one per line; empty: every demo). Run:
//   flutter test --update-goldens tool/demo_frames/sheet_test.dart
// Strips land in tool/demo_frames/sheets/<slug>.png (git-ignored).
import 'dart:io';

import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';
import 'package:fitos/features/exercise/presentation/widgets/exercise_demo_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const count = 8;
const width = 150.0;
const height = 170.0;

void main() {
  // Beta 5.6: the demos' labels (a floor press's 45°) in the app's font.
  setUpAll(() async {
    final barlow = FontLoader('Barlow')
      ..addFont(rootBundle.load('assets/fonts/Barlow-Bold.ttf'));
    await barlow.load();
  });

  final listed = File('tool/demo_frames/sheet_slugs.txt').existsSync()
      ? File('tool/demo_frames/sheet_slugs.txt')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList()
      : <String>[];
  final slugs = listed.isEmpty ? exerciseDemos.keys.toList() : listed;
  for (final slug in slugs) {
    testWidgets(slug, (tester) async {
      final demo = exerciseDemos[slug]!;
      final bounds = demoBounds(demo);
      const p = FitPalette.dark;
      await tester.binding.setSurfaceSize(const Size(width * count, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: ColoredBox(
              color: p.paper,
              child: Row(
                children: [
                  for (var i = 0; i < count; i++)
                    SizedBox(
                      width: width,
                      height: height,
                      child: CustomPaint(
                        painter: DemoPainter(
                          demo: demo,
                          figure: demo.at(demo.period * i / count),
                          bounds: bounds,
                          ink: p.ink,
                          dim: p.ink35,
                          accent: p.accent,
                          rule: p.rule,
                          paper: p.paper,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('sheets/$slug.png'),
      );
    });
  }
}
