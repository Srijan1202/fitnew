import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
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
    final result = await _repo.getProgram();
    return result.when(ok: (p) => p, err: (f) => throw f);
  }

  Future<Failure?> _apply(Future<Result<Program>> call) async {
    final result = await call;
    return result.when<Failure?>(
      ok: (p) {
        state = AsyncData(p);
        return null;
      },
      err: (f) => f,
    );
  }

  Future<Failure?> generate({int? daysPerWeek, int? preferredSessionMinutes}) =>
      _apply(
        _repo.generate(
          GenerateProgramRequest(
            daysPerWeek: daysPerWeek,
            preferredSessionMinutes: preferredSessionMinutes,
          ),
        ),
      );

  Future<Failure?> putCustom(PutProgramRequest request) =>
      _apply(_repo.putProgram(request));

  Future<Failure?> patchDay(String dayId, PatchProgramDayRequest request) =>
      _apply(_repo.patchDay(dayId, request));
}

final programControllerProvider =
    AsyncNotifierProvider<ProgramController, Program?>(
  ProgramController.new,
  // No silent retry-with-backoff: a failure shows with "Try again" (§6.6).
  retry: (_, __) => null,
);
