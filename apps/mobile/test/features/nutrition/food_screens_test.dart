import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/nutrition/presentation/screens/custom_food_screen.dart';
import 'package:fitos/features/nutrition/presentation/screens/food_detail_screen.dart';
import 'package:fitos/features/nutrition/presentation/screens/food_library_screen.dart';
import 'package:fitos/features/nutrition/presentation/widgets/food_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_food_repository.dart';

/// Phase 7 food library against a scripted server: search, results with
/// their provenance, a detail that keeps ranges as ranges and unknown fibre
/// unknown, USDA attribution, and a retry-safe custom-food form. Phase 8
/// adds "Log this food" on the detail ("Log it now" after creating one); the
/// library's search and intro still never pretend to log.
void main() {
  late FakeFoodRepository repo;

  setUp(() => repo = FakeFoodRepository());

  Widget harness({String initial = '/nutrition', Object? extra}) {
    final router = GoRouter(
      initialLocation: initial,
      initialExtra: extra,
      routes: [
        GoRoute(
          path: '/nutrition',
          builder: (_, __) => const FoodLibraryScreen(),
          routes: [
            GoRoute(
              path: 'foods/new',
              builder: (_, __) => const CustomFoodScreen(),
            ),
            GoRoute(
              path: 'foods/:id',
              builder: (_, s) => FoodDetailScreen(
                food: switch (s.extra) {
                  final FoodDetailArgs a => a.food,
                  final Food f => f,
                  _ => null,
                },
                justCreated: s.extra is FoodDetailArgs &&
                    (s.extra! as FoodDetailArgs).justCreated,
              ),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  /// Tall enough that the whole form and every detail section is built.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  Future<void> type(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const ValueKey('food.search')), q);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  /// Nothing in Phase 7 may pretend to log food or count it toward a target.
  final loggingWords = RegExp(
    r'\blog(ged|ging)?\b|add to (meal|diary|today|breakfast|lunch|dinner)|\btrack\b|eaten',
    caseSensitive: false,
  );

  void expectNoLoggingControls(WidgetTester tester) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
    for (final text in texts) {
      expect(loggingWords.hasMatch(text), isFalse, reason: text);
    }
  }

  group('library', () {
    testWidgets(
        'before typing: what it is, how to search, USDA credited — and no request',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Food library'), findsOneWidget);
      expect(find.byKey(const ValueKey('food.intro')), findsOneWidget);
      expect(find.textContaining('dhal, roti, idly'), findsOneWidget);
      expect(find.byKey(const ValueKey('usda.attribution')), findsOneWidget);
      expect(find.textContaining('USDA FoodData Central'), findsOneWidget);
      expect(repo.queries, isEmpty);
      expectNoLoggingControls(tester);
    });

    testWidgets('typing asks the server once and shows its answer in order',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await type(tester, '  dhal ');

      expect(repo.queries, ['dhal']);
      final names = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('food.results')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(names.indexOf('Dal tadka'), lessThan(names.indexOf('Honey')));
      // An estimate's row shows its range and serving; a USDA row its
      // first USDA portion. Each carries its source.
      expect(find.text('120–185 kcal · 1 katori'), findsOneWidget);
      expect(find.text('64 kcal · 1 tbsp'), findsOneWidget);
      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(find.text('USDA'), findsOneWidget);
      expectNoLoggingControls(tester);
    });

    testWidgets('a custom food row shows its brand and says it is yours',
        (tester) async {
      repo.results = const [
        FoodSearchResult(food: lassi, match: FoodMatchKind.exact),
      ];
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await type(tester, 'lassi');
      expect(
        find.text('Amul · 160 kcal · 1 bottle (200 ml)'),
        findsOneWidget,
      );
      expect(find.text('YOURS'), findsOneWidget);
    });

    testWidgets('nothing found: says so and offers to add it from a label',
        (tester) async {
      repo.results = const [];
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await type(tester, 'xqzv');

      expect(find.text('No food matches “xqzv”'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('food.empty.add')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomFoodScreen), findsOneWidget);
    });

    testWidgets('a failed search is shown with Try again, which asks again',
        (tester) async {
      repo.searchFailure = const Offline();
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await type(tester, 'rice');

      expect(find.text('Could not search the library'), findsOneWidget);
      expect(find.text('You appear to be offline.'), findsOneWidget);
      repo.searchFailure = null;
      await tester.tap(find.byKey(const ValueKey('food.retry')));
      await tester.pumpAndSettle();
      expect(repo.queries, ['rice', 'rice']);
      expect(find.text('Dal tadka'), findsOneWidget);
    });

    testWidgets('tapping a result opens it', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await type(tester, 'dal');
      await tester.tap(find.byKey(const ValueKey('food.dal-tadka')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('food.detail')), findsOneWidget);
      expect(find.text('Dal tadka'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets(
        'an estimate: ranges stay ranges, fibre is "Not known", never 0, and it says it is an estimate',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
        harness(initial: '/nutrition/foods/${dalTadka.id}', extra: dalTadka),
      );
      await tester.pumpAndSettle();

      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(find.text('Medium confidence'), findsOneWidget);
      expect(find.textContaining('shown as a range'), findsOneWidget);
      expect(find.text('PER 1 KATORI (150 G)'), findsOneWidget);
      expect(find.text('120–185 kcal'), findsOneWidget);
      expect(find.text('6–9 g'), findsOneWidget);
      expect(find.text('16–23 g'), findsOneWidget);
      expect(find.text('3–7.5 g'), findsOneWidget);
      expect(find.byKey(const ValueKey('fibre.unknown')), findsOneWidget);
      expect(find.text('Not known'), findsOneWidget);
      expect(find.text('0 g'), findsNothing);
      expect(find.text('dal, dhal, daal'), findsOneWidget);
      expect(find.textContaining('core estimate table'), findsOneWidget);
      // Not USDA data: no USDA credit on this one.
      expect(find.byKey(const ValueKey('usda.attribution')), findsNothing);
      expect(find.text('Verified · Medium confidence'), findsNothing);
      // Phase 8: a food can be logged from its detail.
      expect(find.text('Log this food'), findsOneWidget);
    });

    testWidgets(
        'a USDA record: verified, exact values, its FDC record and the attribution',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
        harness(initial: '/nutrition/foods/${honey.id}', extra: honey),
      );
      await tester.pumpAndSettle();

      expect(find.text('USDA'), findsOneWidget);
      expect(find.text('Verified · High confidence'), findsOneWidget);
      expect(find.textContaining('Measured values'), findsOneWidget);
      expect(find.text('PER 100 G'), findsOneWidget);
      expect(find.text('PER 1 TBSP (21 G)'), findsOneWidget);
      expect(find.text('304 kcal'), findsOneWidget);
      expect(find.text('82.4 g'), findsOneWidget);
      // USDA reports fibre here, so it is shown — a reported 0 is a real 0.
      expect(find.text('0.2 g'), findsOneWidget);
      expect(find.byKey(const ValueKey('fibre.unknown')), findsNothing);
      expect(find.textContaining('FDC 169640'), findsOneWidget);
      expect(find.byKey(const ValueKey('usda.attribution')), findsOneWidget);
      expect(find.text('Log this food'), findsOneWidget);
    });

    testWidgets('an estimate composed from USDA ingredients credits USDA too',
        (tester) async {
      tall(tester);
      final composite = dalTadka.copyWith(
        sourceRef:
            'FITOS estimate · composed from USDA ingredients · recipe rajma v1',
      );
      await tester.pumpWidget(
        harness(initial: '/nutrition/foods/x', extra: composite),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('usda.attribution')), findsOneWidget);
      expect(find.text('ESTIMATE'), findsOneWidget);
    });

    testWidgets('your own food says it is yours and unverified',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
        harness(initial: '/nutrition/foods/${lassi.id}', extra: lassi),
      );
      await tester.pumpAndSettle();
      expect(find.text('YOURS'), findsOneWidget);
      expect(find.textContaining('FITOS has not verified it'), findsOneWidget);
      expect(find.text('Amul'), findsOneWidget);
      expect(find.text('PER 1 BOTTLE (200 ML)'), findsOneWidget);
      expect(find.text('Not known'), findsOneWidget);
    });

    testWidgets('opened without its food (a restored route): no guessing',
        (tester) async {
      await tester.pumpWidget(harness(initial: '/nutrition/foods/abc'));
      await tester.pumpAndSettle();
      expect(find.text('Open this food from the library'), findsOneWidget);
    });
  });

  group('custom food', () {
    Future<void> fill(WidgetTester tester, Map<String, String> values) async {
      for (final e in values.entries) {
        await tester.enterText(
          find.byKey(ValueKey('food.form.${e.key}')),
          e.value,
        );
      }
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('food.form.save')));
      await tester.pumpAndSettle();
    }

    const label = <String, String>{
      'name': 'Protein Lassi',
      'brand': 'Amul',
      'servingLabel': '1 bottle (200 ml)',
      'servingGrams': '200',
      'kcal': '160',
      'protein': '15',
      'carb': '20',
      'fat': '2',
    };

    testWidgets('required fields are asked for; nothing is sent',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition/foods/new'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Required.'), findsWidgets);
      expect(find.text('Enter the label value.'), findsWidgets);
      expect(repo.created, isEmpty);
    });

    testWidgets(
        'saves the label as typed — no fibre means null, not 0 — and opens the new food',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition/foods/new'));
      await tester.pumpAndSettle();
      await fill(tester, label);
      await save(tester);

      final sent = repo.created.single;
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(sent.clientFoodId),
        isTrue,
      );
      expect(sent.toJson(), <String, dynamic>{
        'clientFoodId': sent.clientFoodId,
        'name': 'Protein Lassi',
        'brand': 'Amul',
        'basis': 'per_serving',
        'servingLabel': '1 bottle (200 ml)',
        'servingGrams': 200.0,
        'kcal': 160.0,
        'proteinG': 15.0,
        'carbG': 20.0,
        'fatG': 2.0,
        'fibreG': null,
      });
      expect(find.byType(FoodDetailScreen), findsOneWidget);
      expect(find.text('Protein Lassi'), findsOneWidget);
      expect(find.text('YOURS'), findsOneWidget);
      // Phase 8 (owner item 27): straight from saving, "Log it now".
      expect(find.text('Saved to your foods.'), findsOneWidget);
      expect(find.text('Log it now'), findsOneWidget);
    });

    testWidgets(
        'a failed save keeps the form and resends the SAME clientFoodId',
        (tester) async {
      tall(tester);
      repo.createResults.add(const Err(Offline()));
      await tester.pumpWidget(harness(initial: '/nutrition/foods/new'));
      await tester.pumpAndSettle();
      await fill(tester, {...label, 'fibre': '0'});
      await save(tester);

      expect(find.text('You appear to be offline.'), findsOneWidget);
      expect(find.byType(CustomFoodScreen), findsOneWidget);
      await save(tester);

      expect(repo.created, hasLength(2));
      expect(repo.created[1].clientFoodId, repo.created[0].clientFoodId);
      // A stated 0 g of fibre is sent as 0 — it is known.
      expect(repo.created[0].fibreG, 0);
      expect(find.byType(FoodDetailScreen), findsOneWidget);
    });

    testWidgets(
        'per 100 g: no serving asked, impossible labels caught before sending',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition/foods/new'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('food.form.basis.Per 100 g')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('food.form.servingLabel')),
        findsNothing,
      );

      await fill(tester, {
        'name': 'Ghee label',
        'kcal': '950',
        'protein': '0',
        'carb': '0',
        'fat': '99',
      });
      await save(tester);
      expect(
        find.text('No food has more than 900 kcal per 100 g.'),
        findsOneWidget,
      );
      expect(repo.created, isEmpty);

      await fill(tester, {'kcal': '897'});
      await save(tester);
      final sent = repo.created.single.toJson();
      expect(sent['basis'], 'per_100g');
      expect(sent.containsKey('servingLabel'), isFalse);
      expect(sent['servingGrams'], isNull);
    });

    testWidgets('macros heavier than the serving are caught', (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition/foods/new'));
      await tester.pumpAndSettle();
      await fill(tester, {...label, 'servingGrams': '30'});
      await save(tester);
      expect(
        find.text('Protein, carbohydrate and fat weigh more than the serving.'),
        findsOneWidget,
      );
      expect(repo.created, isEmpty);
    });
  });

  group('formatting', () {
    test('exact values are one number, estimates a range, one decimal at most',
        () {
      expect(FoodFormat.range(130, 130), '130');
      expect(FoodFormat.range(120, 185), '120–185');
      expect(FoodFormat.range(2.5, 2.5), '2.5');
      expect(FoodFormat.number(0.45), '0.5');
      expect(FoodFormat.number(3.0), '3');
      expect(FoodFormat.serving(honey.nutrition[0]), 'Per 100 g');
      expect(FoodFormat.serving(honey.nutrition[1]), 'Per 1 tbsp (21 g)');
      expect(FoodFormat.serving(lassi.nutrition[0]), 'Per 1 bottle (200 ml)');
    });

    test('the headline row is the first serving, else per 100 g', () {
      expect(honey.headline.servingLabel, '1 tbsp');
      final only100 = honey.copyWith(nutrition: [honey.nutrition[0]]);
      expect(only100.headline.servingLabel, '100 g');
    });
  });
}
