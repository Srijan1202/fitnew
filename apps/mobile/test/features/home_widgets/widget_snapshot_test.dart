import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/home/data/streak_api.dart';
import 'package:fitos/features/home_widgets/domain/widget_snapshot.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/running/domain/units.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 5.0 (owner): what the home-screen widgets are given.
void main() {
  // 2026-11-02 is a Monday.
  const today = '2026-11-02';

  ProgramDay day(int dow, String name, {bool rest = false, int n = 6}) =>
      ProgramDay(
        id: 'd$dow',
        dayOfWeek: dow,
        sessionName: name,
        focus: const [],
        isRest: rest,
        estimatedMinutes: 50,
        exercises: List.generate(n, (_) => _exercise),
      );

  final program = Program(
    id: 'p',
    name: 'Upper / lower',
    splitType: SplitType.fullBody,
    daysPerWeek: 3,
    source: ProgramSource.generated,
    templateSlug: null,
    mesocycleWeek: 1,
    active: true,
    createdAt: '2026-10-01T00:00:00Z',
    days: [
      day(1, 'Upper A'),
      day(3, 'Lower A', n: 1),
      day(7, 'Rest', rest: true),
    ],
    weeklyVolume: const {},
    rationale: const [],
    shortfalls: const [],
  );

  PlannedRun run(
    String date, {
    PlannedRunStatus status = PlannedRunStatus.planned,
  }) =>
      PlannedRun(
        id: 'r$date',
        date: date,
        week: 1,
        kind: 'easy',
        title: 'Easy run',
        distanceM: 5000,
        seconds: null,
        pace: null,
        steps: null,
        note: '',
        status: status,
        runId: null,
        movedFrom: null,
      );

  RunningPlan plan(List<PlannedRun> runs) => RunningPlan(
        id: 'rp',
        goal: '5k',
        level: 'beginner',
        weeks: 8,
        weekdays: const [2, 4],
        longRunWeekday: 6,
        startDate: '2026-10-26',
        zones: null,
        predictedSeconds: null,
        gymOverlap: const [],
        runs: runs,
      );

  RemainingRange range(double target, double left, RemainingState s) =>
      RemainingRange(target: target, low: left, high: left, state: s);

  final food = NutritionDay(
    date: today,
    today: today,
    timezone: 'Asia/Kolkata',
    targets: null,
    totals: const NutritionTotals(
      kcalLow: 1200,
      kcalHigh: 1200,
      proteinLow: 80,
      proteinHigh: 80,
      carbLow: 0,
      carbHigh: 0,
      fatLow: 0,
      fatHigh: 0,
      fibreKnownLow: 0,
      fibreKnownHigh: 0,
      fibreUnknownItems: 0,
      itemCount: 3,
    ),
    remaining: NutritionRemaining(
      kcal: range(2200, 1000, RemainingState.under),
      protein: range(140, 60, RemainingState.under),
      carb: range(250, 100, RemainingState.under),
      fat: range(70, 30, RemainingState.under),
    ),
    logs: const [],
  );

  Map<String, Object?> build({
    NutritionDay? f,
    Program? p,
    RunningPlan? r,
    Streak? s,
    bool done = false,
  }) =>
      WidgetSnapshot.build(
        today: today,
        food: f,
        program: p,
        runningPlan: r,
        streak: s,
        workoutDoneToday: done,
        unit: DistanceUnit.km,
      );

  List<Map<String, Object?>> week(Map<String, Object?> s) =>
      (s['week']! as List).cast<Map<String, Object?>>();

  test('signed out: nothing but that', () {
    expect(WidgetSnapshot.signedOut(), {'v': 1, 'signedIn': false});
  });

  test('food: what is left as the app words it, the share eaten, the targets',
      () {
    final f = build(f: food)['food']! as Map<String, Object?>;
    expect(f['date'], today);
    expect(f['leftValue'], '1,000');
    expect(f['leftCaption'], 'kcal left of 2,200');
    expect(f['protein'], 'Protein 60 g left');
    expect(f['kcalTarget'], 2200);
    expect(f['proteinTarget'], 140);
    expect(f['eatenShare'], closeTo(1200 / 2200, 1e-9));
    expect(f['over'], false);
    // Another day's food is never shown as today's.
    expect(
      build(f: food.copyWith(date: '2026-11-01')).containsKey('food'),
      isFalse,
    );
  });

  test('the week: workouts by weekday, a run on its date wins, rest, none', () {
    final s = build(
      p: program,
      r: plan([
        run('2026-11-03'),
        run('2026-11-05', status: PlannedRunStatus.skipped),
      ]),
      done: true,
    );
    final w = week(s);
    expect(w, hasLength(7));
    expect(w.map((d) => d['date']), [
      '2026-11-02',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
      '2026-11-07',
      '2026-11-08',
    ]);
    expect(w[0], {
      'date': '2026-11-02',
      'kind': 'workout',
      'title': 'Upper A',
      'detail': '6 exercises · about 50 min',
      'done': true,
    });
    expect(w[1]['kind'], 'run');
    expect(w[1]['detail'], '5.00 km');
    expect(w[2]['detail'], '1 exercise · about 50 min');
    expect(w[2]['done'], false, reason: 'done is today only');
    // A skipped run leaves the day to the programme (Thursday: nothing).
    expect(w[3]['kind'], 'rest');
    expect(w[6]['title'], 'Rest day');
    // No programme at all.
    expect(week(build())[0]['kind'], 'none');
  });

  test('the streak: the count, today, the last 14 days', () {
    final s = build(
      s: Streak(
        current: 12,
        best: 20,
        todayCounted: true,
        weekDone: null,
        weekPlanned: null,
        calendar: [
          for (var i = 0; i < 20; i++)
            StreakDay(
              WidgetSnapshot.addDays('2026-10-14', i),
              StreakDayStatus.logged,
            ),
        ],
      ),
    )['streak']! as Map<String, Object?>;
    expect(s['current'], 12);
    expect(s['todayCounted'], true);
    final days = (s['days']! as List).cast<Map<String, Object?>>();
    expect(days, hasLength(14));
    expect(days.last, {'date': '2026-11-02', 'status': 'logged'});
  });

  test('dates and taps', () {
    expect(WidgetSnapshot.addDays('2026-12-31', 1), '2027-01-01');
    expect(WidgetTarget.fromLink('fitos://widget/food'), WidgetTarget.food);
    expect(WidgetTarget.fromLink('fitos://widget/streak'), WidgetTarget.streak);
    expect(WidgetTarget.fromLink('fitos://other/food'), isNull);
    expect(WidgetTarget.fromLink('https://widget/food'), isNull);
    expect(WidgetTarget.fromLink('fitos://widget/nope'), isNull);
    expect(slotAt(8), MealSlot.breakfast);
    expect(slotAt(13), MealSlot.lunch);
    expect(slotAt(17), MealSlot.snacks);
    expect(slotAt(21), MealSlot.dinner);
  });
}

const _exercise = PlannedExercise(
  id: 'e',
  exerciseId: 'x',
  slug: 'barbell-back-squat',
  name: 'Barbell Back Squat',
  movementPattern: MovementPattern.squat,
  equipment: [],
  difficulty: Difficulty.intermediate,
  isUnilateral: false,
  primaryMuscles: [],
  orderIndex: 0,
  setCount: 3,
  repMin: 6,
  repMax: 10,
  targetRir: 2,
  incrementKg: 2.5,
  reason: null,
  sets: [],
);
