import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../data/exercise_repository_impl.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return DioExerciseRepository(ref.watch(dioProvider));
});

/// The browser's filters. Pure client state; changing it re-asks the server.
class ExerciseFilters extends Notifier<ExerciseQuery> {
  @override
  ExerciseQuery build() => const ExerciseQuery();

  void setSearch(String q) => state = state.copyWith(q: q, offset: 0);

  void toggleEquipment(Equipment e) {
    final next = {...state.equipment};
    if (!next.remove(e)) next.add(e);
    state = state.copyWith(equipment: next, offset: 0);
  }

  void setMuscle(MuscleGroup? m) =>
      state = state.copyWith(muscle: m, offset: 0);

  void setPattern(MovementPattern? p) =>
      state = state.copyWith(pattern: p, offset: 0);

  void clear() => state = const ExerciseQuery();
}

final exerciseFiltersProvider =
    NotifierProvider<ExerciseFilters, ExerciseQuery>(ExerciseFilters.new);

/// The list for the current filters. Every filter change is a request; the
/// client never filters a cached superset itself (§30: the performability
/// rule is the server's).
final exerciseListProvider = FutureProvider<ExerciseListResponse>(
  (ref) async {
    final query = ref.watch(exerciseFiltersProvider);
    final result = await ref.read(exerciseRepositoryProvider).list(query);
    return result.when(ok: (r) => r, err: (f) => throw f);
  },
  // No silent retry-with-backoff: a failure is shown with "Try again" (§6.6).
  retry: (_, __) => null,
);

final exerciseDetailProvider = FutureProvider.family<ExerciseDetail, String>(
  (ref, id) async {
    final result = await ref.read(exerciseRepositoryProvider).detail(id);
    return result.when(ok: (d) => d, err: (f) => throw f);
  },
  retry: (_, __) => null,
);
