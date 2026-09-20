import 'package:freezed_annotation/freezed_annotation.dart';

/// Closed vocabularies, mirroring `@fitos/contracts` profile.ts exactly.
///
/// Every `@JsonValue` is the wire string the server's Zod enum accepts. The
/// contract-conformance test (`test/contracts/`) reads openapi.json and fails
/// if any list here diverges from the server's — that is how "contracts can't
/// drift" is enforced (ADR-004).
///
/// `label` is display copy and lives here rather than in screens so the same
/// word appears everywhere a value is shown.

enum GoalType {
  @JsonValue('muscle-gain')
  muscleGain(
    'muscle-gain',
    'Build muscle',
    'Eat a little above maintenance and train for growth.',
  ),
  @JsonValue('fat-loss')
  fatLoss(
    'fat-loss',
    'Lose fat',
    'A steady deficit that protects your training.',
  ),
  @JsonValue('recomposition')
  recomposition(
    'recomposition',
    'Recomposition',
    'Lose fat while keeping muscle. Slow, but it works.',
  ),
  @JsonValue('strength')
  strength(
    'strength',
    'Get stronger',
    'Lower reps, heavier loads, a small surplus.',
  ),
  @JsonValue('general')
  general(
    'general',
    'General fitness',
    'Feel better, move more, no strict target.',
  ),
  @JsonValue('maintenance')
  maintenance(
    'maintenance',
    'Maintain',
    'Hold where you are and keep the habit.',
  );

  const GoalType(this.wire, this.label, this.blurb);
  final String wire;
  final String label;
  final String blurb;
}

enum Sex {
  @JsonValue('male')
  male('male', 'Male'),
  @JsonValue('female')
  female('female', 'Female');

  const Sex(this.wire, this.label);
  final String wire;
  final String label;
}

enum ExperienceLevel {
  @JsonValue('beginner')
  beginner('beginner', 'Beginner', 'Under a year of consistent training.'),
  @JsonValue('intermediate')
  intermediate(
    'intermediate',
    'Intermediate',
    'One to three years. You know the main lifts.',
  ),
  @JsonValue('advanced')
  advanced(
    'advanced',
    'Advanced',
    'Three years or more, progressing on a plan.',
  );

  const ExperienceLevel(this.wire, this.label, this.blurb);
  final String wire;
  final String label;
  final String blurb;
}

enum ActivityLevel {
  @JsonValue('sedentary')
  sedentary('sedentary', 'Mostly sitting', 'Lectures, desk, not much walking.'),
  @JsonValue('light')
  light(
    'light',
    'Lightly active',
    'On your feet a fair bit. Most hostel days.',
  ),
  @JsonValue('moderate')
  moderate('moderate', 'Moderately active', 'Walking or cycling most days.'),
  @JsonValue('high')
  high('high', 'Very active', 'Physical work or sport beyond the gym.');

  const ActivityLevel(this.wire, this.label, this.blurb);
  final String wire;
  final String label;
  final String blurb;
}

enum DietType {
  @JsonValue('vegetarian')
  vegetarian('vegetarian', 'Vegetarian'),
  @JsonValue('eggetarian')
  eggetarian('eggetarian', 'Eggetarian'),
  @JsonValue('non-vegetarian')
  nonVegetarian('non-vegetarian', 'Non-vegetarian');

  const DietType(this.wire, this.label);
  final String wire;
  final String label;
}

enum TrainingLocation {
  @JsonValue('commercial-gym')
  commercialGym('commercial-gym', 'Commercial gym'),
  @JsonValue('campus-gym')
  campusGym('campus-gym', 'Campus gym'),
  @JsonValue('home')
  home('home', 'Home or hostel room');

  const TrainingLocation(this.wire, this.label);
  final String wire;
  final String label;
}

enum Equipment {
  @JsonValue('barbell')
  barbell('barbell', 'Barbell'),
  @JsonValue('dumbbell')
  dumbbell('dumbbell', 'Dumbbells'),
  @JsonValue('machine')
  machine('machine', 'Machines'),
  @JsonValue('cable')
  cable('cable', 'Cables'),
  @JsonValue('kettlebell')
  kettlebell('kettlebell', 'Kettlebell'),
  @JsonValue('resistance-band')
  resistanceBand('resistance-band', 'Resistance bands'),
  @JsonValue('pull-up-bar')
  pullUpBar('pull-up-bar', 'Pull-up bar'),
  @JsonValue('bodyweight')
  bodyweight('bodyweight', 'Bodyweight only');

  const Equipment(this.wire, this.label);
  final String wire;
  final String label;
}

/// SAFETY-CRITICAL on the server: a hard filter, never a penalty (§9.2).
enum Allergen {
  @JsonValue('peanut')
  peanut('peanut', 'Peanut'),
  @JsonValue('tree-nut')
  treeNut('tree-nut', 'Tree nuts'),
  @JsonValue('milk')
  milk('milk', 'Milk'),
  @JsonValue('egg')
  egg('egg', 'Egg'),
  @JsonValue('soy')
  soy('soy', 'Soy'),
  @JsonValue('wheat')
  wheat('wheat', 'Wheat / gluten'),
  @JsonValue('fish')
  fish('fish', 'Fish'),
  @JsonValue('shellfish')
  shellfish('shellfish', 'Shellfish'),
  @JsonValue('sesame')
  sesame('sesame', 'Sesame'),
  @JsonValue('mustard')
  mustard('mustard', 'Mustard');

  const Allergen(this.wire, this.label);
  final String wire;
  final String label;
}

enum AllergySeverity {
  @JsonValue('mild')
  mild('mild', 'Mild'),
  @JsonValue('moderate')
  moderate('moderate', 'Moderate'),
  @JsonValue('severe')
  severe('severe', 'Severe');

  const AllergySeverity(this.wire, this.label);
  final String wire;
  final String label;
}

enum Units {
  @JsonValue('metric')
  metric('metric'),
  @JsonValue('imperial')
  imperial('imperial');

  const Units(this.wire);
  final String wire;
}

enum BudgetTier {
  @JsonValue('low')
  low('low'),
  @JsonValue('medium')
  medium('medium'),
  @JsonValue('high')
  high('high');

  const BudgetTier(this.wire);
  final String wire;
}

/// Screens 1–6 plus the terminal state. Order is §32 order.
enum OnboardingStage {
  @JsonValue('goal')
  goal('goal'),
  @JsonValue('about')
  about('about'),
  @JsonValue('experience')
  experience('experience'),
  @JsonValue('training')
  training('training'),
  @JsonValue('food')
  food('food'),
  @JsonValue('vit')
  vit('vit'),
  @JsonValue('complete')
  complete('complete');

  const OnboardingStage(this.wire);
  final String wire;

  static OnboardingStage fromWire(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => goal);

  /// The six answerable steps, in order.
  static const List<OnboardingStage> steps = [
    goal,
    about,
    experience,
    training,
    food,
    vit,
  ];

  int get screenNumber => steps.indexOf(this) + 1;
}

enum ConsentType {
  @JsonValue('privacy-policy')
  privacyPolicy('privacy-policy'),
  @JsonValue('health-data-processing')
  healthDataProcessing('health-data-processing');

  const ConsentType(this.wire);
  final String wire;
}
