import '../../../../core/errors/result.dart';
import '../entities/program.dart';

/// The active programme and the three ways it changes. Nothing here decides
/// what a programme should contain (§30: generation is the backend's).
abstract class TrainingRepository {
  /// `Ok(null)` when there is no active programme yet (server 404).
  Future<Result<Program?>> getProgram();
  Future<Result<Program>> generate(GenerateProgramRequest request);
  Future<Result<Program>> putProgram(PutProgramRequest request);
  Future<Result<Program>> patchDay(
    String dayId,
    PatchProgramDayRequest request,
  );
}
