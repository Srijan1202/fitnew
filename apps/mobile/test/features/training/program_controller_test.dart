import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/training/domain/entities/program.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_training_repository.dart';

/// The controller is a pipe: server state in, server state out. Nothing is
/// generated, edited or recomputed on the client (§30).
void main() {
  late FakeTrainingRepository repo;
  late ProviderContainer container;

  setUp(() => repo = FakeTrainingRepository());

  void start() {
    container = ProviderContainer(
      overrides: [trainingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(programControllerProvider, (_, __) {});
  }

  ProgramController notifier() =>
      container.read(programControllerProvider.notifier);
  Future<Program?> settled() =>
      container.read(programControllerProvider.future);

  test('no programme is a null value, not an error', () async {
    start();
    expect(await settled(), isNull);
    expect(repo.calls, ['getProgram']);
  });

  test('an existing programme loads as-is', () async {
    repo.nextProgram = Ok(generatedProgram);
    start();
    expect(await settled(), generatedProgram);
  });

  test(
      'generate replaces state with the server answer and sends only overrides',
      () async {
    start();
    await settled();
    final failure = await notifier().generate(daysPerWeek: 3);
    expect(failure, isNull);
    expect(
      container.read(programControllerProvider).requireValue,
      generatedProgram,
    );
    expect(
      withoutNulls(repo.generateRequests.single.toJson()),
      {'daysPerWeek': 3},
    );
    await notifier().generate();
    expect(withoutNulls(repo.generateRequests.last.toJson()), isEmpty);
  });

  test('a failed generate returns the failure and leaves state alone',
      () async {
    start();
    await settled();
    repo.nextGenerate = const Err(Offline());
    final failure = await notifier().generate();
    expect(failure, isA<Offline>());
    expect(container.read(programControllerProvider).requireValue, isNull);
  });

  test('patchDay sends the day id and body, then adopts the returned plan',
      () async {
    repo.nextProgram = Ok(generatedProgram);
    start();
    await settled();
    const body = PatchProgramDayRequest(sessionName: 'Arms');
    final failure = await notifier().patchDay('day-1', body);
    expect(failure, isNull);
    expect(repo.patchRequests.single, ('day-1', body));
  });

  test('putCustom sends the whole programme', () async {
    start();
    await settled();
    const request = PutProgramRequest(
      name: 'Mine',
      days: [
        CustomDay(
          dayOfWeek: 1,
          sessionName: 'A',
          exercises: [
            CustomExercise(
              exerciseId: 'x',
              setCount: 3,
              repMin: 8,
              repMax: 12,
              targetRir: 2,
            ),
          ],
        ),
        CustomDay(
          dayOfWeek: 4,
          sessionName: 'B',
          exercises: [
            CustomExercise(
              exerciseId: 'y',
              setCount: 3,
              repMin: 8,
              repMax: 12,
              targetRir: 2,
            ),
          ],
        ),
      ],
    );
    await notifier().putCustom(request);
    expect(repo.putRequests.single, request);
    expect(
      container.read(programControllerProvider).requireValue,
      generatedProgram,
    );
  });

  test('a failed load is an error state, not a retry loop', () async {
    repo.nextProgram = const Err(Offline());
    start();
    await expectLater(settled(), throwsA(isA<Offline>()));
    final state = container.read(programControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
  });
}
