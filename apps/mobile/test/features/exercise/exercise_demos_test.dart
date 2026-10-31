import 'dart:convert';
import 'dart:io';

import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/exercise/domain/demo/demo_rig.dart';
import 'package:fitos/features/exercise/domain/demo/exercise_demos.dart';
import 'package:fitos/features/exercise/presentation/widgets/exercise_demo_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 5.0 (owner): the exercise demos — each a believable lift, tied to
/// the library's own cues, and drawn the same every time (goldens).
void main() {
  final library = {
    for (final e in (jsonDecode(
      File('../../database/seeds/exercises.json').readAsStringSync(),
    ) as List))
      (e as Map<String, dynamic>)['slug'] as String: e,
  };

  test('29 lifts, every one in the library; every variant points at a demo',
      () {
    expect(exerciseDemos, hasLength(29));
    for (final slug in exerciseDemos.keys) {
      expect(library.containsKey(slug), isTrue, reason: slug);
    }
    for (final MapEntry(key: slug, value: (target, note))
        in demoVariants.entries) {
      expect(library.containsKey(slug), isTrue, reason: slug);
      expect(exerciseDemos.containsKey(target), isTrue, reason: slug);
      expect(note, isNotEmpty);
      expect(demoFor(slug)!.note, note);
    }
    expect(demoFor('barbell-back-squat')!.note, isNull);
    expect(demoFor('sissy-squat'), isNull);
  });

  test('every key moment shows one of its lift\'s cues, in order, all used',
      () {
    for (final MapEntry(key: slug, value: demo) in exerciseDemos.entries) {
      final n = (library[slug]!['instructions'] as List).length;
      final cues = [
        for (final f in demo.frames)
          if (f.cue != null) f.cue!,
      ];
      expect(cues, isNotEmpty, reason: slug);
      for (final c in cues) {
        expect(c, inInclusiveRange(0, n - 1), reason: slug);
      }
      expect([...cues]..sort(), cues, reason: '$slug: in order');
      expect(cues.toSet().length, cues.length, reason: '$slug: once each');
    }
  });

  test('nothing goes through the floor; limbs reach what they hold', () {
    for (final MapEntry(key: slug, value: demo) in exerciseDemos.entries) {
      for (var t = 0.0; t < demo.period; t += demo.period / 60) {
        final pose = demo.poseAt(t);
        final f = demo.solve(pose);
        expect(f.lowest, greaterThan(-0.02), reason: '$slug at $t');
        final bones = [
          (Joint.shoulder, Joint.elbow, Body.upperArm),
          (Joint.elbow, Joint.hand, Body.forearm),
          (Joint.knee, Joint.ankle, Body.shin),
        ];
        if (demo.view == DemoView.side) {
          bones.add((Joint.hip, Joint.knee, Body.thigh));
          bones.add((Joint.hip, Joint.shoulder, Body.torso));
        }
        for (final (a, b, len) in bones) {
          expect(
            (f[a] - f[b]).distance,
            closeTo(len, 1e-6),
            reason: '$slug $a-$b',
          );
        }
        // A hand or foot sent to a point gets there (the lifts keep their
        // targets within reach).
        if (pose.hands != null) {
          final target = pose.handsFrom == null
              ? pose.hands!
              : f[pose.handsFrom!] + pose.hands!;
          expect(
            (f[Joint.hand] - target).distance,
            lessThan(0.01),
            reason: '$slug hands at $t',
          );
        }
        if (pose.feet != null && demo.view == DemoView.side) {
          expect(
            (f[Joint.ankle] - pose.feet!).distance,
            lessThan(0.01),
            reason: '$slug feet at $t',
          );
        }
      }
    }
  });

  test('standing feet stay planted; a squat\'s or press\'s bar goes straight',
      () {
    double drift(String slug, Joint j) {
      final d = exerciseDemos[slug]!;
      final xs = [
        for (var t = 0.0; t < d.period; t += d.period / 60) d.at(t)[j].dx,
      ];
      return xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
    }

    for (final slug in [
      'barbell-back-squat',
      'goblet-squat',
      'conventional-deadlift',
      'romanian-deadlift',
      'overhead-press',
    ]) {
      expect(drift(slug, Joint.ankle), lessThan(0.01), reason: slug);
      expect(exerciseDemos[slug]!.at(0)[Joint.toe].dy, lessThan(0.05));
    }
    expect(drift('barbell-back-squat', Joint.upperBack), lessThan(0.08));
    expect(drift('conventional-deadlift', Joint.hand), lessThan(0.01));
    // Beta 5.0.1: the bar goes forward around the face, then back over
    // mid-foot.
    expect(drift('overhead-press', Joint.hand), lessThan(0.15));
  });

  test('the loop: key moments in time order, the pose at a key moment is it',
      () {
    for (final demo in exerciseDemos.values) {
      final times = demo.times;
      for (var i = 0; i < times.length; i++) {
        final p = demo.poseAt(times[i] + 1e-9);
        expect(p.trunk, closeTo(demo.frames[i].trunk, 1e-3));
        if (i > 0) expect(times[i], greaterThan(times[i - 1]));
      }
      expect(demo.period, greaterThan(times.last));
    }
  });

  group('the view', () {
    Widget host(Widget child, {bool still = false}) => MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: still),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Center(child: SizedBox(width: 280, child: child)),
                ),
              ),
            ),
          ),
        );
    Offset hip(WidgetTester tester) => (tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('demo.canvas')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter! as DemoPainter)
        .figure[Joint.shoulder];
    final squat = exerciseDemos['barbell-back-squat']!;

    testWidgets(
        'loops; tap pauses; a key moment shows that cue; Slow halves the pace',
        (tester) async {
      await tester.pumpWidget(
        host(ExerciseDemoView(demo: squat, name: 'Barbell Back Squat')),
      );
      // One chip per cue, numbered as the written steps.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Demo of Barbell Back Squat'),
        findsOneWidget,
      );
      Future<bool> moving() async {
        final before = hip(tester);
        await tester.pump(const Duration(milliseconds: 700));
        return hip(tester) != before;
      }

      await tester.pump(const Duration(milliseconds: 16));
      expect(await moving(), isTrue);
      await tester.tap(find.byKey(const ValueKey('demo.pause')));
      await tester.pump();
      expect(await moving(), isFalse);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('demo.pause')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(await moving(), isTrue);
      // The bottom: still, its chip selected.
      await tester.tap(find.byKey(const ValueKey('demo.moment.2')));
      await tester.pump();
      expect(await moving(), isFalse);
      expect(
        hip(tester),
        squat.solve(squat.frames[2])[Joint.shoulder],
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('demo.moment.2')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('demo.slow')));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('demo.slow')))
            .selected,
        isTrue,
      );
    });

    testWidgets('Remove animations: still pictures to step through, no loop',
        (tester) async {
      await tester.pumpWidget(
        host(
          ExerciseDemoView(demo: squat, name: 'Squat', note: 'Palms in.'),
          still: true,
        ),
      );
      final first = hip(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(hip(tester), first);
      expect(find.byKey(const ValueKey('demo.pause')), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('demo.moment.0')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('demo.moment.1')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('demo.moment.1')))
            .selected,
        isTrue,
      );
      expect(find.text('Palms in.'), findsOneWidget);
    });

    testWidgets('three loops, then it rests on the start with Play',
        (tester) async {
      await tester.pumpWidget(
        host(ExerciseDemoView(demo: squat, name: 'Squat')),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(hip(tester), squat.solve(squat.frames[0])[Joint.shoulder]);
    });

    testWidgets('a hold (plank) says HOLD and has no Slow', (tester) async {
      await tester.pumpWidget(
        host(ExerciseDemoView(demo: exerciseDemos['plank']!, name: 'Plank')),
      );
      expect(find.text('HOLD'), findsOneWidget);
      expect(find.byKey(const ValueKey('demo.slow')), findsNothing);
    });
  });

  group('goldens', () {
    for (final MapEntry(key: slug, value: demo) in exerciseDemos.entries) {
      testWidgets(slug, (tester) async {
        final bounds = demoBounds(demo);
        const p = FitPalette.dark;
        await tester.binding.setSurfaceSize(
          Size(240.0 * demo.frames.length, 260),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: p.paper,
              child: RepaintBoundary(
                key: const ValueKey('golden'),
                child: Row(
                  children: [
                    for (final f in demo.frames)
                      SizedBox(
                        width: 240,
                        height: 260,
                        child: CustomPaint(
                          painter: DemoPainter(
                            demo: demo,
                            figure: demo.solve(f),
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
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('goldens/demo_$slug.png'),
        );
      });
    }
  });
}
