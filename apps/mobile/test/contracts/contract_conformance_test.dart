import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/ai/data/ai_api.dart';
import 'package:fitos/features/ai/domain/entities/ai.dart';
import 'package:fitos/features/auth/domain/entities/user_profile.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/mess/domain/mess.dart';
import 'package:fitos/features/mess/domain/recommendation.dart';
import 'package:fitos/features/mess/presentation/widgets/recommend_words.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/data/profile_repository.dart'
    show PersonalDetailsChange;
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/progress/domain/progress.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/today/presentation/today_words.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/workout/data/workout_api.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_exercise_repository.dart';
import '../support/fake_food_repository.dart';
import '../support/fake_mess_api.dart';
import '../support/fake_training_repository.dart';
import '../support/fake_onboarding_repository.dart';
import '../support/fake_today_api.dart';
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
        emphasis: [MuscleGroup.chest],
      );
      expect(withoutNulls(full.toJson()).keys.toSet(), keysOf(variant));
      expect(
        enumOf(
          (properties(variant)['emphasis'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>,
        ),
        MuscleGroup.values.map((m) => m.wire).toList(),
      );
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

    test(
        'Phase 6.6 Gate 7: one weekday convention — ISO 1..7 in the API and in Dart; the start names its day by id, and the ad-hoc resend omits it',
        () {
      // The API's dayOfWeek (programme days, /today?dayOfWeek) is ISO 1..7.
      final days = schemaOf('/training/program', 'get');
      final day = (properties(days)['days'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      final dow = properties(day)['dayOfWeek'] as Map<String, dynamic>;
      expect(dow['minimum'], 1);
      expect(dow['maximum'], 7);
      // Dart's DateTime.weekday is the same ISO numbering: the S24's week.
      expect(
        [for (var d = 21; d <= 27; d++) DateTime(2026, 9, d).weekday],
        [1, 2, 3, 4, 5, 6, 7],
      );
      expect(DateTime(2026, 9, 23).weekday, 3, reason: 'Wednesday');
      // The start body identifies the day by id — no weekday at all.
      final start = schemaOf('/training/sessions', 'post', request: true);
      expect(keysOf(start), isNot(contains('dayOfWeek')));
      expect(keysOf(start), contains('programDayId'));
      expect(
        DioWorkoutApi.startJson(
          const StartSessionRequest(clientSessionId: 'c', startedAt: 's'),
        ).keys,
        isNot(contains('programDayId')),
        reason: 'the ad-hoc resend must omit it, not send null',
      );
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

  test(
      'Personal details (Phase 6.6 Gate 7): the editor sends only keys PATCH /user/profile accepts, in its enum values',
      () {
    final patch = schemaOf('/user/profile', 'patch', request: true);
    const everything = PersonalDetailsChange(
      displayName: 'A',
      sex: Sex.male,
      heightCm: 170,
      weightKg: 70,
      activityLevel: ActivityLevel.moderate,
    );
    expect(keysOf(patch), containsAll(everything.toJson().keys));
    expect(
      Sex.values.map((v) => v.wire).toList(),
      enumOf(properties(patch)['sex'] as Map<String, dynamic>),
    );
    expect(
      ActivityLevel.values.map((v) => v.wire).toList(),
      enumOf(properties(patch)['activityLevel'] as Map<String, dynamic>),
    );
    // Targets are the server's: no target field is writable through PATCH.
    for (final k in [
      'kcal',
      'proteinG',
      'carbG',
      'fatG',
      'fiberG',
      'targets',
    ]) {
      expect(keysOf(patch), isNot(contains(k)));
    }
  });

  group('FITOS AI (Phase 6.6)', () {
    Map<String, dynamic> items(Map<String, dynamic> schema, String key) =>
        (properties(schema)[key] as Map<String, dynamic>)['items']
            as Map<String, dynamic>;

    test('status, chat request and chat response shapes; action and role enums',
        () {
      final status = schemaOf('/ai/status', 'get');
      expect(
        const AiStatus(
          configured: true,
          provider: 'gemini',
          model: 'm',
          excludes: ['health-connect'],
        ).toJson().keys.toSet(),
        keysOf(status),
      );
      final request = schemaOf('/ai/chat', 'post', request: true);
      final body = DioAiApi.chatJson(
        const AiChatRequest(
          message: 'hi',
          history: [AiChatMessage(role: AiRole.assistant, content: 'x')],
        ),
      );
      expect(body.keys.toSet(), keysOf(request));
      expect(
        (body['history'] as List<Map<String, dynamic>>).first.keys.toSet(),
        keysOf(items(request, 'history')),
      );
      expect(
        AiRole.values.map((r) => r.wire).toList(),
        enumOf(
          properties(items(request, 'history'))['role'] as Map<String, dynamic>,
        ),
      );
      final response = schemaOf('/ai/chat', 'post');
      const answer = AiChatResponse(
        text: 't',
        actions: [AiAction(type: AiActionType.openWorkout, label: 'l')],
        toolsUsed: ['get_today'],
        model: 'm',
      );
      expect(answer.toJson().keys.toSet(), keysOf(response));
      expect(
        answer.actions.first.toJson().keys.toSet(),
        keysOf(items(response, 'actions')),
      );
      expect(
        AiActionType.values.map((a) => a.wire).toList(),
        enumOf(
          properties(items(response, 'actions'))['type']
              as Map<String, dynamic>,
        ),
      );
      // Gate 5: the apply-program action carries the structured request,
      // whose shape is exactly the server's (no exercises, no sets).
      final actionProps = properties(items(response, 'actions'));
      const proposed = AiProgramRequest(
        daysPerWeek: 5,
        preferredSessionMinutes: 60,
        template: 'bodybuilding-5',
        emphasis: [MuscleGroup.chest],
      );
      expect(
        withoutNulls(proposed.toJson()).keys.toSet(),
        keysOf(actionProps['programRequest'] as Map<String, dynamic>),
      );
      expect(
        AiAction.fromJson(
          jsonDecode(
            jsonEncode(
              const AiAction(
                type: AiActionType.applyProgram,
                label: 'l',
                programRequest: proposed,
              ).toJson(),
            ),
          ) as Map<String, dynamic>,
        ).programRequest,
        proposed,
      );
      // Excludes name what the server never sees.
      expect(
        enumOf(properties(status)['excludes'] as Map<String, dynamic>),
        ['health-connect', 'food-log'],
      );
    });
  });

  group('food library (Phase 7)', () {
    late Map<String, dynamic> search;
    late Map<String, dynamic> item;
    late Map<String, dynamic> nutrition;
    late Map<String, dynamic> created;
    late Map<String, dynamic> request;

    setUpAll(() {
      final paths = doc['paths'] as Map<String, dynamic>;
      final op = (paths['/nutrition/foods/search']
          as Map<String, dynamic>)['get'] as Map<String, dynamic>;
      final params = (op['parameters'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((p) => p['name'])
          .toSet();
      expect(params, {'q', 'limit'});
      search = schemaOf('/nutrition/foods/search', 'get');
      item = properties(search)['items']['items'] as Map<String, dynamic>;
      nutrition =
          properties(item)['nutrition']['items'] as Map<String, dynamic>;
      created = schemaOf('/nutrition/foods', 'post');
      request = schemaOf('/nutrition/foods', 'post', request: true);
    });

    test('FoodSource, NutritionBasis, NutritionConfidence, FoodMatchKind', () {
      expect(
        FoodSource.values.map((v) => v.wire).toList(),
        enumOf(properties(item)['source'] as Map<String, dynamic>),
      );
      expect(
        NutritionBasis.values.map((v) => v.wire).toList(),
        enumOf(properties(nutrition)['basis'] as Map<String, dynamic>),
      );
      expect(
        NutritionConfidence.values.map((v) => v.wire).toList(),
        enumOf(properties(nutrition)['confidence'] as Map<String, dynamic>),
      );
      expect(
        FoodMatchKind.values.map((v) => v.wire).toList(),
        enumOf(properties(item)['match'] as Map<String, dynamic>),
      );
      expect(
        NutritionBasis.values.map((v) => v.wire).toList(),
        enumOf(properties(request)['basis'] as Map<String, dynamic>),
      );
    });

    test('Food, FoodNutrition, FoodSearchResult, FoodSearchResponse', () {
      expect(keysOf(search), {'items'});
      expect(
        const FoodSearchResponse(items: []).toJson().keys.toSet(),
        keysOf(search),
      );
      const hit = FoodSearchResult(food: honey, match: FoodMatchKind.exact);
      expect(hit.toJson().keys.toSet(), keysOf(item));
      expect(honey.toJson().keys.toSet(), keysOf(created));
      expect(honey.nutrition.first.toJson().keys.toSet(), keysOf(nutrition));
      // A created food is the same shape as a search hit, minus `match`.
      expect(keysOf(item).difference(keysOf(created)), {'match'});
    });

    test('CreateFoodRequest sends exactly the accepted properties', () {
      const full = CreateFoodRequest(
        clientFoodId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        name: 'Protein bar',
        brand: 'Brand',
        basis: NutritionBasis.perServing,
        servingLabel: '1 bar',
        servingGrams: 60,
        kcal: 220,
        proteinG: 20,
        carbG: 22,
        fatG: 7,
        fibreG: 3,
      );
      expect(full.toJson().keys.toSet(), keysOf(request));
      expect(request['additionalProperties'], isFalse);
      // A per-100 g label omits the serving label (the contract has it
      // optional, not nullable) and still sends only accepted keys.
      const per100 = CreateFoodRequest(
        clientFoodId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        name: 'Oats',
        brand: null,
        basis: NutritionBasis.per100g,
        servingLabel: null,
        servingGrams: null,
        kcal: 389,
        proteinG: 13.2,
        carbG: 67.7,
        fatG: 7.6,
        fibreG: null,
      );
      expect(per100.toJson().containsKey('servingLabel'), isFalse);
      expect(keysOf(request).containsAll(per100.toJson().keys), isTrue);
      final required = (request['required'] as List<dynamic>).cast<String>();
      expect(per100.toJson().keys.toSet().containsAll(required), isTrue);
    });

    test('Food and search results round-trip through JSON', () {
      Object? wire(Object? v) => jsonDecode(jsonEncode(v));
      for (final food in [honey, dalTadka, lassi]) {
        expect(
          Food.fromJson(wire(food.toJson()) as Map<String, dynamic>),
          food,
        );
      }
      final hit = FoodSearchResult.fromJson(
        wire(
          const FoodSearchResult(food: dalTadka, match: FoodMatchKind.alias)
              .toJson(),
        ) as Map<String, dynamic>,
      );
      expect(hit.food, dalTadka);
      expect(hit.match, FoodMatchKind.alias);
    });
  });

  group('food logging (Phase 8)', () {
    late Map<String, dynamic> day;
    late Map<String, dynamic> totals;
    late Map<String, dynamic> log;
    late Map<String, dynamic> item;
    late Map<String, dynamic> remaining;
    late Map<String, dynamic> range;
    late List<Map<String, dynamic>> createVariants;
    late Map<String, dynamic> recent;
    late Map<String, dynamic> savedMeal;
    late List<Map<String, dynamic>> savedItemVariants;

    Map<String, dynamic> p(Map<String, dynamic> s, String k) =>
        properties(s)[k] as Map<String, dynamic>;

    setUpAll(() {
      day = schemaOf('/nutrition/today', 'get');
      totals = p(day, 'totals');
      log = p(day, 'logs')['items'] as Map<String, dynamic>;
      item = p(log, 'items')['items'] as Map<String, dynamic>;
      remaining = p(day, 'remaining');
      range = p(remaining, 'kcal');
      createVariants =
          (schemaOf('/nutrition/logs', 'post', request: true)['anyOf']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      recent = p(schemaOf('/nutrition/foods/recent', 'get'), 'items')['items']
          as Map<String, dynamic>;
      savedMeal = p(schemaOf('/nutrition/saved-meals', 'get'), 'items')['items']
          as Map<String, dynamic>;
      savedItemVariants = ((p(savedMeal, 'items')['items']
              as Map<String, dynamic>)['anyOf'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    });

    const item0 = FoodLogItem(
      id: 'i',
      position: 0,
      foodId: null,
      foodName: 'Quick add',
      foodSource: FoodSource.user,
      basis: null,
      servingLabel: null,
      servingGrams: null,
      servings: 1,
      grams: null,
      kcalLow: 250,
      kcalHigh: 250,
      proteinLow: 10,
      proteinHigh: 10,
      carbLow: 30,
      carbHigh: 30,
      fatLow: 9,
      fatHigh: 9,
      fibreLow: null,
      fibreHigh: null,
      confidence: NutritionConfidence.medium,
    );
    const totals0 = NutritionTotals(
      kcalLow: 250,
      kcalHigh: 250,
      proteinLow: 10,
      proteinHigh: 10,
      carbLow: 30,
      carbHigh: 30,
      fatLow: 9,
      fatHigh: 9,
      fibreKnownLow: 0,
      fibreKnownHigh: 0,
      fibreUnknownItems: 1,
      itemCount: 1,
    );
    const log0 = FoodLog(
      id: 'l',
      clientLogId: 'c',
      loggedAt: '2026-09-24T07:30:00.000Z',
      localDate: '2026-09-24',
      mealSlot: MealSlot.lunch,
      entryMethod: EntryMethod.quickAdd,
      savedMealId: null,
      items: [item0],
      totals: totals0,
    );
    const range0 = RemainingRange(
      target: 2400,
      low: 2150,
      high: 2150,
      state: RemainingState.under,
    );
    const day0 = NutritionDay(
      date: '2026-09-24',
      today: '2026-09-24',
      timezone: 'Asia/Kolkata',
      targets: null,
      totals: totals0,
      remaining: NutritionRemaining(
        kcal: range0,
        protein: range0,
        carb: range0,
        fat: range0,
      ),
      logs: [log0],
    );

    test('MealSlot, EntryMethod, RemainingState', () {
      expect(
        MealSlot.values.map((v) => v.wire).toList(),
        enumOf(p(log, 'mealSlot')),
      );
      expect(
        EntryMethod.values.map((v) => v.wire).toList(),
        enumOf(p(log, 'entryMethod')),
      );
      expect(
        RemainingState.values.map((v) => v.wire).toList(),
        enumOf(p(range, 'state')),
      );
    });

    test('NutritionDay, NutritionTotals, FoodLog, FoodLogItem, remaining', () {
      expect(day0.toJson().keys.toSet(), keysOf(day));
      expect(keysOf(schemaOf('/nutrition/day/{date}', 'get')), keysOf(day));
      expect(totals0.toJson().keys.toSet(), keysOf(totals));
      expect(log0.toJson().keys.toSet(), keysOf(log));
      expect(item0.toJson().keys.toSet(), keysOf(item));
      expect(day0.remaining!.toJson().keys.toSet(), keysOf(remaining));
      expect(range0.toJson().keys.toSet(), keysOf(range));
    });

    test('CreateLogResponse, DeleteLogResponse, RecentFood, SavedMeal', () {
      expect(
        const CreateLogResponse(log: log0, day: day0).toJson().keys.toSet(),
        keysOf(schemaOf('/nutrition/logs', 'post')),
      );
      expect(
        const DeleteLogResponse(day: day0).toJson().keys.toSet(),
        keysOf(schemaOf('/nutrition/logs/{clientLogId}', 'delete')),
      );
      expect(
        const RecentFood(
          food: honey,
          lastLoggedAt: '2026-09-24T07:30:00.000Z',
          lastBasis: NutritionBasis.perServing,
          lastServingLabel: '1 tbsp',
          lastServings: 2,
        ).toJson().keys.toSet(),
        keysOf(recent),
      );
      final meal = SavedMeal(
        id: 'm',
        clientMealId: 'c',
        name: 'Dinner',
        createdAt: '2026-09-24T07:30:00.000Z',
        items: [
          SavedFoodItem(
            foodId: 'f',
            foodName: 'Dal',
            basis: NutritionBasis.perServing,
            servingLabel: '1 katori',
            servings: 1,
            grams: 150,
            row: honey.nutrition.first,
          ),
          const SavedQuickAddItem(
            quickAddName: 'Curd',
            kcal: 60,
            proteinG: 3,
            carbG: 4,
            fatG: 3,
            fibreG: null,
          ),
        ],
      );
      expect(meal.toJson().keys.toSet(), keysOf(savedMeal));
      expect(
        keysOf(schemaOf('/nutrition/saved-meals', 'post')),
        keysOf(savedMeal),
      );
      expect(meal.items[0].toJson().keys.toSet(), keysOf(savedItemVariants[0]));
      expect(meal.items[1].toJson().keys.toSet(), keysOf(savedItemVariants[1]));
      // The hand-written union parses what it sends.
      Object? wire(Object? v) => jsonDecode(jsonEncode(v));
      final back =
          SavedMeal.fromJson(wire(meal.toJson()) as Map<String, dynamic>);
      expect(back.items[0], isA<SavedFoodItem>());
      expect(back.items[1], isA<SavedQuickAddItem>());
      expect(
        NutritionDay.fromJson(wire(day0.toJson()) as Map<String, dynamic>),
        day0,
      );
    });

    test('each CreateLogRequest variant sends exactly its accepted properties',
        () {
      final search = const CreateLogRequest.search(
        clientLogId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        loggedAt: '2026-09-24T07:30:00.000Z',
        mealSlot: MealSlot.lunch,
        items: [
          LogFoodItemRequest(
            foodId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
            basis: NutritionBasis.perServing,
            servingLabel: '1 katori',
            servings: 1.5,
          ),
        ],
      ).toJson();
      final quick = const CreateLogRequest.quickAdd(
        clientLogId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        loggedAt: '2026-09-24T07:30:00.000Z',
        mealSlot: MealSlot.snacks,
        quickAdd: QuickAdd(
          name: 'Samosa',
          kcal: 260,
          proteinG: 4,
          carbG: 28,
          fatG: 15,
          fibreG: 2,
        ),
      ).toJson();
      final saved = const CreateLogRequest.savedMeal(
        clientLogId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        loggedAt: '2026-09-24T07:30:00.000Z',
        mealSlot: MealSlot.dinner,
        savedMealId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
      ).toJson();
      Map<String, dynamic> variant(String method) => createVariants.firstWhere(
            (v) => enumOf(p(v, 'entryMethod')).single == method,
          );
      expect(search.keys.toSet(), keysOf(variant('search')));
      expect(quick.keys.toSet(), keysOf(variant('quick-add')));
      expect(saved.keys.toSet(), keysOf(variant('saved-meal')));
      final itemSchema =
          p(variant('search'), 'items')['items'] as Map<String, dynamic>;
      final itemJson =
          (search['items'] as List<dynamic>).first as Map<String, dynamic>;
      expect(keysOf(itemSchema).containsAll(itemJson.keys), isTrue);
      expect(
        (quick['quickAdd'] as Map<String, dynamic>).keys.toSet(),
        keysOf(p(variant('quick-add'), 'quickAdd')),
      );
      expect(
        const CreateSavedMealRequest(
          clientMealId: 'c',
          name: 'n',
          fromClientLogIds: ['a'],
        ).toJson().keys.toSet(),
        keysOf(schemaOf('/nutrition/saved-meals', 'post', request: true)),
      );
    });
  });

  group('VIT mess (Phase 9)', () {
    Map<String, dynamic> p(Map<String, dynamic> s, String k) =>
        properties(s)[k] as Map<String, dynamic>;

    late Map<String, dynamic> messes;
    late Map<String, dynamic> menu;

    setUpAll(() {
      messes = schemaOf('/mess/providers/{slug}/messes', 'get');
      menu = schemaOf('/mess/menu', 'get');
    });

    final menu0 = FakeMessApi.defaultMenu(
      'mens-veg',
      '2026-09-24',
      logged: const [
        MessLoggedDish(
          dishSlug: 'phulka',
          mealSlot: MealSlot.lunch,
          clientLogId: 'c',
        ),
      ],
    );

    test('DietClass matches the server; unknown is a member', () {
      final dish = p(
        p(menu, 'meals')['items'] as Map<String, dynamic>,
        'dishes',
      )['items'] as Map<String, dynamic>;
      expect(
        DietClass.values.map((d) => d.wire).toList(),
        enumOf(p(dish, 'diet')),
      );
      final fresh = p(
        p(messes, 'items')['items'] as Map<String, dynamic>,
        'freshness',
      );
      expect(
        MirrorError.values.map((e) => e.wire).toSet(),
        enumOf(p(fresh, 'lastError')).toSet(),
      );
    });

    test('providers, messes, freshness', () {
      final response = MessesResponse(
        provider: const MessProviderInfo(
          slug: 'vit-vellore',
          displayName: 'VIT Vellore',
          status: 'active',
        ),
        items: [FakeMessApi.messOf('mens-veg')],
      );
      expect(response.toJson().keys.toSet(), keysOf(messes));
      expect(
        response.provider.toJson().keys.toSet(),
        keysOf(p(messes, 'provider')),
      );
      final item = p(messes, 'items')['items'] as Map<String, dynamic>;
      expect(response.items.first.toJson().keys.toSet(), keysOf(item));
      expect(
        response.items.first.freshness.toJson().keys.toSet(),
        keysOf(p(item, 'freshness')),
      );
      expect(
        keysOf(
          p(schemaOf('/mess/providers', 'get'), 'items')['items']
              as Map<String, dynamic>,
        ),
        response.provider.toJson().keys.toSet(),
      );
    });

    test('menu, resolution variants, meal, dish, estimate, logged', () {
      expect(menu0.toJson().keys.toSet(), keysOf(menu));
      final variants = (p(menu, 'resolution')['anyOf'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic> variant(String kind) =>
          variants.firstWhere((v) => enumOf(p(v, 'kind')).single == kind);
      expect(
        const ExactMenu('2026-09-24').toJson().keys.toSet(),
        keysOf(variant('exact')),
      );
      expect(
        const InferredMenu(
          '2026-10-02',
          sourceDate: '2026-09-18',
          cycleLengthDays: 14,
        ).toJson().keys.toSet(),
        keysOf(variant('cycle-inferred')),
      );
      expect(
        const UnavailableMenu('2026-10-02', latestAvailable: null)
            .toJson()
            .keys
            .toSet(),
        keysOf(variant('unavailable')),
      );
      final meal = p(menu, 'meals')['items'] as Map<String, dynamic>;
      expect(menu0.meals.first.toJson().keys.toSet(), keysOf(meal));
      final dish = p(meal, 'dishes')['items'] as Map<String, dynamic>;
      final withEstimate = menu0
          .meal(MealSlot.lunch)!
          .dishes
          .firstWhere((d) => d.nutrition != null);
      expect(withEstimate.toJson().keys.toSet(), keysOf(dish));
      expect(
        (withEstimate.toJson()['nutrition'] as Map<String, dynamic>)
            .keys
            .toSet(),
        keysOf(p(dish, 'nutrition')),
      );
      expect(
        menu0.logged.first.toJson().keys.toSet(),
        keysOf(p(menu, 'logged')['items'] as Map<String, dynamic>),
      );
      // The hand-written parsers read what the server sends.
      Object? wire(Object? v) => jsonDecode(jsonEncode(v));
      final back =
          MessMenu.fromJson(wire(menu0.toJson()) as Map<String, dynamic>);
      expect(back.toJson(), wire(menu0.toJson()));
    });

    test('corrections: each field sends only accepted properties; the answer',
        () {
      final accepted = keysOf(
        schemaOf('/mess/dishes/{slug}/correction', 'post', request: true),
      );
      for (final r in [
        const MessCorrectionRequest(
          clientCorrectionId: 'c',
          field: CorrectionField.kcal,
          low: 1,
          high: 2,
          note: 'n',
        ),
        const MessCorrectionRequest(
          clientCorrectionId: 'c',
          field: CorrectionField.diet,
          diet: DietClass.egg,
        ),
        const MessCorrectionRequest(
          clientCorrectionId: 'c',
          field: CorrectionField.other,
          note: 'n',
        ),
      ]) {
        expect(accepted.containsAll(r.toJson().keys), isTrue);
      }
      expect(
        CorrectionField.values.map((f) => f.wire).toList(),
        enumOf(
          p(
            schemaOf('/mess/dishes/{slug}/correction', 'post', request: true),
            'field',
          ),
        ),
      );
      const answer = MessCorrection(
        id: 'i',
        clientCorrectionId: 'c',
        dishSlug: 'phulka',
        field: CorrectionField.kcal,
        low: 1,
        high: 2,
        diet: null,
        note: null,
        status: 'pending',
        createdAt: '2026-09-24T07:30:00.000Z',
      );
      expect(
        answer.toJson().keys.toSet(),
        keysOf(schemaOf('/mess/dishes/{slug}/correction', 'post')),
      );
    });

    test('a mess log sends the mess, the date and dishes — and no numbers', () {
      final request = const CreateLogRequest.mess(
        clientLogId: '0b1f6a8e-4d2c-4b8e-9d5f-1a2b3c4d5e6f',
        loggedAt: '2026-09-24T07:30:00.000Z',
        mealSlot: MealSlot.lunch,
        mess: 'mens-veg',
        menuDate: '2026-09-24',
        messItems: [LogMessDishRequest(dishSlug: 'phulka', servings: 1.5)],
      ).toJson();
      final variants =
          (schemaOf('/nutrition/logs', 'post', request: true)['anyOf']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final mess = variants
          .firstWhere((v) => enumOf(p(v, 'entryMethod')).single == 'mess');
      expect(request.keys.toSet(), keysOf(mess));
      final itemSchema = p(mess, 'items')['items'] as Map<String, dynamic>;
      final item =
          (request['items'] as List<dynamic>).first as Map<String, dynamic>;
      expect(keysOf(itemSchema).containsAll(item.keys), isTrue);
      expect(item.keys.any((k) => k.startsWith('kcal')), isFalse);
      // It survives the queue: parsed back exactly.
      expect(
        CreateLogRequest.fromJson(
          jsonDecode(jsonEncode(request)) as Map<String, dynamic>,
        ).toJson(),
        request,
      );
    });

    test('a saved mess item is its own kind (owner D11) and round-trips', () {
      final savedMeal =
          p(schemaOf('/nutrition/saved-meals', 'get'), 'items')['items']
              as Map<String, dynamic>;
      final variants = ((p(savedMeal, 'items')['items']
              as Map<String, dynamic>)['anyOf'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final mess =
          variants.firstWhere((v) => enumOf(p(v, 'kind')).single == 'mess');
      const item = SavedMessItem(
        dishSlug: 'dhal-makhani',
        dishName: 'Dhal Makhani',
        servings: 2,
        row: FakeMessApi.dal,
      );
      expect(item.toJson().keys.toSet(), keysOf(mess));
      expect(
        (item.toJson()['row'] as Map<String, dynamic>).keys.toSet(),
        keysOf(p(mess, 'row')),
      );
      final back = SavedMealItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(back, isA<SavedMessItem>());
      expect((back as SavedMessItem).row, FakeMessApi.dal);
    });

    test('the profile carries isVitStudent; PATCH accepts the mess', () {
      final patch = keysOf(schemaOf('/user/profile', 'patch', request: true));
      expect(patch.containsAll(['isVitStudent', 'mess']), isTrue);
    });
  });

  group('mess recommendations (Phase 10)', () {
    Map<String, dynamic> p(Map<String, dynamic> s, String k) =>
        properties(s)[k] as Map<String, dynamic>;
    Map<String, dynamic> items(Map<String, dynamic> s, String k) =>
        p(s, k)['items'] as Map<String, dynamic>;

    late Map<String, dynamic> rec;
    setUpAll(() => rec = schemaOf('/mess/menu/recommend', 'get'));

    final full = FakeMessApi.defaultRecommendation(
      'mens-veg',
      '2026-09-24',
      allergies: const [Allergen.peanut],
      proteinShortfall: const Gap(
        target: 85,
        gapLow: 45.3,
        gapHigh: 60,
        menuMax: 46,
        menuCanMeet: false,
      ),
      kcalShortfall: const Gap(
        target: 900,
        gapLow: 100,
        gapHigh: 200,
        menuMax: 1000,
        menuCanMeet: true,
      ),
    );

    test('status, basis and reason-code vocabularies match the server', () {
      expect(
        RecommendationStatus.values.map((s) => s.wire).toList(),
        enumOf(p(rec, 'status')),
      );
      expect(enumOf(p(rec, 'basis')), ['published', 'inferred']);
      final reason = items(items(rec, 'plates'), 'reasons');
      final codes = enumOf(p(reason, 'code'));
      // Every code the server can send has words — never the raw code.
      for (final code in codes) {
        final r = Reason(code, const {'dishSlug': 'dal'});
        final words = {
          ReasonText.plate(r, const {'dal': 'Dal'}),
          ReasonText.dish(r, DietType.vegetarian),
        };
        expect(words.any((w) => w != code), isTrue, reason: code);
      }
      expect(
        Allergen.values.map((a) => a.wire).toSet(),
        enumOf(p(reason, 'allergen')).toSet(),
      );
    });

    test('response, plate, item, totals, target, gap, dish, alternative', () {
      expect(full.toJson().keys.toSet(), keysOf(rec));
      expect(
        (full.toJson()['filters'] as Map<String, dynamic>).keys.toSet(),
        keysOf(p(rec, 'filters')),
      );
      expect(full.target!.toJson().keys.toSet(), keysOf(p(rec, 'target')));
      final plate = items(rec, 'plates');
      expect(full.plates.first.toJson().keys.toSet(), keysOf(plate));
      expect(
        full.plates.first.items.first.toJson().keys.toSet(),
        keysOf(items(plate, 'items')),
      );
      expect(
        full.plates.first.totals.toJson().keys.toSet(),
        keysOf(p(plate, 'totals')),
      );
      // ADR-016: the plate's structure and each item's component.
      expect(
        full.plates.first.structure.toJson().keys.toSet(),
        keysOf(p(plate, 'structure')),
      );
      expect(
        StructureKind.values.map((k) => k.wire).toList(),
        enumOf(p(p(plate, 'structure'), 'kind')),
      );
      expect(
        MealComponent.values.map((c) => c.wire).toList(),
        enumOf(p(items(plate, 'items'), 'component')),
      );
      final shortfall = full.toJson()['shortfall'] as Map<String, dynamic>;
      expect(shortfall.keys.toSet(), keysOf(p(rec, 'shortfall')));
      expect(
        full.proteinShortfall!.toJson().keys.toSet(),
        keysOf(p(p(rec, 'shortfall'), 'protein')),
      );
      final dish = items(rec, 'dishes');
      expect(full.dishes.first.toJson().keys.toSet(), keysOf(dish));
      final alternative = items(dish, 'alternatives');
      final withAlternative = full.dishes.firstWhere(
        (d) => d.alternatives.isNotEmpty,
        orElse: () => throw StateError('the fake needs a dish alternative'),
      );
      expect(
        withAlternative.alternatives.first.toJson().keys.toSet(),
        keysOf(alternative),
      );
      // Reasons only ever carry documented values.
      final reasonKeys = keysOf(items(plate, 'reasons'));
      for (final r in [
        ...full.plates.expand((x) => x.reasons),
        ...full.dishes.expand((d) => d.reasons),
      ]) {
        expect(reasonKeys.containsAll(r.toJson().keys), isTrue, reason: r.code);
      }
    });

    test('the query sends only date, mess and slot', () {
      final params = (doc['paths']['/mess/menu/recommend']['get']['parameters']
              as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['name'])
          .toSet();
      expect(params, {'date', 'mess', 'slot'});
    });

    test('a recommendation round-trips through its own JSON', () {
      final back = MessRecommendation.fromJson(
        jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(full.toJson()));
    });
  });

  group('TODAY (Phase 11)', () {
    Map<String, dynamic> p(Map<String, dynamic> s, String k) =>
        properties(s)[k] as Map<String, dynamic>;

    late Map<String, dynamic> plan;
    late Map<String, dynamic> action;
    late List<Map<String, dynamic>> reasons;
    setUpAll(() {
      plan = schemaOf('/today', 'get');
      action = p(plan, 'actions')['items'] as Map<String, dynamic>;
      reasons = (p(action, 'reason')['anyOf'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    });

    /// A value of the documented type (enough to exercise the words).
    Object? sample(String name, Map<String, dynamic> s) => switch (s['type']) {
          'boolean' => true,
          'number' || 'integer' => 2,
          'array' => ['knee'],
          _ when (s['pattern'] as String?)?.contains(r'\d{4}') ?? false =>
            '2026-09-26',
          _ when s['enum'] != null => (s['enum'] as List<dynamic>).first,
          _ => '$name value',
        };

    TodayReason sampleReason(Map<String, dynamic> variant) {
      final code = (p(variant, 'code')['enum'] as List<dynamic>?)?.first ??
          p(variant, 'code')['const'];
      final values = p(variant, 'values');
      return TodayReason(code as String, {
        for (final e in properties(values).entries)
          e.key: sample(e.key, e.value as Map<String, dynamic>),
      });
    }

    test('kinds, bases, targets and events are exactly the server\'s', () {
      expect(
        TodayKind.values.map((k) => k.wire).toList(),
        enumOf(p(action, 'kind')),
      );
      expect(
        ActionBasis.values.map((b) => b.wire).toList(),
        enumOf(p(action, 'basis')),
      );
      expect(
        ActionTarget.values.map((t) => t.wire).toList(),
        enumOf(p(action, 'target')),
      );
      final request =
          schemaOf('/today/actions/{id}/event', 'post', request: true);
      expect(
        TodayEventName.values.map((e) => e.wire).toList(),
        enumOf(p(request, 'event')),
      );
    });

    test('the plan and an action have exactly the documented properties', () {
      final a = FakeTodayApi.action(TodayKind.startWorkout);
      final full = TodayPlan(
        date: '2026-09-24',
        generatedAt: '2026-09-24T06:30:00.000Z',
        engineVersion: 'today-1',
        actions: [a],
      );
      expect(full.toJson().keys.toSet(), keysOf(plan));
      expect(a.toJson().keys.toSet(), keysOf(action));
      expect(a.reason.toJson().keys.toSet(), {'code', 'values'});
    });

    test('every reason code the server can send is worded from its values', () {
      expect(reasons, hasLength(11)); // Phase 12 adds calorie-target-off-trend
      for (final variant in reasons) {
        final r = sampleReason(variant);
        expect(TodayWords.facts(r), isNotEmpty, reason: r.code);
      }
    });

    test(
        'the event request sends exactly clientEventId, event, occurredAt; the stored event reads back',
        () {
      final request =
          schemaOf('/today/actions/{id}/event', 'post', request: true);
      const body = TodayEventRequest(
        clientEventId: '11111111-1111-4111-8111-111111111111',
        event: TodayEventName.shown,
        occurredAt: '2026-09-24T06:30:00.000Z',
      );
      expect(body.toJson().keys.toSet(), keysOf(request));
      final response = schemaOf('/today/actions/{id}/event', 'post');
      final record = TodayEventRecord.fromJson({
        'event': {
          'id': 'e',
          'recommendationId': 'r',
          'event': 'shown',
          'clientEventId': body.clientEventId,
          'occurredAt': body.occurredAt,
          'receivedAt': body.occurredAt,
        },
      });
      expect(keysOf(response), {'event'});
      expect(record.toJson().keys.toSet(), keysOf(p(response, 'event')));
    });

    test('a plan round-trips through its own JSON (the offline cache)', () {
      final full = TodayPlan(
        date: '2026-09-24',
        generatedAt: '2026-09-24T06:30:00.000Z',
        engineVersion: 'today-1',
        actions: [
          FakeTodayApi.action(
            TodayKind.eatProtein,
            subjectKey: 'lunch',
            reason: const TodayReason('protein-behind', {
              'slot': 'lunch',
              'proteinTarget': 106,
              'proteinLow': 0,
              'proteinHigh': 8,
              'kcalLeftLow': 2100,
              'kcalLeftHigh': 2276,
            }),
          ),
        ],
      );
      final back = TodayPlan.fromJson(
        jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(full.toJson()));
    });
  });

  group('Progress (Phase 12)', () {
    Map<String, dynamic> p(Map<String, dynamic> s, String k) =>
        properties(s)[k] as Map<String, dynamic>;
    Map<String, dynamic> items(Map<String, dynamic> s, String k) =>
        p(s, k)['items'] as Map<String, dynamic>;

    late Map<String, dynamic> sum;
    setUpAll(() => sum = schemaOf('/progress/summary', 'get'));

    const full = ProgressSummary(
      window: ProgressWindow.d30,
      today: '2026-09-24',
      from: '2026-08-26',
      weight: WeightProgress(
        points: [WeightPoint(date: '2026-09-24', rawKg: 75.4, trendKg: 75.1)],
        currentTrendKg: 75.1,
        weeklyChangeKg: -0.3,
        daysOfData: 14,
        isReliable: true,
        windowChangeKg: -0.5,
        windowChangeDays: 13,
      ),
      measurements: [
        SiteProgress(
          site: MeasurementSite.waist,
          latestDate: '2026-09-24',
          latestCm: 84.5,
          changeCm: -1.5,
          changeDays: 20,
        ),
      ],
      prs: [
        PrRecord(
          id: '11111111-1111-4111-8111-111111111111',
          exerciseId: '22222222-2222-4222-8222-222222222222',
          exerciseName: 'Bench',
          prType: 'weight',
          value: 85,
          previous: 80,
          reason: 'r',
          achievedOn: '2026-09-20',
        ),
      ],
      bestLifts: [
        BestLift(
          exerciseId: '22222222-2222-4222-8222-222222222222',
          exerciseName: 'Bench',
          estimated1RmKg: 93.5,
          weightKg: 85,
          reps: 3,
          date: '2026-09-20',
        ),
      ],
      adherence: Adherence(
        protein: AdherenceCount(met: 2, of: 4, percent: 50),
        calories: AdherenceCount(met: 2, of: 4, percent: 50),
        loggedDays: 4,
        daysWithoutTarget: 0,
      ),
      consistency: Consistency(
        weeks: [
          WeekConsistency(isoWeek: '2026-W39', completed: 2, planned: 2),
        ],
        completed: 2,
        planned: 2,
        percent: 100,
      ),
    );

    test('windows and measurement sites are exactly the server\'s', () {
      expect(
        ProgressWindow.values.map((w) => w.wire).toList(),
        enumOf(
          ((doc['paths']['/progress/summary']['get']['parameters']
                      as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .firstWhere((q) => q['name'] == 'window')['schema'])
              as Map<String, dynamic>,
        ),
      );
      expect(
        MeasurementSite.values.map((s) => s.wire).toList(),
        enumOf(p(items(sum, 'measurements'), 'site')),
      );
    });

    test(
        'the summary and every nested shape have exactly the documented properties',
        () {
      final j = full.toJson();
      expect(j.keys.toSet(), keysOf(sum));
      expect((j['weight'] as Map).keys.toSet(), keysOf(p(sum, 'weight')));
      expect(
        full.weight.points.first.toJson().keys.toSet(),
        keysOf(items(p(sum, 'weight'), 'points')),
      );
      expect(
        full.measurements.first.toJson().keys.toSet(),
        keysOf(items(sum, 'measurements')),
      );
      expect(full.prs.first.toJson().keys.toSet(), keysOf(items(sum, 'prs')));
      expect(
        full.bestLifts.first.toJson().keys.toSet(),
        keysOf(items(sum, 'bestLifts')),
      );
      expect(full.adherence.toJson().keys.toSet(), keysOf(p(sum, 'adherence')));
      expect(
        full.adherence.protein.toJson().keys.toSet(),
        keysOf(p(p(sum, 'adherence'), 'protein')),
      );
      expect(
        full.consistency.toJson().keys.toSet(),
        keysOf(p(sum, 'consistency')),
      );
      expect(
        full.consistency.weeks.first.toJson().keys.toSet(),
        keysOf(items(p(sum, 'consistency'), 'weeks')),
      );
    });

    test('the two writes send exactly weightKg/date and site/valueCm/date', () {
      final w = schemaOf('/progress/weight', 'post', request: true);
      expect(
        const LogWeightRequest(weightKg: 70, date: '2026-09-24')
            .toJson()
            .keys
            .toSet(),
        keysOf(w),
      );
      final m = schemaOf('/progress/measurement', 'post', request: true);
      expect(
        const LogMeasurementRequest(
          site: MeasurementSite.hip,
          valueCm: 98,
          date: '2026-09-24',
        ).toJson().keys.toSet(),
        keysOf(m),
      );
    });

    test('a summary round-trips through its own JSON (the offline cache)', () {
      final back = ProgressSummary.fromJson(
        jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(full.toJson()));
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
