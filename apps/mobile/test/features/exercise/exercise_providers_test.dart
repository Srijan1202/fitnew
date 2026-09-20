import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/exercise/presentation/controllers/exercise_providers.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercise_repository.dart';

/// The filters are client state; the list is whatever the server answers.
/// These pin that every filter change becomes a request with the contract's
/// query shape, and that nothing is filtered locally.
void main() {
  late FakeExerciseRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeExerciseRepository();
    container = ProviderContainer(
      overrides: [exerciseRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(exerciseListProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  ExerciseFilters filters() => container.read(exerciseFiltersProvider.notifier);
  Future<ExerciseListResponse> list() =>
      container.read(exerciseListProvider.future);

  test('the first load asks for everything, with the default page size',
      () async {
    final page = await list();
    expect(page.items, [squat, pushUp]);
    expect(repo.queries.single.toQueryParameters(), {
      'limit': '200',
      'offset': '0',
    });
  });

  test('toggling equipment sends the set, comma-separated and sorted',
      () async {
    await list();
    filters().toggleEquipment(Equipment.dumbbell);
    filters().toggleEquipment(Equipment.barbell);
    await list();
    expect(
      repo.queries.last.toQueryParameters()['equipment'],
      'barbell,dumbbell',
    );

    filters().toggleEquipment(Equipment.dumbbell);
    await list();
    expect(repo.queries.last.toQueryParameters()['equipment'], 'barbell');

    filters().toggleEquipment(Equipment.barbell);
    await list();
    expect(
      repo.queries.last.toQueryParameters().containsKey('equipment'),
      isFalse,
    );
  });

  test('muscle and pattern are single-valued and clearable; search is trimmed',
      () async {
    await list();
    filters().setMuscle(MuscleGroup.chest);
    filters().setPattern(MovementPattern.horizontalPush);
    filters().setSearch('  push  ');
    await list();
    expect(repo.queries.last.toQueryParameters(), {
      'q': 'push',
      'muscle': 'chest',
      'pattern': 'horizontal-push',
      'limit': '200',
      'offset': '0',
    });

    filters().clear();
    await list();
    expect(repo.queries.last.hasFilters, isFalse);
  });

  test('the client shows what the server returns, never a local subset',
      () async {
    // The fake ignores the query and returns the squat for a bodyweight-only
    // ask. If the client filtered locally the squat would vanish; it must not.
    filters().toggleEquipment(Equipment.bodyweight);
    final page = await list();
    expect(page.items.map((i) => i.slug), contains('barbell-back-squat'));
  });

  test('a failed load is an error state, not a retry loop', () async {
    // Script the failure BEFORE anything watches the provider.
    final failing = FakeExerciseRepository()
      ..nextList = (_) => const Err(Offline());
    final c = ProviderContainer(
      overrides: [exerciseRepositoryProvider.overrideWithValue(failing)],
    );
    addTearDown(c.dispose);
    c.listen(exerciseListProvider, (_, __) {});
    await expectLater(
      c.read(exerciseListProvider.future),
      throwsA(isA<Offline>()),
    );
    final state = c.read(exerciseListProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('detail is fetched by id and cached per id', () async {
    final d = await container.read(exerciseDetailProvider(squat.id).future);
    expect(d, squatDetail);
    await container.read(exerciseDetailProvider(squat.id).future);
    expect(repo.detailIds, [squat.id]);
  });
}
