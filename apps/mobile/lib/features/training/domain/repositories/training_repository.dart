import '../../../../core/errors/result.dart';
import '../entities/program.dart';

/// The active programme and the ways it changes. Nothing here decides what
/// a programme should contain (§30: generation, templates and their
/// exercise selection are the backend's).
abstract class TrainingRepository {
  /// `Ok(null)` when there is no active programme yet (server 404).
  Future<Result<Program?>> getProgram();
  Future<Result<Program>> generate(GenerateProgramRequest request);
  Future<Result<Program>> putProgram(PutProgramRequest request);
  Future<Result<Program>> patchDay(
    String dayId,
    PatchProgramDayRequest request,
  );
  Future<Result<Program>> rename(String name);

  /// ADR-030: skip today — every day of the week moves one day later.
  Future<Result<Program>> skipToday();

  /// ADR-030: undo today's skip — every day moves back.
  Future<Result<Program>> undoSkip();
  Future<Result<List<ProgramTemplate>>> listTemplates();
  Future<Result<TemplatePreview>> previewTemplate(
    String slug,
    GenerateProgramRequest request,
  );
  Future<Result<Program>> applyTemplate(
    String slug,
    GenerateProgramRequest request,
  );
}
