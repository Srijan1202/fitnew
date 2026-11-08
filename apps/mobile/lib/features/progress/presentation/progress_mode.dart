import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Beta 5.9 (owner: "move progress and recovery to the nutrition, make food
/// the default"): the Nutrition tab has three parts, Food · Progress ·
/// Recovery, chosen at the top with Training's switch. It opens on Food; the
/// choice holds while the app is open. Home's readiness and check-in sleep,
/// and the check-in reminder, open Recovery. (Beta 5.7 had Progress | Recovery
/// as a tab of its own; Community took that place in the bar.)
enum NutritionMode { food, progress, recovery }

class NutritionModeController extends Notifier<NutritionMode> {
  @override
  NutritionMode build() => NutritionMode.food;

  void set(NutritionMode mode) => state = mode;
}

final nutritionModeProvider =
    NotifierProvider<NutritionModeController, NutritionMode>(
  NutritionModeController.new,
);
