import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/progress/data/lift_history_api.dart';
import 'package:fitos/features/progress/presentation/lift_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements LiftHistoryApi {
  _FakeApi(this.answer);
  final Result<LiftHistory> answer;
  final asked = <String>[];

  @override
  Future<Result<LiftHistory>> history(String exerciseId) async {
    asked.add(exerciseId);
    return answer;
  }
}

LiftSession _s(
  String id,
  String date,
  double kg,
  int reps, {
  bool record = false,
}) =>
    LiftSession(
      sessionId: id,
      date: date,
      sets: [
        LiftSet(weightKg: kg, reps: reps, rir: 1),
        LiftSet(weightKg: kg, reps: reps - 2, rir: 0),
      ],
      topWeightKg: kg,
      topReps: reps,
      estimated1RmKg: double.parse((kg * (1 + reps / 30)).toStringAsFixed(1)),
      volumeKg: kg * (2 * reps - 2),
      reps: 2 * reps - 2,
      record: record,
    );

/// Beta 6.1 (E3): a lift's whole history.
void main() {
  Widget app(_FakeApi api) => ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('u1'),
          liftHistoryApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const LiftHistoryScreen(exerciseId: 'bench'),
        ),
      );

  testWidgets(
      'the estimate over time, then every session newest first, records marked',
      (tester) async {
    final api = _FakeApi(
      Ok(
        LiftHistory(
          exerciseId: 'bench',
          name: 'Barbell Bench Press',
          sessions: [
            _s('c', '2026-11-08', 57.5, 10),
            _s('b', '2026-11-04', 60, 10, record: true),
            _s('a', '2026-10-31', 50, 10, record: true),
          ],
          bestKg: 80,
          bestDate: '2026-11-04',
          truncated: false,
        ),
      ),
    );
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(api.asked, ['bench']);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(
      find.textContaining('3 sessions · best est. 1RM 80.0 kg on'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lift.chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('lift.record.b')), findsOneWidget);
    expect(find.byKey(const ValueKey('lift.record.c')), findsNothing);
    expect(find.text('57.5×10, 57.5×8'), findsOneWidget);
    final c = tester.getTopLeft(find.byKey(const ValueKey('lift.session.c')));
    final a = tester.getTopLeft(find.byKey(const ValueKey('lift.session.a')));
    expect(c.dy, lessThan(a.dy));
  });

  testWidgets('no sessions yet: says so, no chart', (tester) async {
    await tester.pumpWidget(
      app(
        _FakeApi(
          const Ok(
            LiftHistory(
              exerciseId: 'bench',
              name: 'Barbell Bench Press',
              sessions: [],
              bestKg: null,
              bestDate: null,
              truncated: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No sessions with this lift yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('lift.chart')), findsNothing);
  });

  testWidgets('offline with nothing kept: the error and Try again',
      (tester) async {
    await tester.pumpWidget(app(_FakeApi(const Err(Offline()))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lift.error')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
