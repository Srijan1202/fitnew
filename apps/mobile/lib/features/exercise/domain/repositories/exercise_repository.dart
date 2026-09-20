import '../../../../core/errors/result.dart';
import '../entities/exercise.dart';

/// Read-only: the library is seeded and admin-edited, never written from
/// the app. Filtering is the server's — the client sends the query and
/// renders the answer (§30).
abstract class ExerciseRepository {
  Future<Result<ExerciseListResponse>> list(ExerciseQuery query);
  Future<Result<ExerciseDetail>> detail(String id);
}
