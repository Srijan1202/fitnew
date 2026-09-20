import '../../../../core/errors/result.dart';
import '../entities/onboarding.dart';

/// Onboarding contract. Nothing in here decides anything — the server derives
/// the next step and the client renders it (§7.3).
abstract class OnboardingRepository {
  Future<Result<OnboardingState>> getState();
  Future<Result<OnboardingState>> answer(OnboardingAnswer answer);
  Future<Result<OnboardingCompleteResponse>> complete();
}
