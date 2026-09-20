import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/auth/domain/entities/user_profile.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_exercise_repository.dart';
import '../support/fake_training_repository.dart';
import '../support/fake_onboarding_repository.dart';

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
        withoutNulls(exercise.toJson()..remove('incrementKg')).keys.toSet(),
        reason: 'incrementKg is the only optional field',
      );

      // patch: both optional; at least one sent.
      final patch = schemaOf(
        '/training/program/days/{id}',
        'patch',
        request: true,
      );
      const patchBody = PatchProgramDayRequest(
        sessionName: 's',
        exercises: [exercise],
      );
      expect(withoutNulls(patchBody.toJson()).keys.toSet(), keysOf(patch));
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
