import 'dart:convert';
import 'dart:io';

import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/domain/portion_preview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner J10: the Dart preview is DISPLAY-ONLY, but it must say exactly what
/// the server will store — so it is checked against the same fixture
/// packages/core's `snapshotNutrition` / `resolvePortion` are checked against.
void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    final file = File('../../packages/core/test/fixtures/portion-preview.json');
    expect(file.existsSync(), isTrue);
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  FoodNutrition rowOf(
    Map<String, dynamic> r, {
    String basis = 'per_serving',
    double? grams = 150,
  }) =>
      FoodNutrition(
        basis: NutritionBasis.values.firstWhere((b) => b.wire == basis),
        servingLabel: basis == 'per_100g' ? '100 g' : '1 katori',
        servingGrams: basis == 'per_100g' ? 100 : grams,
        kcalLow: (r['kcalLow'] as num).toDouble(),
        kcalHigh: (r['kcalHigh'] as num).toDouble(),
        proteinLow: (r['proteinLow'] as num).toDouble(),
        proteinHigh: (r['proteinHigh'] as num).toDouble(),
        carbLow: (r['carbLow'] as num).toDouble(),
        carbHigh: (r['carbHigh'] as num).toDouble(),
        fatLow: (r['fatLow'] as num).toDouble(),
        fatHigh: (r['fatHigh'] as num).toDouble(),
        fibreLow: (r['fibreLow'] as num?)?.toDouble(),
        fibreHigh: (r['fibreHigh'] as num?)?.toDouble(),
        confidence: NutritionConfidence.medium,
      );

  test('every snapshot in the shared fixture is reproduced exactly', () {
    for (final c in fixture['snapshots'] as List<dynamic>) {
      final m = c as Map<String, dynamic>;
      final got = PortionPreview.scale(
        rowOf(m['row'] as Map<String, dynamic>),
        (m['servings'] as num).toDouble(),
      ).toMap();
      final want = (m['expected'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num?)?.toDouble()));
      expect(got, want, reason: m['name'] as String);
    }
  });

  test('every portion in the shared fixture resolves the same way', () {
    const zero = <String, dynamic>{
      'kcalLow': 0, 'kcalHigh': 0, 'proteinLow': 0, 'proteinHigh': 0, //
      'carbLow': 0, 'carbHigh': 0, 'fatLow': 0, 'fatHigh': 0,
      'fibreLow': null, 'fibreHigh': null,
    };
    for (final c in fixture['portions'] as List<dynamic>) {
      final m = c as Map<String, dynamic>;
      final row = m['row'] as Map<String, dynamic>;
      final input = m['input'] as Map<String, dynamic>;
      final expected = m['expected'] as Map<String, dynamic>;
      final r = rowOf(
        zero,
        basis: row['basis'] as String,
        grams: (row['servingGrams'] as num?)?.toDouble(),
      );
      final got = PortionPreview.resolve(
        r,
        servings: (input['servings'] as num?)?.toDouble(),
        grams: (input['grams'] as num?)?.toDouble(),
      );
      expect(got.ok, expected['ok'], reason: jsonEncode(m));
      if (got.ok) {
        expect(
          got.servings,
          (expected['servings'] as num).toDouble(),
          reason: jsonEncode(m),
        );
        expect(
          got.grams,
          (expected['grams'] as num?)?.toDouble(),
          reason: jsonEncode(m),
        );
      }
    }
  });

  test('a quick add previews its own numbers; unknown fibre stays unknown', () {
    final p = PortionPreview.quickAdd(
      const QuickAdd(kcal: 250.4, proteinG: 12.34, carbG: 30, fatG: 9),
    );
    expect(p.kcalLow, 250);
    expect(p.kcalHigh, 250);
    expect(p.proteinLow, 12.3);
    expect(p.fibreLow, isNull);
  });

  test(
      'a saved meal previews as the sum; a missing food means no preview at all',
      () {
    final dal = rowOf(
      (fixture['snapshots'] as List<dynamic>).first['row']
          as Map<String, dynamic>,
    );
    final meal = SavedMeal(
      id: 'm',
      clientMealId: 'c',
      name: 'Dinner',
      createdAt: '2026-09-24T12:00:00.000Z',
      items: [
        SavedFoodItem(
          foodId: 'f',
          foodName: 'Dal',
          basis: NutritionBasis.perServing,
          servingLabel: '1 katori',
          servings: 1.5,
          grams: 225,
          row: dal,
        ),
        const SavedQuickAddItem(
          quickAddName: 'Curd',
          kcal: 60,
          proteinG: 3,
          carbG: 4,
          fatG: 3,
          fibreG: null,
        ),
      ],
    );
    final p = PortionPreview.savedMeal(meal)!;
    expect([p.kcalLow, p.kcalHigh], [240, 338]);
    expect(p.fibreLow, isNull);
    const gone = SavedMeal(
      id: 'm',
      clientMealId: 'c',
      name: 'Dinner',
      createdAt: '2026-09-24T12:00:00.000Z',
      items: [
        SavedFoodItem(
          foodId: 'f',
          foodName: 'Dal',
          basis: NutritionBasis.perServing,
          servingLabel: '1 katori',
          servings: 1,
          grams: null,
          row: null,
        ),
      ],
    );
    expect(PortionPreview.savedMeal(gone), isNull);
  });
}
