import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/onboarding_repository_impl.dart';
import '../../domain/entities/onboarding.dart';
import '../../domain/repositories/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return DioOnboardingRepository(ref.watch(dioProvider));
});

/// Drives screens 1–7 (§32).
///
/// State is the server's `OnboardingState` — the client holds no separate
/// notion of "where am I". Every answer round-trips and the response is the
/// new state, so a killed app resumes from exactly the data the server has.
///
/// Per-submit busy/error is the screen's (via `OnboardingStep` widget), so
/// the form stays populated while a request is in flight; only the initial
/// load uses `AsyncValue`'s loading state.
class OnboardingController extends AsyncNotifier<OnboardingState> {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  Future<OnboardingState> build() async {
    // A new sign-in never resumes the previous user's steps.
    requireSession(ref);
    final result = await _repo.getState();
    return result.when(ok: (s) => s, err: (f) => throw f);
  }

  /// Submit one screen. Returns the failure to show inline, or null.
  Future<Failure?> answer(OnboardingAnswer answer) async {
    final result = await _repo.answer(answer);
    return result.when<Failure?>(
      ok: (next) {
        state = AsyncData(next);
        return null;
      },
      err: (failure) => failure,
    );
  }

  /// Screen 7. On success the auth session is marked complete so the route
  /// guard opens TODAY on this and every future cold start.
  Future<Result<OnboardingCompleteResponse>> complete() async {
    final result = await _repo.complete();
    if (result is Ok<OnboardingCompleteResponse>) {
      await ref.read(authControllerProvider.notifier).markOnboardingComplete();
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(profile: result.value.profile));
      }
    }
    return result;
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
  // Riverpod 3 would otherwise retry a failed load with back-off while
  // reporting `isLoading`, so the user would stare at a skeleton for ~13s
  // before seeing anything. A failure is shown at once with its own
  // "Try again" (§6.6); retrying is the user's call.
  retry: (_, __) => null,
);
