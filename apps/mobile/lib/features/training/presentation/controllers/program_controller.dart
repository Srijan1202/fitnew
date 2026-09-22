import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../data/training_repository_impl.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/training_repository.dart';

final trainingRepositoryProvider = Provider<TrainingRepository>((ref) {
  return DioTrainingRepository(ref.watch(dioProvider));
});

/// The active programme, or null before one exists. Every mutation
/// round-trips and the server's answer replaces state — the client never
/// edits the plan locally and hopes.
class ProgramController extends AsyncNotifier<Program?> {
  TrainingRepository get _repo => ref.read(trainingRepositoryProvider);

  @override
  Future<Program?> build() async {
    requireSession(ref); // rebuilt on sign-out / sign-in as someone else
    final result = await _repo.getProgram();
    return result.when(ok: (p) => p, err: (f) => throw f);
  }

  Future<Failure?> _apply(Future<Result<Program>> call) async {
    final result = await call;
    return result.when<Failure?>(
      ok: (p) {
        // A flush-on-leave can land after the session (and this notifier)
        // is gone; the server has the edit, there is nothing left to show.
        if (ref.mounted) state = AsyncData(p);
        return null;
      },
      err: (f) => f,
    );
  }

  Future<Failure?> generate({
    int? daysPerWeek,
    int? preferredSessionMinutes,
    List<MuscleGroup>? emphasis,
  }) =>
      _apply(
        _repo.generate(
          GenerateProgramRequest(
            daysPerWeek: daysPerWeek,
            preferredSessionMinutes: preferredSessionMinutes,
            emphasis: emphasis,
          ),
        ),
      );

  Future<Failure?> putCustom(PutProgramRequest request) =>
      _apply(_repo.putProgram(request));

  Future<Failure?> patchDay(String dayId, PatchProgramDayRequest request) =>
      _apply(_repo.patchDay(dayId, request));

  Future<Failure?> rename(String name) => _apply(_repo.rename(name));

  Future<Failure?> applyTemplate(
    String slug, {
    int? preferredSessionMinutes,
    List<MuscleGroup>? emphasis,
  }) =>
      _apply(
        _repo.applyTemplate(
          slug,
          GenerateProgramRequest(
            preferredSessionMinutes: preferredSessionMinutes,
            emphasis: emphasis,
          ),
        ),
      );
}

/// The professional library. Structures only; exercises come with a preview.
final templatesProvider = FutureProvider<List<ProgramTemplate>>(
  (ref) async {
    requireSession(ref);
    final result = await ref.read(trainingRepositoryProvider).listTemplates();
    return result.when(ok: (t) => t, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// A template materialised for this user. Nothing is stored by previewing.
final templatePreviewProvider = FutureProvider.family<TemplatePreview, String>(
  (ref, slug) async {
    requireSession(ref);
    final result = await ref
        .read(trainingRepositoryProvider)
        .previewTemplate(slug, const GenerateProgramRequest());
    return result.when(ok: (p) => p, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final programControllerProvider =
    AsyncNotifierProvider<ProgramController, Program?>(
  ProgramController.new,
  // No silent retry-with-backoff: a failure shows with "Try again" (§6.6).
  retry: (_, __) => null,
);
