import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';

/// A brand-new user: nothing answered, stage is the first screen.
const freshProfile = UserProfileDetail(
  sex: null,
  birthDate: null,
  heightCm: null,
  experienceLevel: null,
  trainingDaysPerWeek: null,
  activityLevel: null,
  preferredSessionMinutes: null,
  trainingLocation: null,
  equipment: <Equipment>[],
  latestWeightKg: null,
  timezone: 'Asia/Kolkata',
  locale: 'en-IN',
  onboardingStage: 'goal',
  mess: null,
);

const freshState = OnboardingState(
  stage: OnboardingStage.goal,
  completed: false,
  answered: <OnboardingStage>[],
  missing: OnboardingStage.steps,
  profile: freshProfile,
  goalType: null,
  dietType: null,
  allergies: <Allergy>[],
  policyVersion: '2026-09-21',
);

/// Persona C from the spec's manual calculation, three screens in.
const midwayProfile = UserProfileDetail(
  sex: Sex.female,
  birthDate: '2005-03-14',
  heightCm: 160,
  experienceLevel: ExperienceLevel.beginner,
  trainingDaysPerWeek: 3,
  activityLevel: ActivityLevel.light,
  preferredSessionMinutes: null,
  trainingLocation: null,
  equipment: <Equipment>[],
  latestWeightKg: 58,
  timezone: 'Asia/Kolkata',
  locale: 'en-IN',
  onboardingStage: 'training',
  mess: null,
);

const midwayState = OnboardingState(
  stage: OnboardingStage.training,
  completed: false,
  answered: <OnboardingStage>[
    OnboardingStage.goal,
    OnboardingStage.about,
    OnboardingStage.experience,
  ],
  missing: <OnboardingStage>[OnboardingStage.training, OnboardingStage.food],
  profile: midwayProfile,
  goalType: GoalType.fatLoss,
  dietType: null,
  allergies: <Allergy>[],
  policyVersion: '2026-09-21',
);

/// The numbers the API integration test derives by hand for Persona C.
const personaCTargets = NutritionTargets(
  effectiveFrom: '2026-09-21',
  kcal: 2276,
  proteinG: 106,
  carbG: 337,
  fatG: 56,
  fiberG: 30,
  bmr: 1348,
  tdeeEstimate: 2069,
  rationale: <String>[
    'Mifflin-St Jeor BMR 1348 kcal',
    'TDEE 2069 kcal at light activity',
  ],
  reason: 'onboarding',
);

final personaCGoal = Goal(
  id: '9c8b7a65-4321-4fed-cba9-876543210fed',
  goalType: GoalType.fatLoss,
  targetWeightKg: null,
  startedAt: DateTime.utc(2026, 9, 21, 9),
);

/// Scripted OnboardingRepository. Records every call; answers advance a
/// scripted state so tests can assert the *server's* view moved.
class FakeOnboardingRepository implements OnboardingRepository {
  Result<OnboardingState> nextState = const Ok(freshState);
  Result<OnboardingState>? nextAnswer;
  Result<OnboardingCompleteResponse>? nextComplete;

  final calls = <String>[];
  final answers = <OnboardingAnswer>[];

  @override
  Future<Result<OnboardingState>> getState() async {
    calls.add('getState');
    return nextState;
  }

  @override
  Future<Result<OnboardingState>> answer(OnboardingAnswer answer) async {
    calls.add('answer:${answer.runtimeType}');
    answers.add(answer);
    final scripted = nextAnswer;
    if (scripted != null) return scripted;
    // Default: the server accepted it and moved to the next step.
    final current = nextState;
    if (current is! Ok<OnboardingState>) return current;
    final s = current.value;
    final stage = _stageOf(answer);
    final answered = {...s.answered, stage}.toList();
    final missing = s.missing.where((m) => m != stage).toList();
    final nextStage = OnboardingStage.steps.firstWhere(
      (step) => !answered.contains(step),
      orElse: () => OnboardingStage.complete,
    );
    final next = s.copyWith(
      stage: nextStage,
      answered: answered,
      missing: missing,
    );
    nextState = Ok(next);
    return Ok(next);
  }

  @override
  Future<Result<OnboardingCompleteResponse>> complete() async {
    calls.add('complete');
    return nextComplete ??
        Ok(
          OnboardingCompleteResponse(
            profile: midwayProfile.copyWith(onboardingStage: 'complete'),
            goal: personaCGoal,
            targets: personaCTargets,
          ),
        );
  }

  static OnboardingStage _stageOf(OnboardingAnswer a) => switch (a) {
        GoalAnswer() => OnboardingStage.goal,
        AboutAnswer() => OnboardingStage.about,
        ExperienceAnswer() => OnboardingStage.experience,
        TrainingAnswer() => OnboardingStage.training,
        FoodAnswer() => OnboardingStage.food,
        VitAnswer() => OnboardingStage.vit,
      };
}

/// The server's 18+ rejection as the client sees it (§23).
const under18 = Validation(
  'You must be 18 or older to use FitOS.',
  field: 'birthDate',
);
