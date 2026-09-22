import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/auth/domain/entities/user_profile.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/workout/data/workout_api.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_exercise_repository.dart';
import '../support/fake_training_repository.dart';
import '../support/fake_onboarding_repository.dart';
import '../support/fake_workout_api.dart';

/// ADR-004: the Dart DTOs are hand-written, so this test is what stops them
/// drifting from `@fitos/contracts`. It reads the OpenAPI document the API
/// exports from the Zod schemas and checks, for every shape the client
/// speaks:
///
///   * each closed vocabulary here has exactly the server's members, in the
///     server's wire spelling;
///   * each response DTO serialises to exactly the property set the server
///     documents (no field the client cannot receive, none it would drop);
///   * each request DTO sends exactly the properties the server accepts.
///
/// A contract change that is not mirrored here fails ci-mobile.
void main() {
  late Map<String, dynamic> doc;

  setUpAll(() {
    // apps/mobile → repo root. `flutter test` runs from the package dir.
    final file = File('../../packages/contracts/openapi.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run `pnpm --filter @fitos/api openapi:export` first',
    );
    doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  Map<String, dynamic> schemaOf(
    String path,
    String method, {
    bool request = false,
  }) {
    final paths = doc['paths'] as Map<String, dynamic>;
    final op =
        (paths[path] as Map<String, dynamic>)[method] as Map<String, dynamic>;
    final holder = request
        ? op['requestBody'] as Map<String, dynamic>
        : ((op['responses'] as Map<String, dynamic>)['200']
            as Map<String, dynamic>);
    final content = holder['content'] as Map<String, dynamic>;
    final json = content['application/json'] as Map<String, dynamic>;
    return json['schema'] as Map<String, dynamic>;
  }

  Map<String, dynamic> properties(Map<String, dynamic> schema) =>
      schema['properties'] as Map<String, dynamic>;

  List<String> enumOf(Map<String, dynamic> schema) {
    final items = schema['items'];
    final source = items is Map<String, dynamic> ? items : schema;
    return (source['enum'] as List<dynamic>).cast<String>();
  }

  Set<String> keysOf(Map<String, dynamic> schema) =>
      properties(schema).keys.toSet();

  group('vocabularies match the server enums', () {
    late Map<String, dynamic> profile;
    late Map<String, dynamic> diet;
    late Map<String, dynamic> prefs;
    late Map<String, dynamic> state;

    setUpAll(() {
      profile = properties(schemaOf('/user/profile', 'get'));
      diet = properties(schemaOf('/user/diet-preferences', 'get'));
      prefs = properties(schemaOf('/user/preferences', 'get'));
      state = properties(schemaOf('/onboarding/state', 'get'));
    });

    void same<T extends Enum>(
      String what,
      List<T> values,
      String Function(T) wire,
      List<String> server,
    ) {
      expect(values.map(wire).toList(), server, reason: what);
    }

    test('GoalType', () {
      final goal = properties(schemaOf('/user/goal', 'get'))['goal']
          as Map<String, dynamic>;
      same(
        'goalType',
        GoalType.values,
        (g) => g.wire,
        enumOf(properties(goal)['goalType'] as Map<String, dynamic>),
      );
    });

    test('Sex, ExperienceLevel, ActivityLevel, TrainingLocation, Equipment',
        () {
      same(
        'sex',
        Sex.values,
        (s) => s.wire,
        enumOf(profile['sex'] as Map<String, dynamic>),
      );
      same(
        'experienceLevel',
        ExperienceLevel.values,
        (e) => e.wire,
        enumOf(profile['experienceLevel'] as Map<String, dynamic>),
      );
      same(
        'activityLevel',
        ActivityLevel.values,
        (a) => a.wire,
        enumOf(profile['activityLevel'] as Map<String, dynamic>),
      );
      same(
        'trainingLocation',
        TrainingLocation.values,
        (t) => t.wire,
        enumOf(profile['trainingLocation'] as Map<String, dynamic>),
      );
      same(
        'equipment',
        Equipment.values,
        (e) => e.wire,
        enumOf(profile['equipment'] as Map<String, dynamic>),
      );
    });

    test('DietType, Allergen, AllergySeverity, BudgetTier', () {
      same(
        'dietType',
        DietType.values,
        (d) => d.wire,
        enumOf(diet['dietType'] as Map<String, dynamic>),
      );
      final allergy = (diet['allergies'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      same(
        'allergen',
        Allergen.values,
        (a) => a.wire,
        enumOf(properties(allergy)['allergen'] as Map<String, dynamic>),
      );
      same(
        'severity',
        AllergySeverity.values,
        (s) => s.wire,
        enumOf(properties(allergy)['severity'] as Map<String, dynamic>),
      );
      same(
        'budgetTier',
        BudgetTier.values,
        (b) => b.wire,
        enumOf(diet['budgetTier'] as Map<String, dynamic>),
      );
    });

    test('Units', () {
      same(
        'units',
        Units.values,
        (u) => u.wire,
        enumOf(prefs['units'] as Map<String, dynamic>),
      );
    });

    test('OnboardingStage: stage includes complete, steps do not', () {
      same(
        'stage',
        OnboardingStage.values,
        (s) => s.wire,
        enumOf(state['stage'] as Map<String, dynamic>),
      );
      same(
        'answered',
        OnboardingStage.steps,
        (s) => s.wire,
        enumOf(state['answered'] as Map<String, dynamic>),
      );
      same(
        'missing',
        OnboardingStage.steps,
        (s) => s.wire,
        enumOf(state['missing'] as Map<String, dynamic>),
      );
    });

    test('ConsentType and the answer discriminator', () {
      final variants =
          (schemaOf('/onboarding/answer', 'post', request: true)['anyOf']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final steps = variants
          .map((v) => enumOf(properties(v)['step'] as Map<String, dynamic>))
          .map((e) => e.single)
          .toSet();
      expect(steps, OnboardingStage.steps.map((s) => s.wire).toSet());

      final about = variants.firstWhere(
        (v) =>
            enumOf(properties(v)['step'] as Map<String, dynamic>).single ==
            'about',
      );
      final consent = properties(about)['consent'] as Map<String, dynamic>;
      same(
        'consent.types',
        ConsentType.values,
        (c) => c.wire,
        enumOf(properties(consent)['types'] as Map<String, dynamic>),
      );
    });
  });

  group('response DTOs carry exactly the documented properties', () {
    test('UserProfile (auth session user)', () {
      final session = properties(schemaOf('/auth/session', 'post'));
      final user = session['user'] as Map<String, dynamic>;
      expect(testProfile.toJson().keys.toSet(), keysOf(user));
    });

    test('UserProfileDetail', () {
      expect(
        freshProfile.toJson().keys.toSet(),
        keysOf(schemaOf('/user/profile', 'get')),
      );
      final mess = properties(schemaOf('/user/profile', 'get'))['mess']
          as Map<String, dynamic>;
      const ref = MessRef(providerId: 'p', hostelId: 'h', messId: 'm');
      expect(ref.toJson().keys.toSet(), keysOf(mess));
    });

    test('GoalResponse, Goal, NutritionTargets', () {
      final goalResponse = schemaOf('/user/goal', 'get');
      final response =
          GoalResponse(goal: personaCGoal, targets: personaCTargets);
      expect(response.toJson().keys.toSet(), keysOf(goalResponse));
      expect(
        personaCGoal.toJson().keys.toSet(),
        keysOf(properties(goalResponse)['goal'] as Map<String, dynamic>),
      );
      expect(
        personaCTargets.toJson().keys.toSet(),
        keysOf(properties(goalResponse)['targets'] as Map<String, dynamic>),
      );
    });

    test('DietPreferences and Allergy', () {
      final diet = schemaOf('/user/diet-preferences', 'get');
      const value = DietPreferences(
        dietType: DietType.vegetarian,
        allergies: [
          Allergy(allergen: Allergen.milk, severity: AllergySeverity.mild),
        ],
        excludedDishIds: [],
        budgetTier: null,
      );
      expect(value.toJson().keys.toSet(), keysOf(diet));
      final allergy = (properties(diet)['allergies']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      expect(value.allergies.single.toJson().keys.toSet(), keysOf(allergy));
    });

    test('OnboardingState', () {
      expect(
        freshState.toJson().keys.toSet(),
        keysOf(schemaOf('/onboarding/state', 'get')),
      );
      expect(
        freshState.toJson().keys.toSet(),
        keysOf(schemaOf('/onboarding/answer', 'post')),
        reason: 'answer returns the same state shape',
      );
    });

    test('OnboardingCompleteResponse', () {
      final complete = OnboardingCompleteResponse(
        profile: freshProfile,
        goal: personaCGoal,
        targets: personaCTargets,
      );
      expect(
        complete.toJson().keys.toSet(),
        keysOf(schemaOf('/onboarding/complete', 'post')),
      );
    });
  });

  group('request DTOs send exactly the accepted properties', () {
    test('PutGoalRequest', () {
      const body = PutGoalRequest(goalType: GoalType.general);
      expect(
        body.toJson().keys.toSet(),
        keysOf(schemaOf('/user/goal', 'put', request: true)),
      );
    });

    test('every OnboardingAnswer variant', () {
      final variants =
          (schemaOf('/onboarding/answer', 'post', request: true)['anyOf']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      Map<String, dynamic> variant(String step) => variants.firstWhere(
            (v) =>
                enumOf(properties(v)['step'] as Map<String, dynamic>).single ==
                step,
          );

      const answers = <OnboardingAnswer>[
        OnboardingAnswer.goal(goalType: GoalType.fatLoss),
        OnboardingAnswer.about(
          displayName: 'Persona',
          sex: Sex.female,
          birthDate: '2005-03-14',
          heightCm: 160,
          weightKg: 58,
          consent: ConsentGrant(
            policyVersion: '2026-09-21',
            types: ConsentType.values,
          ),
        ),
        OnboardingAnswer.experience(
          experienceLevel: ExperienceLevel.beginner,
          trainingDaysPerWeek: 3,
          activityLevel: ActivityLevel.light,
        ),
        OnboardingAnswer.training(
          trainingLocation: TrainingLocation.campusGym,
          equipment: [Equipment.barbell],
        ),
        OnboardingAnswer.food(dietType: DietType.eggetarian, allergies: []),
        OnboardingAnswer.vit(isVitStudent: false, mess: null),
      ];
      for (final answer in answers) {
        final json = answer.toJson();
        final step = json['step'] as String;
        expect(json.keys.toSet(), keysOf(variant(step)), reason: step);
      }

      final consent =
          properties(variant('about'))['consent'] as Map<String, dynamic>;
      const grant = ConsentGrant(policyVersion: 'v', types: ConsentType.values);
      expect(grant.toJson().keys.toSet(), keysOf(consent));
    });
  });

  group('exercise library (Phase 3)', () {
    late Map<String, dynamic> detail;
    late List<Map<String, dynamic>> params;

    setUpAll(() {
      detail = properties(schemaOf('/exercises/{id}', 'get'));
      final op = ((doc['paths'] as Map<String, dynamic>)['/exercises']
          as Map<String, dynamic>)['get'] as Map<String, dynamic>;
      params = (op['parameters'] as List<dynamic>).cast<Map<String, dynamic>>();
    });

    Map<String, dynamic> param(String name) =>
        params.firstWhere((p) => p['name'] == name)['schema']
            as Map<String, dynamic>;

    test(
        'MuscleGroup, MovementPattern, Difficulty, MuscleRole, AlternativeReason, BodyPart',
        () {
      expect(
        MuscleGroup.values.map((m) => m.wire).toList(),
        enumOf(detail['primaryMuscles'] as Map<String, dynamic>),
      );
      expect(
        MovementPattern.values.map((p) => p.wire).toList(),
        enumOf(detail['movementPattern'] as Map<String, dynamic>),
      );
      expect(
        Difficulty.values.map((d) => d.wire).toList(),
        enumOf(detail['difficulty'] as Map<String, dynamic>),
      );
      final muscle = (detail['muscles'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(
        MuscleRole.values.map((r) => r.wire).toList(),
        enumOf(properties(muscle)['role'] as Map<String, dynamic>),
      );
      final alt = (detail['alternatives'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(
        AlternativeReason.values.map((r) => r.wire).toList(),
        enumOf(properties(alt)['reason'] as Map<String, dynamic>),
      );
      expect(
        BodyPart.values.map((b) => b.wire).toList(),
        enumOf(detail['contraindications'] as Map<String, dynamic>),
      );
    });

    test('ExerciseSummary, ExerciseDetail, ExerciseListResponse shapes', () {
      final list = schemaOf('/exercises', 'get');
      const page = ExerciseListResponse(
        items: [squat],
        total: 1,
        limit: 200,
        offset: 0,
      );
      expect(page.toJson().keys.toSet(), keysOf(list));
      final item = (properties(list)['items'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(squat.toJson().keys.toSet(), keysOf(item));
      expect(
        squatDetail.toJson().keys.toSet(),
        keysOf(schemaOf('/exercises/{id}', 'get')),
      );
      final muscle = (detail['muscles'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(squatDetail.muscles.first.toJson().keys.toSet(), keysOf(muscle));
      final alt = (detail['alternatives'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(squatDetail.alternatives.first.toJson().keys.toSet(), keysOf(alt));
    });

    test('ExerciseQuery sends exactly the documented query parameters', () {
      final documented = params.map((p) => p['name'] as String).toSet();
      const full = ExerciseQuery(
        q: 'x',
        equipment: {Equipment.barbell},
        muscle: MuscleGroup.chest,
        pattern: MovementPattern.squat,
      );
      expect(full.toQueryParameters().keys.toSet(), documented);
      // Equipment is the enum list, sent comma-separated; limit within bounds.
      expect(
        enumOf(param('equipment')),
        Equipment.values.map((e) => e.wire).toList(),
      );
      expect(
        const ExerciseQuery().limit,
        lessThanOrEqualTo(param('limit')['maximum'] as int),
      );
    });
  });

  group('training programme (Phase 4)', () {
    late Map<String, dynamic> program;

    setUpAll(() {
      program = schemaOf('/training/program', 'get');
    });

    test('SplitType, ProgramSource, ShortfallReason', () {
      final props = properties(program);
      expect(
        SplitType.values.map((s) => s.wire).toList(),
        enumOf(props['splitType'] as Map<String, dynamic>),
      );
      expect(
        ProgramSource.values.map((s) => s.wire).toList(),
        enumOf(props['source'] as Map<String, dynamic>),
      );
      final shortfall = (props['shortfalls'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(
        ShortfallReason.values.map((r) => r.wire).toList(),
        enumOf(properties(shortfall)['reason'] as Map<String, dynamic>),
      );
    });

    test('PlannedSet shape and the day/program day-of-week bounds', () {
      final day = (properties(program)['days'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      final px = (properties(day)['exercises'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      final set = (properties(px)['sets'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(plannedSquat.sets.first.toJson().keys.toSet(), keysOf(set));
    });

    test('templates: list item, preview day and preview exercise shapes', () {
      final list = schemaOf('/training/templates', 'get');
      final item = (properties(list)['items'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(pplTemplate.toJson().keys.toSet(), keysOf(item));
      final tday = (properties(item)['days'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(pplTemplate.days.first.toJson().keys.toSet(), keysOf(tday));
      expect(
        TemplateLevel.values.map((l) => l.wire).toList(),
        enumOf(properties(item)['level'] as Map<String, dynamic>),
      );

      final preview = schemaOf('/training/templates/{slug}', 'get');
      expect(pplPreview.toJson().keys.toSet(), keysOf(preview));
      final pday = (properties(preview)['days']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      expect(pplPreview.days.first.toJson().keys.toSet(), keysOf(pday));
      final pex = (properties(pday)['exercises']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      expect(
        pplPreview.days.first.exercises.first.toJson().keys.toSet(),
        keysOf(pex),
      );
      expect(
        Program.fromJson(
          jsonDecode(jsonEncode(generatedProgram.toJson()))
              as Map<String, dynamic>,
        ).source,
        ProgramSource.generated,
      );
    });

    test('Program, ProgramDay, PlannedExercise, VolumeShortfall shapes', () {
      expect(generatedProgram.toJson().keys.toSet(), keysOf(program));
      final day = (properties(program)['days'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(generatedProgram.days.first.toJson().keys.toSet(), keysOf(day));
      final px = (properties(day)['exercises'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(plannedSquat.toJson().keys.toSet(), keysOf(px));
      final shortfall = (properties(program)['shortfalls']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      expect(
        generatedProgram.shortfalls.first.toJson().keys.toSet(),
        keysOf(shortfall),
      );
      // Every day and exercise the server can send parses back.
      expect(
        Program.fromJson(
          jsonDecode(jsonEncode(generatedProgram.toJson()))
              as Map<String, dynamic>,
        ),
        generatedProgram,
      );
    });

    test('request bodies send exactly the accepted properties', () {
      // generate: the body is optional; when sent, only the two overrides.
      final gen = schemaOf('/training/program/generate', 'post', request: true);
      final variant = (gen['anyOf'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((v) => v.containsKey('properties'));
      const full = GenerateProgramRequest(
        daysPerWeek: 3,
        preferredSessionMinutes: 45,
      );
      expect(withoutNulls(full.toJson()).keys.toSet(), keysOf(variant));
      expect(withoutNulls(const GenerateProgramRequest().toJson()), isEmpty);

      // put: name + days; each day; each exercise (incrementKg optional).
      final put = schemaOf('/training/program', 'put', request: true);
      const exercise = CustomExercise(
        exerciseId: 'x',
        setCount: 3,
        repMin: 6,
        repMax: 12,
        targetRir: 2,
        incrementKg: 2.5,
        startingWeightKg: 40,
        sets: [
          CustomSet(repsMin: 10, repsMax: 10, weightKg: 40, rir: 2),
          CustomSet(repsMin: 10, repsMax: 10, weightKg: 40, rir: 2),
          CustomSet(repsMin: 8, repsMax: 8, weightKg: 42.5, rir: 1),
        ],
      );
      const body = PutProgramRequest(
        name: 'n',
        days: [
          CustomDay(dayOfWeek: 1, sessionName: 'A', exercises: [exercise]),
        ],
      );
      expect(body.toJson().keys.toSet(), keysOf(put));
      final day = (properties(put)['days'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(body.days.first.toJson().keys.toSet(), keysOf(day));
      final px = (properties(day)['exercises'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      expect(exercise.toJson().keys.toSet(), keysOf(px));
      expect(
        (px['required'] as List<dynamic>).cast<String>().toSet(),
        {'exerciseId', 'setCount', 'repMin', 'repMax', 'targetRir'},
        reason: 'increment, starting weight and per-set targets are optional',
      );
      final customSet = (properties(px)['sets']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      expect(exercise.sets!.first.toJson().keys.toSet(), keysOf(customSet));

      // patch: both optional; at least one sent.
      final patch = schemaOf(
        '/training/program/days/{id}',
        'patch',
        request: true,
      );
      const patchBody = PatchProgramDayRequest(
        sessionName: 's',
        focus: [MuscleGroup.chest],
        exercises: [exercise],
      );
      expect(withoutNulls(patchBody.toJson()).keys.toSet(), keysOf(patch));
      // rename
      final rename = schemaOf('/training/program', 'patch', request: true);
      expect(keysOf(rename), {'name'});
    });
  });

  group('workout logging (Phase 5)', () {
    late Map<String, dynamic> session;
    late Map<String, dynamic> sessionExercise;

    Map<String, dynamic> items(Map<String, dynamic> schema, String key) =>
        (properties(schema)[key] as Map<String, dynamic>)['items']
            as Map<String, dynamic>;

    setUpAll(() {
      session = schemaOf('/training/sessions', 'post');
      sessionExercise = items(session, 'exercises');
    });

    const sampleSet = SetLog(
      id: '00000000-0000-4000-8000-000000000001',
      clientSetId: '00000000-0000-4000-8000-000000000002',
      setIndex: 1,
      setType: SetType.working,
      weightKg: 60,
      reps: 10,
      rir: 2,
      isPr: false,
      loggedAt: '2026-09-21T10:00:00.000Z',
      plannedSetId: null,
    );
    const sampleExercise = SessionExercise(
      id: '00000000-0000-4000-8000-000000000003',
      clientExerciseId: '00000000-0000-4000-8000-000000000004',
      exerciseId: '11111111-1111-4111-8111-111111111111',
      slug: 'barbell-back-squat',
      name: 'Barbell Back Squat',
      movementPattern: MovementPattern.squat,
      equipment: [Equipment.barbell],
      difficulty: Difficulty.intermediate,
      primaryMuscles: [MuscleGroup.quads],
      secondaryMuscles: [MuscleGroup.hamstrings],
      incrementKg: 5,
      orderIndex: 0,
      supersetGroup: null,
      plannedExerciseId: null,
      targets: [
        PlannedSet(
          setIndex: 1,
          repsMin: 6,
          repsMax: 12,
          weightKg: null,
          rir: 1,
        ),
      ],
      prefill: [
        SetPrefill(
          setIndex: 1,
          reps: 12,
          weightKg: null,
          rir: 1,
          weightSource: 'none',
        ),
      ],
      lastPerformance: LastPerformance(
        sessionId: '00000000-0000-4000-8000-000000000005',
        completedAt: '2026-09-14T10:00:00.000Z',
        sets: [LastSet(setIndex: 1, weightKg: 60, reps: 10, rir: 2)],
      ),
      sets: [sampleSet],
    );
    const sampleSummary = SessionSummary(
      durationSeconds: 3300,
      totalSets: 1,
      workingSets: 1,
      tonnageKg: 600,
      hardSetsByMuscle: {'quads': 1},
      exercisesCompleted: 1,
      exercisesSkipped: 0,
      prs: [
        PersonalRecord(
          prType: PrType.weight,
          exerciseId: '11111111-1111-4111-8111-111111111111',
          exerciseName: 'Barbell Back Squat',
          value: 60,
          previous: 55,
          setLogId: '00000000-0000-4000-8000-000000000001',
          reason: 'r',
        ),
      ],
    );
    const sampleSession = WorkoutSession(
      id: '00000000-0000-4000-8000-000000000006',
      clientSessionId: '00000000-0000-4000-8000-000000000007',
      status: SessionStatus.completed,
      programId: null,
      programDayId: null,
      name: 'Legs',
      startedAt: '2026-09-21T10:00:00.000Z',
      completedAt: '2026-09-21T10:55:00.000Z',
      durationSeconds: 3300,
      notes: null,
      exercises: [sampleExercise],
      summary: sampleSummary,
    );

    test('SetType, SessionStatus, PrType', () {
      expect(
        SessionStatus.values.map((s) => s.wire).toList(),
        enumOf(properties(session)['status'] as Map<String, dynamic>),
      );
      final set = items(sessionExercise, 'sets');
      expect(
        SetType.values.map((s) => s.wire).toList(),
        enumOf(properties(set)['setType'] as Map<String, dynamic>),
      );
      final summary = properties(session)['summary'] as Map<String, dynamic>;
      final pr = items(summary, 'prs');
      expect(
        PrType.values.map((p) => p.wire).toList(),
        enumOf(properties(pr)['prType'] as Map<String, dynamic>),
      );
    });

    test(
        'session, exercise, set, last performance, prefill, summary and record shapes',
        () {
      expect(sampleSession.toJson().keys.toSet(), keysOf(session));
      expect(sampleExercise.toJson().keys.toSet(), keysOf(sessionExercise));
      expect(
        sampleSet.toJson().keys.toSet(),
        keysOf(items(sessionExercise, 'sets')),
      );
      final last = properties(sessionExercise)['lastPerformance']
          as Map<String, dynamic>;
      expect(
        sampleExercise.lastPerformance!.toJson().keys.toSet(),
        keysOf(last),
      );
      expect(
        sampleExercise.lastPerformance!.sets.first.toJson().keys.toSet(),
        keysOf(items(last, 'sets')),
      );
      expect(
        sampleExercise.prefill.first.toJson().keys.toSet(),
        keysOf(items(sessionExercise, 'prefill')),
      );
      final summary = properties(session)['summary'] as Map<String, dynamic>;
      expect(sampleSummary.toJson().keys.toSet(), keysOf(summary));
      expect(
        sampleSummary.prs.first.toJson().keys.toSet(),
        keysOf(items(summary, 'prs')),
      );
    });

    test('today and today-exercise shapes', () {
      final today = schemaOf('/training/today', 'get');
      final fake = FakeWorkoutApi().todayResponse;
      expect(fake.toJson().keys.toSet(), keysOf(today));
      expect(
        fake.exercises.first.toJson().keys.toSet(),
        keysOf(items(today, 'exercises')),
      );
    });

    test('history list and item shapes', () {
      final list = schemaOf('/training/sessions', 'get');
      const item = SessionListItem(
        id: 'x',
        status: SessionStatus.completed,
        name: 'Legs',
        startedAt: 's',
        completedAt: null,
        durationSeconds: null,
        exerciseCount: 1,
        workingSets: 1,
        tonnageKg: 1,
        prCount: 0,
      );
      expect(
        const SessionListResponse(items: [item], nextBefore: null)
            .toJson()
            .keys
            .toSet(),
        keysOf(list),
      );
      expect(item.toJson().keys.toSet(), keysOf(items(list, 'items')));
    });

    test('request bodies send exactly the accepted properties', () {
      final start = schemaOf('/training/sessions', 'post', request: true);
      final startBody = DioWorkoutApi.startJson(
        const StartSessionRequest(
          clientSessionId: 'c',
          programDayId: 'd',
          startedAt: 's',
          exercises: [
            SeededExercise(
              clientExerciseId: 'e',
              exerciseId: 'x',
              plannedExerciseId: 'p',
              orderIndex: 0,
            ),
          ],
        ),
      );
      expect(startBody.keys.toSet(), keysOf(start));
      expect(
        (startBody['exercises'] as List<Map<String, dynamic>>)
            .first
            .keys
            .toSet(),
        keysOf(items(start, 'exercises')),
      );

      final log =
          schemaOf('/training/sessions/{id}/sets', 'post', request: true);
      expect(keysOf(log), {'sets', 'merge'});
      final setBody = DioWorkoutApi.setJson(
        const LogSetInput(
          clientSetId: 'c',
          clientExerciseId: 'e',
          setIndex: 1,
          setType: SetType.working,
          weightKg: 60,
          reps: 10,
          rir: 2,
          loggedAt: 't',
          plannedSetId: 'p',
        ),
      );
      // The server takes sessionExerciseId OR clientExerciseId; the client always sends the client id.
      expect(keysOf(items(log, 'sets')).containsAll(setBody.keys), isTrue);
      expect(setBody.keys, isNot(contains('sessionExerciseId')));

      final patchSet = schemaOf(
        '/training/sessions/{id}/sets/{setId}',
        'patch',
        request: true,
      );
      final patchBody = DioWorkoutApi.patchSetJson(
        const PatchSetRequest(
          setType: SetType.drop,
          weightKg: 1,
          reps: 1,
          rir: 1,
        ),
      );
      expect(patchBody.keys.toSet(), keysOf(patchSet));
      expect(
        DioWorkoutApi.patchSetJson(
          const PatchSetRequest(weightCleared: true),
        ),
        {'weightKg': null},
      );

      final add =
          schemaOf('/training/sessions/{id}/exercises', 'post', request: true);
      expect(
        withoutNulls(
          const AddSessionExerciseRequest(
            clientExerciseId: 'c',
            exerciseId: 'x',
            plannedExerciseId: 'p',
            orderIndex: 0,
            supersetGroup: 1,
          ).toJson(),
        ).keys.toSet(),
        keysOf(add),
      );
      final patchEx = schemaOf(
        '/training/sessions/{id}/exercises/{exerciseId}',
        'patch',
        request: true,
      );
      expect(
        DioWorkoutApi.patchExerciseJson(
          const PatchSessionExerciseRequest(
            orderIndex: 0,
            supersetGroup: 1,
            exerciseId: 'x',
            removed: true,
          ),
        ).keys.toSet(),
        keysOf(patchEx),
      );
      final complete =
          schemaOf('/training/sessions/{id}/complete', 'post', request: true);
      expect(
        withoutNulls(
          const CompleteSessionRequest(completedAt: 't', notes: 'n').toJson(),
        ).keys.toSet(),
        keysOf(complete),
      );
    });

    test('a session round-trips through JSON', () {
      expect(
        WorkoutSession.fromJson(
          jsonDecode(jsonEncode(sampleSession.toJson()))
              as Map<String, dynamic>,
        ),
        sampleSession,
      );
    });
  });

  group('progression, volume and deload (Phase 6)', () {
    Map<String, dynamic> items(Map<String, dynamic> schema, String key) =>
        (properties(schema)[key] as Map<String, dynamic>)['items']
            as Map<String, dynamic>;
    Map<String, dynamic> nested(Map<String, dynamic> schema, String key) =>
        properties(schema)[key] as Map<String, dynamic>;

    const recommendation = ProgressionRecommendation(
      action: ProgressionAction.increaseLoad,
      weightKg: 65,
      repTarget: '6',
      targetRir: 1,
      reason: 'Every working set hit 12 reps at 1 RIR or better at 60 kg.',
      basis: 'calculated',
      sessionsConsidered: 1,
    );
    const priorBest = PriorBest(
      weightKg: 60,
      repsAtBestWeight: 12,
      estimated1rm: 84,
    );
    const substitution = Substitution(
      trigger: SubstitutionTrigger.equipment,
      alternative: SubstitutionAlternative(
        exerciseId: '33333333-3333-4333-8333-333333333333',
        slug: 'dumbbell-goblet-squat',
        name: 'Dumbbell Goblet Squat',
        equipment: [Equipment.dumbbell],
      ),
      reason: 'Needs a barbell, which is no longer in your kit.',
    );
    const deload = DeloadState(
      state: DeloadStatus.offered,
      trigger: DeloadTrigger.fatigue,
      reason: 'Fatigue on two lead lifts in the last seven days.',
      endsOn: null,
    );

    test('enums match the server', () {
      final session = schemaOf('/training/sessions', 'post');
      final exercise = items(session, 'exercises');
      final rec = nested(exercise, 'recommendation');
      expect(
        ProgressionAction.values.map((a) => a.wire).toList(),
        enumOf(nested(rec, 'action')),
      );
      expect(
        enumOf(nested(items(exercise, 'prefill'), 'weightSource')),
        contains('recommendation'),
      );
      final today = schemaOf('/training/today', 'get');
      final sub = nested(items(today, 'exercises'), 'substitution');
      expect(
        SubstitutionTrigger.values.map((t) => t.wire).toList(),
        enumOf(nested(sub, 'trigger')),
      );
      final dl = nested(today, 'deload');
      expect(
        DeloadStatus.values.map((t) => t.wire).toList(),
        enumOf(nested(dl, 'state')),
      );
      expect(
        DeloadTrigger.values.map((t) => t.wire).toList(),
        enumOf(nested(dl, 'trigger')),
      );
      final volume = schemaOf('/training/volume', 'get');
      final week = items(items(volume, 'weeks'), 'muscles');
      expect(
        LandmarkStatus.values.map((t) => t.wire).toList(),
        enumOf(nested(week, 'status')),
      );
    });

    test('recommendation, prior best, substitution and deload shapes', () {
      final session = schemaOf('/training/sessions', 'post');
      final exercise = items(session, 'exercises');
      expect(
        recommendation.toJson().keys.toSet(),
        keysOf(nested(exercise, 'recommendation')),
      );
      expect(
        priorBest.toJson().keys.toSet(),
        keysOf(nested(exercise, 'priorBest')),
      );
      final today = schemaOf('/training/today', 'get');
      final todayExercise = items(today, 'exercises');
      expect(
        substitution.toJson().keys.toSet(),
        keysOf(nested(todayExercise, 'substitution')),
      );
      expect(
        substitution.alternative!.toJson().keys.toSet(),
        keysOf(nested(nested(todayExercise, 'substitution'), 'alternative')),
      );
      expect(deload.toJson().keys.toSet(), keysOf(nested(today, 'deload')));
      expect(
        const NeglectedMuscle(muscle: MuscleGroup.calves, daysSince: 9)
            .toJson()
            .keys
            .toSet(),
        keysOf(items(today, 'neglected')),
      );
    });

    test('volume and progression-detail shapes', () {
      final volume = schemaOf('/training/volume', 'get');
      const muscleWeek = MuscleWeek(
        muscle: MuscleGroup.chest,
        hardSets: 12,
        tonnageKg: 4800,
        status: LandmarkStatus.mevToMav,
        landmarks:
            VolumeLandmarks(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 22),
        owned: true,
      );
      const response = VolumeResponse(
        weeks: [
          VolumeWeek(isoWeek: '2026-W39', muscles: [muscleWeek]),
        ],
        owned: [MuscleGroup.chest],
        neglected: [],
        mesocycleWeek: 2,
        deload: deload,
      );
      expect(response.toJson().keys.toSet(), keysOf(volume));
      final week = items(volume, 'weeks');
      expect(response.weeks.first.toJson().keys.toSet(), keysOf(week));
      expect(
        muscleWeek.toJson().keys.toSet(),
        keysOf(items(week, 'muscles')),
      );
      expect(
        muscleWeek.landmarks.toJson().keys.toSet(),
        keysOf(nested(items(week, 'muscles'), 'landmarks')),
      );

      final detailSchema =
          schemaOf('/training/progression/{exerciseId}', 'get');
      const detail = ProgressionDetail(
        exerciseId: '11111111-1111-4111-8111-111111111111',
        name: 'Barbell Back Squat',
        target: ProgressionTarget(
          repMin: 6,
          repMax: 12,
          targetRir: 1,
          sets: 3,
          incrementKg: 5,
        ),
        recommendation: recommendation,
        history: [
          ProgressionHistoryEntry(
            sessionId: '00000000-0000-4000-8000-000000000006',
            date: '2026-09-18',
            sets: [
              ProgressionHistorySet(
                setIndex: 1,
                weightKg: 60,
                reps: 12,
                rir: 1,
              ),
            ],
          ),
        ],
      );
      expect(detail.toJson().keys.toSet(), keysOf(detailSchema));
      expect(
        detail.target!.toJson().keys.toSet(),
        keysOf(nested(detailSchema, 'target')),
      );
      final history = items(detailSchema, 'history');
      expect(detail.history.first.toJson().keys.toSet(), keysOf(history));
      expect(
        detail.history.first.sets.first.toJson().keys.toSet(),
        keysOf(items(history, 'sets')),
      );
      // Deload accept/decline answer the deload state.
      expect(
        deload.toJson().keys.toSet(),
        keysOf(schemaOf('/training/deload/accept', 'post')),
      );
      expect(
        deload.toJson().keys.toSet(),
        keysOf(schemaOf('/training/deload/decline', 'post')),
      );
    });

    test('a Phase 5 cached "today" without the Phase 6 fields still parses',
        () {
      // Offline path: JSON cached before this build lacks the new keys.
      final fake = FakeWorkoutApi().todayResponse;
      // Through the wire first: freezed's toJson leaves nested objects.
      final old =
          (jsonDecode(jsonEncode(fake.toJson())) as Map<String, dynamic>)
            ..remove('mesocycleWeek')
            ..remove('deload')
            ..remove('neglected');
      for (final x in old['exercises'] as List<dynamic>) {
        (x as Map<String, dynamic>)
          ..remove('recommendation')
          ..remove('priorBest')
          ..remove('originalTargets')
          ..remove('substitution');
      }
      final parsed = TodayResponse.fromJson(
        jsonDecode(jsonEncode(old)) as Map<String, dynamic>,
      );
      expect(parsed.deload, DeloadState.none);
      expect(parsed.neglected, isEmpty);
      expect(parsed.exercises.first.recommendation, isNull);
      expect(parsed.exercises.first.priorBest, PriorBest.none);
    });

    test('Phase 6 DTOs round-trip through JSON', () {
      Object? wire(Object? v) => jsonDecode(jsonEncode(v));
      expect(
        ProgressionRecommendation.fromJson(
          wire(recommendation.toJson()) as Map<String, dynamic>,
        ),
        recommendation,
      );
      expect(
        Substitution.fromJson(
          wire(substitution.toJson()) as Map<String, dynamic>,
        ),
        substitution,
      );
      expect(
        DeloadState.fromJson(wire(deload.toJson()) as Map<String, dynamic>),
        deload,
      );
    });
  });

  test('every DTO round-trips through its own JSON', () {
    // `fromJson(toJson())` — the generated parsers accept what they emit,
    // which is the same shape the server sends (checked above).
    Object? wire(Object? v) => jsonDecode(jsonEncode(v));
    expect(
      UserProfile.fromJson(wire(testProfile.toJson()) as Map<String, dynamic>),
      testProfile,
    );
    expect(
      OnboardingState.fromJson(
        wire(midwayState.toJson()) as Map<String, dynamic>,
      ),
      midwayState,
    );
    expect(
      NutritionTargets.fromJson(
        wire(personaCTargets.toJson()) as Map<String, dynamic>,
      ),
      personaCTargets,
    );
    expect(
      GoalResponse.fromJson(
        wire(GoalResponse(goal: personaCGoal, targets: null).toJson())
            as Map<String, dynamic>,
      ),
      GoalResponse(goal: personaCGoal, targets: null),
    );
  });
}
