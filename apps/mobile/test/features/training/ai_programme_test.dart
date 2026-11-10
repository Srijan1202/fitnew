import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/training/data/ai_programme_api.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:fitos/features/training/presentation/screens/ai_programme_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_training_repository.dart';

class _Api implements AiProgrammeApi {
  final asked = <Map<String, Object?>>[];

  @override
  Future<Result<AiProgrammeDraft>> draft({
    required int sessions,
    required int minutes,
    required List<String> focus,
    required List<String> avoid,
    String? note,
  }) async {
    asked.add({
      'sessions': sessions,
      'minutes': minutes,
      'focus': focus,
      'avoid': avoid,
      'note': note,
    });
    return Ok(
      AiProgrammeDraft.fromJson({
        'name': 'Upper Lower',
        'why': 'Each muscle twice a week.',
        'adjustments': ['Upper shortened to about 52 minutes.'],
        'days': [
          for (final n in ['Upper', 'Lower', 'Upper B', 'Lower B'])
            {
              'sessionName': n,
              'exercises': [
                for (var i = 0; i < 3; i++)
                  {
                    'exerciseId': 'eeeeeeee-eeee-4eee-8eee-00000000000$i',
                    'name': '$n move $i',
                    'setCount': 3,
                    'repMin': 8,
                    'repMax': 12,
                    'targetRir': 2,
                  },
              ],
            },
        ],
      }),
    );
  }
}

/// Beta 6.1 (premium): Build with FITOS AI.
void main() {
  late FakeTrainingRepository training;
  late _Api api;

  setUp(() {
    training = FakeTrainingRepository();
    api = _Api();
  });

  Widget app(bool? premium) {
    final router = GoRouter(
      initialLocation: '/plan/ai',
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, __) => const Scaffold(body: Text('PLAN')),
        ),
        GoRoute(
          path: '/plan/ai',
          builder: (_, __) => const AiProgrammeScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('u1'),
        isPremiumProvider.overrideWithValue(premium),
        trainingRepositoryProvider.overrideWithValue(training),
        aiProgrammeApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  testWidgets('a free account sees what Premium is', (tester) async {
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiprog.premium')), findsOneWidget);
  });

  testWidgets(
      'the answers go to the server; the draft shows what FITOS changed; Use makes it the programme on weekdays',
      (tester) async {
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiprog.noteWarning')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('aiprog.sessions.4')));
    await tester.tap(find.byKey(const ValueKey('aiprog.minutes.45')));
    await tester.tap(find.byKey(const ValueKey('aiprog.focus.chest')));
    await tester.enterText(
      find.byKey(const ValueKey('aiprog.note')),
      'short sessions please',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('aiprog.build')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('aiprog.build')));
    await tester.pumpAndSettle();

    expect(api.asked.single, {
      'sessions': 4,
      'minutes': 45,
      'focus': ['chest'],
      'avoid': <String>[],
      'note': 'short sessions please',
    });
    expect(find.text('Upper Lower'), findsOneWidget);
    expect(find.text('Upper shortened to about 52 minutes.'), findsOneWidget);
    expect(find.text('Monday · Upper'), findsOneWidget);
    expect(find.text('Friday · Lower B'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('aiprog.use')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('aiprog.use')));
    await tester.pumpAndSettle();
    final put = training.putRequests.single;
    expect(put.name, 'Upper Lower');
    expect(put.days.map((d) => d.dayOfWeek), [1, 2, 4, 5]);
    expect(put.days.first.exercises.first.setCount, 3);
    expect(find.text('PLAN'), findsOneWidget);
  });
}
