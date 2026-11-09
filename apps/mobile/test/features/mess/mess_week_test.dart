import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/mess/data/mess_week_api.dart';
import 'package:fitos/features/mess/presentation/mess_week_screen.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _m(int k, int p) => {
      'kcalLow': k,
      'kcalHigh': k + 50,
      'proteinLow': p,
      'proteinHigh': p + 4,
      'carbLow': 40,
      'carbHigh': 50,
      'fatLow': 8,
      'fatHigh': 12,
    };

Map<String, dynamic> _plate(String dish) => {
      'rank': 1,
      'items': [
        {
          'dishSlug': dish.toLowerCase().replaceAll(' ', '-'),
          'name': dish,
          'servings': 2,
          'servingLabel': '1 katori',
          'servingGrams': 150,
          ..._m(300, 14),
          'confidence': 'medium',
          'component': 'protein',
        },
      ],
      'totals': _m(300, 14),
      'confidence': 'medium',
      'structure': {'kind': 'complete', 'missing': <String>[]},
      'reasons': <Object>[],
    };

MessWeekPlan _plan() => MessWeekPlan.fromJson({
      'mess': {
        'code': 'mens-veg',
        'providerSlug': 'vit-vellore',
        'hostelId': 'mens',
        'hostelLabel': "Men's hostel",
        'messId': 'veg',
        'messLabel': 'Veg mess',
        'servesNonVeg': false,
        'freshness': {
          'lastSuccessAt': null,
          'lastAttemptAt': null,
          'lastError': null,
          'stale': false,
          'latestPublishedDate': null,
        },
      },
      'today': '2026-11-10',
      'filters': {'diet': 'vegetarian', 'allergies': <String>[]},
      'goal': 'general',
      'hasTargets': true,
      'days': [
        {
          'date': '2026-11-10',
          'basis': 'published',
          'meals': [
            {'slot': 'lunch', 'status': 'ok', 'plate': _plate('Paneer Curry')},
            {'slot': 'dinner', 'status': 'nothing-safe', 'plate': null},
          ],
          'totals': _m(300, 14),
        },
        {
          'date': '2026-11-11',
          'basis': 'inferred',
          'meals': [
            {'slot': 'lunch', 'status': 'ok', 'plate': _plate('Rajma')},
          ],
          'totals': _m(300, 14),
        },
        for (final d in ['12', '13', '14', '15', '16'])
          {
            'date': '2026-11-$d',
            'basis': null,
            'meals': <Object>[],
            'totals': _m(0, 0),
          },
      ],
    });

class _Api implements MessWeekApi {
  int calls = 0;
  @override
  Future<Result<MessWeekPlan>> week() async {
    calls += 1;
    return Ok(_plan());
  }
}

/// Beta 6.1 (premium): a week of mess meals, planned by FITOS.
void main() {
  Widget app(bool? premium, _Api api) => ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('u1'),
          isPremiumProvider.overrideWithValue(premium),
          messWeekApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const MessWeekScreen(),
        ),
      );

  testWidgets('a free account sees what Premium is, and nothing is asked',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(app(false, api));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week.premium')), findsOneWidget);
    expect(api.calls, 0);
  });

  testWidgets(
      'today: each meal\'s plate with Log this; a meal without one says why; later days are for planning',
      (tester) async {
    await tester.pumpWidget(app(true, _Api()));
    await tester.pumpAndSettle();
    expect(find.text('Paneer Curry · 2 × 1 katori'), findsOneWidget);
    expect(find.byKey(const ValueKey('week.log.lunch')), findsOneWidget);
    expect(
      find.text('Nothing at this meal suits your diet and allergies.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('week.log.dinner')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('week.day.1')));
    await tester.pumpAndSettle();
    expect(find.text('Rajma · 2 × 1 katori'), findsOneWidget);
    expect(find.byKey(const ValueKey('week.inferred')), findsOneWidget);
    expect(find.byKey(const ValueKey('week.log.lunch')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('week.day.2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week.noMenu')), findsOneWidget);
  });
}
