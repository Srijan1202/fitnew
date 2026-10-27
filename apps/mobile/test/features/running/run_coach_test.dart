import 'package:fitos/features/running/domain/coach.dart';
import 'package:fitos/features/running/domain/units.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/running/domain/workout_runner.dart';
import 'package:fitos/features/running/presentation/screens/run_start.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 4.1 (ADR-039): what the voice coach says and when, a session walked
/// step by step, and sprint sessions.
void main() {
  CoachInput at(
    int seconds,
    double metres, {
    double? now,
    double? avg,
    double? lastSplit,
    String goal = 'free',
    int? value,
    PaceRange? target,
  }) =>
      CoachInput(
        activeSeconds: seconds,
        distanceM: metres,
        avgPaceSecPerKm:
            avg ?? (metres < 10 ? null : seconds / (metres / 1000)),
        currentPaceSecPerKm: now,
        lastSplitSeconds: lastSplit,
        goalKind: goal,
        goalValue: value,
        target: target,
      );

  group('words', () {
    test('durations and paces as said aloud', () {
      expect(spokenDuration(45), '45 seconds');
      expect(spokenDuration(60), '1 minute');
      expect(spokenDuration(1630), '27 minutes 10');
      expect(spokenDuration(3900), '1 hour 5 minutes');
      expect(spokenPace(340), '5 40');
      expect(spokenPace(305), '5 05');
    });
  });

  group('splits', () {
    test('every km: distance, time, the last km and the average', () {
      final c = Coach(settings: const CoachSettings(), unit: DistanceUnit.km);
      expect(c.tick(at(300, 900)), isEmpty);
      expect(
        c.tick(at(340, 1001, lastSplit: 340)),
        ['1 kilometre. 5 minutes 40. Last kilometre 5 40. Average 5 40.'],
      );
      expect(c.tick(at(341, 1004)), isEmpty);
    });

    test('every half too when asked; miles in miles', () {
      final half = Coach(
        settings: const CoachSettings(everyHalf: true),
        unit: DistanceUnit.km,
      );
      expect(
        half.tick(at(170, 501)).single,
        startsWith('0.5 kilometres. 2 minutes 50.'),
      );
      final miles =
          Coach(settings: const CoachSettings(), unit: DistanceUnit.mi);
      expect(
        miles.tick(at(600, 1610, lastSplit: 600)).single,
        '1 mile. 10 minutes. Last mile 10 00. Average 10 00.',
      );
    });

    test('off, or splits off', () {
      expect(
        Coach(
          settings: const CoachSettings(enabled: false),
          unit: DistanceUnit.km,
        ).tick(at(340, 1001)),
        isEmpty,
      );
      expect(
        Coach(
          settings: const CoachSettings(splits: false),
          unit: DistanceUnit.km,
        ).tick(at(340, 1001)),
        isEmpty,
      );
    });
  });

  group('pace', () {
    const target = PaceRange(330, 340);

    test('30 s fast: ease off; then not again for a minute', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      expect(c.tick(at(100, 1200, now: 300, target: target)), isEmpty);
      expect(c.tick(at(129, 1300, now: 300, target: target)), isEmpty);
      expect(
        c.tick(at(130, 1310, now: 300, target: target)),
        ['About 30 seconds fast. Ease off a little.'],
      );
      expect(c.tick(at(170, 1500, now: 300, target: target)), isEmpty);
      expect(
        c.tick(at(191, 1600, now: 300, target: target)),
        ['About 30 seconds fast. Ease off a little.'],
      );
    });

    test(
        'slow: pick it up; inside the tolerance nothing; back on pace resets the hold',
        () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      c.tick(at(100, 1200, now: 360, target: target));
      c.tick(at(120, 1250, now: 345, target: target));
      expect(c.tick(at(131, 1300, now: 360, target: target)), isEmpty);
      expect(
        c.tick(at(161, 1400, now: 362, target: target)),
        ['About 22 seconds slow. Pick it up a little.'],
      );
      expect(c.tick(at(400, 2000, now: 348, target: target)), isEmpty);
    });

    test('start guidance once, in the first km, a minute in, well under target',
        () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      expect(c.tick(at(30, 100, now: 290, target: target)), isEmpty);
      expect(
        c.tick(at(60, 220, now: 290, target: target)),
        ["Easy start. Hold back for now, you'll thank yourself later."],
      );
      expect(c.tick(at(61, 223, now: 290, target: target)), isEmpty);
    });

    test('no target, or no current pace: silent', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      expect(c.tick(at(130, 500, now: 200)), isEmpty);
      expect(c.tick(at(130, 500, target: target)), isEmpty);
    });

    test('the target: a work step’s, else the plan’s, else a pace goal’s', () {
      const step = WorkoutStep(
        kind: StepKind.work,
        distanceM: 400,
        pace: PaceRange(230, 240),
      );
      const rest = WorkoutStep(kind: StepKind.recover, seconds: 90);
      expect(
        targetPace(step: step, goalKind: 'free', goalValue: null)!.fast,
        230,
      );
      expect(
        targetPace(
          step: rest,
          planned: target,
          goalKind: 'free',
          goalValue: null,
        ),
        isNull,
      );
      expect(
        targetPace(planned: target, goalKind: 'free', goalValue: null),
        target,
      );
      expect(
        targetPace(goalKind: 'pace', goalValue: 300, planned: null)!.slow,
        305,
      );
      expect(targetPace(goalKind: 'free', goalValue: null), isNull);
    });
  });

  group('goals', () {
    test('a distance goal: halfway, the last km, on track, reached', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      const t = PaceRange(330, 340);
      expect(
        c.tick(
          at(
            800,
            2500,
            goal: 'distance',
            value: 5000,
            avg: 330,
            target: t,
          ),
        ),
        ['Halfway. 2.5 kilometres to go.'],
      );
      expect(
        c.tick(
          at(
            1100,
            3400,
            goal: 'distance',
            value: 5000,
            avg: 335,
            target: t,
          ),
        ),
        ['On track. Hold this or pick it up to the finish.'],
      );
      expect(
        c.tick(
          at(
            1330,
            4010,
            goal: 'distance',
            value: 5000,
            avg: 335,
            target: t,
          ),
        ),
        ['One kilometre to go.'],
      );
      expect(
        c.tick(
          at(
            1660,
            5001,
            goal: 'distance',
            value: 5000,
            avg: 335,
            target: t,
          ),
        ),
        ['Goal reached. 5 kilometres in 27 minutes 40.'],
      );
      expect(
        c.tick(
          at(
            1700,
            5100,
            goal: 'distance',
            value: 5000,
            avg: 335,
            target: t,
          ),
        ),
        isEmpty,
      );
    });

    test('off target two thirds in: no "on track"', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      c.tick(
        at(
          800,
          2500,
          goal: 'distance',
          value: 5000,
          target: const PaceRange(330, 340),
        ),
      );
      expect(
        c.tick(
          at(
            1300,
            3400,
            goal: 'distance',
            value: 5000,
            avg: 380,
            target: const PaceRange(330, 340),
          ),
        ),
        isEmpty,
      );
    });

    test('a time goal: halfway, five minutes to go, reached', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      expect(
        c.tick(at(900, 2700, goal: 'time', value: 1800)),
        ['Halfway. 15 minutes to go.'],
      );
      expect(
        c.tick(at(1500, 4500, goal: 'time', value: 1800)),
        ['Five minutes to go.'],
      );
      expect(
        c.tick(at(1800, 5400, goal: 'time', value: 1800)),
        ['Goal reached. 30 minutes, 5.5 kilometres.'],
      );
    });

    test('a pace goal has no milestones', () {
      final c = Coach(
        settings: const CoachSettings(splits: false),
        unit: DistanceUnit.km,
      );
      expect(c.tick(at(900, 2700, goal: 'pace', value: 330)), isEmpty);
    });
  });

  group('session calls', () {
    final c = Coach(settings: const CoachSettings(), unit: DistanceUnit.km);

    test('each kind of step', () {
      expect(
        c.step(
          const WorkoutStep(kind: StepKind.warmup, seconds: 600),
          afterRest: false,
        ),
        'Warm-up. 10 minutes easy.',
      );
      expect(
        c.step(
          const WorkoutStep(
            kind: StepKind.work,
            distanceM: 400,
            pace: PaceRange(230, 240),
            repIndex: 3,
            repOf: 6,
          ),
          afterRest: true,
        ),
        'Go! Rep 3 of 6. 400 metres at 3 55.',
      );
      expect(
        c.step(
          const WorkoutStep(
            kind: StepKind.work,
            distanceM: 1000,
            effort: 'all out',
            repIndex: 1,
            repOf: 1,
          ),
          afterRest: false,
        ),
        '1 kilometre all out.',
      );
      expect(
        c.step(
          const WorkoutStep(
            kind: StepKind.recover,
            seconds: 90,
            effort: 'jog',
          ),
          afterRest: false,
        ),
        'Recover. 1 minute 30, jog.',
      );
      expect(
        c.step(
          const WorkoutStep(kind: StepKind.cooldown, seconds: 600),
          afterRest: false,
        ),
        'Cool-down. 10 minutes easy.',
      );
      expect(c.workoutDone(), 'Workout done. Well run.');
      expect(c.paused(), 'Paused.');
      expect(c.resumed(), 'Resumed.');
    });

    test('countdowns: 10 s left of a long timed step, 3-2-1 into a rep', () {
      const rest = WorkoutStep(kind: StepKind.recover, seconds: 90);
      expect(c.countdown(rest, 10, nextIsRep: true), '10 seconds.');
      expect(c.countdown(rest, 3, nextIsRep: true), 'Three. Two. One.');
      expect(c.countdown(rest, 3, nextIsRep: false), isNull);
      expect(
        c.countdown(
          const WorkoutStep(kind: StepKind.recover, seconds: 15),
          10,
          nextIsRep: true,
        ),
        isNull,
      );
      expect(
        c.countdown(
          const WorkoutStep(kind: StepKind.work, distanceM: 400),
          3,
          nextIsRep: true,
        ),
        isNull,
      );
      expect(
        Coach(
          settings: const CoachSettings(enabled: false),
          unit: DistanceUnit.km,
        ).countdown(rest, 3, nextIsRep: true),
        isNull,
      );
    });
  });

  group('a session, step by step', () {
    final w = sprintSession(3, 100, 60);

    test('sprints: warm-up, reps with standing rests between, cool-down', () {
      expect(w.name, 'Sprints: 3 × 100 m');
      expect(w.steps.map((s) => s.kind), [
        StepKind.warmup,
        StepKind.work,
        StepKind.recover,
        StepKind.work,
        StepKind.recover,
        StepKind.work,
        StepKind.cooldown,
      ]);
      expect(w.steps[1].effort, 'all out');
      expect(w.steps[2].effort, 'stand');
    });

    test(
        'steps end on time or distance; lap marks on the run clock; a jump past several steps',
        () {
      final r = WorkoutRunner(w);
      expect(r.current!.kind, StepKind.warmup);
      expect(r.left(distanceM: 0, activeSeconds: 100).secondsLeft, 500);
      expect(
        r.update(distanceM: 1500, activeSeconds: 599, clockT: 599),
        isEmpty,
      );
      expect(r.update(distanceM: 1600, activeSeconds: 600, clockT: 601), [1]);
      expect(r.left(distanceM: 1640, activeSeconds: 610).metresLeft, 60);
      expect(r.update(distanceM: 1700, activeSeconds: 615, clockT: 616), [2]);
      // A long gap (the phone asleep): the rest is over; the next rep starts
      // from where the runner is then, so it is not over too.
      expect(r.update(distanceM: 1820, activeSeconds: 700, clockT: 701), [3]);
      expect(r.marks.map((m) => [m.step, m.startT, m.endT]).toList(), [
        [0, 0.0, 601.0],
        [1, 601.0, 616.0],
        [2, 616.0, 701.0],
      ]);
      expect(r.next!.kind, StepKind.recover);
    });

    test('"Next step" by hand; finishing early closes the step; done', () {
      final r = WorkoutRunner(w);
      expect(r.skip(distanceM: 0, activeSeconds: 30, clockT: 30), 1);
      r.finish(50);
      expect(r.done, isTrue);
      expect(r.current, isNull);
      expect(r.marks.map((m) => m.step), [0, 1]);
      expect(r.skip(distanceM: 0, activeSeconds: 60, clockT: 60), isNull);
      expect(r.update(distanceM: 0, activeSeconds: 60, clockT: 60), isEmpty);
      r.finish(70);
      expect(r.marks, hasLength(2));
      expect(r.left(distanceM: 0, activeSeconds: 0).metresLeft, isNull);
    });

    test('skipping the last step ends the session', () {
      final r = WorkoutRunner(
        const RunWorkout(
          name: 'x',
          steps: [WorkoutStep(kind: StepKind.work, seconds: 60)],
        ),
      );
      expect(r.skip(distanceM: 0, activeSeconds: 10, clockT: 10), isNull);
      expect(r.done, isTrue);
    });

    test('a session restored mid-run picks up after its last mark', () {
      final r = WorkoutRunner(w)
        ..restore(
          const [LapMark(0, 0, 600), LapMark(1, 600, 630)],
          distanceM: 1700,
          activeSeconds: 630,
          clockT: 640,
        );
      expect(r.index, 2);
      expect(r.left(distanceM: 1700, activeSeconds: 650).secondsLeft, 40);
      final fresh = WorkoutRunner(w)
        ..restore(const [], distanceM: 0, activeSeconds: 0, clockT: 0);
      expect(fresh.index, 0);
    });
  });

  group('wire shapes', () {
    test('a workout and its steps round-trip; lap marks and laps parse', () {
      final w = sprintSession(2, 200, 90);
      final back = RunWorkout.fromJson(w.toJson());
      expect(back.steps.map((s) => s.toJson()), w.steps.map((s) => s.toJson()));
      expect(LapMark.fromJson(const LapMark(1, 2, 3).toJson()).endT, 3);
      expect(
        Lap.fromJson(const {
          'step': 1,
          'distanceM': 400,
          'seconds': 92,
          'pace': null,
        }).pace,
        isNull,
      );
      expect(StepKind.parse('nonsense'), StepKind.work);
      expect(PlannedRunStatus.parse('nonsense'), PlannedRunStatus.planned);
      expect(const PaceRange(300, 310).middle, 305);
    });
  });
}
