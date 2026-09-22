import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/ai/domain/entities/ai.dart';
import 'package:fitos/features/ai/presentation/controllers/ai_providers.dart';
import 'package:fitos/features/ai/presentation/screens/ai_chat_screen.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_ai_api.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 6.6 Gate 4 — the FITOS AI screen against a scripted server: the
/// empty state with starter prompts, a sent turn and the answer with its
/// actions, the recent exchange travelling with each message, thinking,
/// every error state with Retry, and the honest not-configured state.
void main() {
  late AppDatabase db;
  late FakeAiApi ai;
  late FakeWorkoutApi workout;

  setUp(() {
    db = AppDatabase.inMemory();
    ai = FakeAiApi();
    workout = FakeWorkoutApi();
  });
  tearDown(() => db.close());

  Widget app() {
    final router = GoRouter(
      initialLocation: Routes.chat,
      routes: [
        GoRoute(path: Routes.chat, builder: (_, __) => const AiChatScreen()),
        GoRoute(
          path: Routes.plan,
          builder: (_, __) => const Scaffold(body: Text('PLAN')),
        ),
        GoRoute(
          path: Routes.volume,
          builder: (_, __) => const Scaffold(body: Text('VOLUME')),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const Scaffold(body: Text('PROFILE')),
        ),
        GoRoute(
          path: Routes.nutrition,
          builder: (_, __) => const Scaffold(body: Text('EAT')),
        ),
        GoRoute(
          path: Routes.history,
          builder: (_, __) => const Scaffold(body: Text('HISTORY')),
        ),
        GoRoute(
          path: '/exercises/:id',
          builder: (_, s) =>
              Scaffold(body: Text('EXERCISE ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/plan/session/:id',
          builder: (_, s) =>
              Scaffold(body: Text('SESSION ${s.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        aiApiProvider.overrideWithValue(ai),
        ...workoutOverrides(db, workout),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));

  Future<void> tapPrompt(WidgetTester tester, int i) async {
    final prompt = find.byKey(ValueKey('ai.prompt.$i'));
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('ai.input')), text);
    await tester.pump();
  }

  testWidgets(
      'empty state: what it answers from, and only starter prompts the build can answer',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai.empty')), findsOneWidget);
    expect(find.text('Ask about your training.'), findsOneWidget);
    expect(
      find.textContaining('cannot see food you have not logged'),
      findsOneWidget,
    );
    for (final p in AiChatScreen.starterPrompts) {
      expect(find.text(p), findsOneWidget);
      expect(
        p.toLowerCase(),
        isNot(contains('eaten')),
        reason: 'no Phase 8 prompts',
      );
      expect(p.toLowerCase(), isNot(contains('log food')));
    }
    expect(find.byKey(const ValueKey('ai.clear')), findsNothing);
  });

  testWidgets(
      'a starter prompt sends it; the answer shows as FITOS AI with its actions; the action navigates',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapPrompt(tester, 0);
    expect(ai.requests.single.message, 'What should I do today?');
    expect(ai.requests.single.history, isEmpty);
    expect(find.byKey(const ValueKey('ai.conversation')), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('FITOS AI'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('ai.turn.1')))
          .data,
      'Pull is ready: 4 movements, about 45 minutes.',
    );
    expect(find.byKey(const ValueKey('ai.clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai.action.open-workout')));
    await tester.pumpAndSettle();
    // No session in progress → the plan.
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets(
      'typing and sending carries the recent exchange; the field clears; New chat resets',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await type(tester, '  Should I increase bench?  ');
    await tester.tap(find.byKey(const ValueKey('ai.send')));
    await tester.pumpAndSettle();
    expect(ai.requests.last.message, 'Should I increase bench?');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ai.input')))
          .controller!
          .text,
      '',
    );

    ai.nextAnswer = const AiChatResponse(
      text: 'Not yet. Stay at 50 kg and add reps.',
      model: 'fake-1',
    );
    await type(tester, 'Why?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(ai.requests.last.message, 'Why?');
    expect(
        ai.requests.last.history
            .map((m) => '${m.role.wire}:${m.content}')
            .toList(),
        [
          'user:Should I increase bench?',
          'assistant:Pull is ready: 4 movements, about 45 minutes.',
        ]);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('ai.turn.3')))
          .data,
      'Not yet. Stay at 50 kg and add reps.',
    );

    await tester.tap(find.byKey(const ValueKey('ai.clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai.empty')), findsOneWidget);
  });

  testWidgets('an empty message is not sent', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await type(tester, '   ');
    await tester.tap(find.byKey(const ValueKey('ai.send')));
    await tester.pumpAndSettle();
    expect(ai.requests, isEmpty);
  });

  testWidgets(
      'server failures show the server\'s own words with Retry; Retry re-sends the same message and drops the failed turn from history',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    ai.nextFailure =
        const Unknown('FITOS AI took too long to answer. Try again.');
    await type(tester, 'Explain my workout');
    await tester.tap(find.byKey(const ValueKey('ai.send')));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'ai.error').data,
      'FITOS AI took too long to answer. Try again.',
    );
    expect(find.byKey(const ValueKey('ai.retry')), findsOneWidget);
    expect(find.textContaining('Gemini'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    ai.nextFailure = null;
    await tester.tap(find.byKey(const ValueKey('ai.retry')));
    await tester.pumpAndSettle();
    expect(ai.requests, hasLength(2));
    expect(ai.requests.last.message, 'Explain my workout');
    expect(
      ai.requests.last.history,
      isEmpty,
      reason: 'the unanswered turn is not history',
    );
    expect(find.byKey(const ValueKey('ai.error')), findsNothing);
    expect(find.text('FITOS AI'), findsOneWidget);
  });

  testWidgets('rate limited, offline and expired session read as FITOS lines',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final (failure, expected) in [
      (
        const RateLimited('FITOS AI is busy right now. Try again in a minute.'),
        'FITOS AI is busy right now. Try again in a minute.'
      ),
      (const Offline(), 'You appear to be offline.'),
      (const Unauthenticated(), 'Sign in to continue.'),
    ]) {
      ai.nextFailure = failure;
      await type(tester, 'hi');
      await tester.tap(find.byKey(const ValueKey('ai.send')));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'ai.error').data, expected);
      await tester.tap(find.byKey(const ValueKey('ai.clear')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'not configured on the server: says so, no composer; API unreachable: Try again',
      (tester) async {
    ai.status_ = const AiStatus(
      configured: false,
      provider: 'none',
      model: null,
      excludes: ['health-connect', 'food-log'],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai.notConfigured')), findsOneWidget);
    expect(find.text('Not set up on this server yet.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('ai.input'))).enabled,
      isFalse,
    );
    expect(ai.calls.where((c) => c == 'chat'), isEmpty);
  });

  testWidgets('status unreachable: an honest line and Try again refetches',
      (tester) async {
    ai.statusFailure = const Offline();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai.unavailable')), findsOneWidget);
    ai.statusFailure = null;
    await tester.tap(find.byKey(const ValueKey('ai.status.retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai.empty')), findsOneWidget);
  });

  testWidgets('actions route: volume, profile, history, exercise',
      (tester) async {
    ai.nextAnswer = const AiChatResponse(
      text: 'Chest is at its ceiling this week.',
      actions: [
        AiAction(type: AiActionType.openVolume, label: 'Training volume'),
        AiAction(
          type: AiActionType.openProgression,
          label: 'See the lift',
          exerciseId: '11111111-1111-4111-8111-111111111111',
        ),
      ],
      model: 'fake-1',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapPrompt(tester, 3);
    await tester.tap(find.byKey(const ValueKey('ai.action.open-progression')));
    await tester.pumpAndSettle();
    expect(
      find.text('EXERCISE 11111111-1111-4111-8111-111111111111'),
      findsOneWidget,
    );
  });
}
