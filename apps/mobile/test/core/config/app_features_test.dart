import 'dart:io';

import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/config/app_features.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/nutrition/presentation/widgets/ask_to_add_food.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_feedback_api.dart';
import '../../support/fake_food_repository.dart';

/// Beta 3.3 (ADR-033): the admin's feature switches. The app's list is the
/// server's; a switch is on until the server says off (and while unknown);
/// coming back to the app re-reads them at most every 5 minutes; a feature
/// that is off is hidden and sends nothing.
void main() {
  test('the app knows exactly the switches the server defines', () {
    final source =
        File('../../packages/contracts/src/admin.ts').readAsStringSync();
    final start = source.indexOf('export const APP_FEATURES = {');
    final block = source.substring(start, source.indexOf('} as const;', start));
    final keys = RegExp(r"^\s+'?([a-z][a-z0-9-]*)'?: \{", multiLine: true)
        .allMatches(block)
        .map((m) => m.group(1))
        .toList();
    expect(keys, AppFeature.values.map((f) => f.key).toList());
  });

  group('featureOnProvider', () {
    Future<ProviderContainer> container(FakeMetaApi meta) async {
      final c = ProviderContainer(
        overrides: [metaApiProvider.overrideWithValue(meta)],
      );
      addTearDown(c.dispose);
      await c.read(appConfigProvider.future);
      return c;
    }

    test('on unless the server says off; offline is on', () async {
      final c = await container(FakeMetaApi(flags: {'streaks': false}));
      expect(c.read(featureOnProvider(AppFeature.streaks)), isFalse);
      expect(c.read(featureOnProvider(AppFeature.messRatings)), isTrue);
      final offline = await container(FakeMetaApi()..offline = true);
      expect(offline.read(featureOnProvider(AppFeature.streaks)), isTrue);
    });

    test('a re-read picks up a switch turned off meanwhile', () async {
      final meta = FakeMetaApi();
      final c = await container(meta);
      expect(c.read(featureOnProvider(AppFeature.weeklyReport)), isTrue);
      meta.flags = {'weekly-report': false};
      c.invalidate(appConfigProvider);
      await c.read(appConfigProvider.future);
      expect(c.read(featureOnProvider(AppFeature.weeklyReport)), isFalse);
    });
  });

  testWidgets('coming back re-reads the switches at most every 5 minutes',
      (tester) async {
    var now = DateTime(2026, 10, 24, 9);
    var refreshes = 0;
    final c = ConfigRefreshCoordinator(() => refreshes++, now: () => now);
    addTearDown(c.dispose);
    now = now.add(const Duration(minutes: 4));
    c.resumed();
    expect(refreshes, 0);
    now = now.add(const Duration(minutes: 2));
    c.resumed();
    expect(refreshes, 1);
    now = now.add(const Duration(minutes: 1));
    c.resumed();
    expect(refreshes, 1);
  });

  group('food requests switched off', () {
    late FakeFoodRepository repo;

    setUp(() => repo = FakeFoodRepository());

    Widget host(Map<String, bool> flags) => ProviderScope(
          overrides: [
            metaApiProvider.overrideWithValue(FakeMetaApi(flags: flags)),
            foodRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AskToAddFood(query: 'kombucha')),
          ),
        );

    testWidgets('"Ask us to add" is hidden, and shows again when on',
        (tester) async {
      await tester.pumpWidget(host({'food-requests': false}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('food.ask')), findsNothing);
      await tester.pumpWidget(Container());
      await tester.pumpWidget(host({}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('food.ask')), findsOneWidget);
    });

    test('a search that finds nothing is not reported', () async {
      final c = ProviderContainer(
        overrides: [
          metaApiProvider
              .overrideWithValue(FakeMetaApi(flags: {'food-requests': false})),
          foodRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      await c.read(appConfigProvider.future);
      c.read(missingFoodReporterProvider).foundNothing('kombucha');
      expect(repo.missing, isEmpty);

      final on = MissingFoodReporter(repo);
      on.foundNothing('kombucha');
      await Future<void>.delayed(Duration.zero);
      expect(repo.missing, [('kombucha', false)]);
    });
  });
}
