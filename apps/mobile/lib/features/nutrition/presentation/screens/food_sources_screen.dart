import 'package:flutter/material.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../widgets/food_widgets.dart';

/// One source of FITOS's food numbers: what it is, its citation, what FITOS
/// changed.
typedef FoodDataSource = ({
  String name,
  String what,
  String citation,
  String changed,
});

/// Beta 3.7 (ADR-036): every source FITOS's food numbers come from, cited.
const kFoodDataSources = <FoodDataSource>[
  (
    name: 'IFCT 2017 (NIN-ICMR)',
    what: 'Indian Food Composition Tables: raw Indian foods measured across '
        'six regions of India — grains, pulses, vegetables, fruit, milk, '
        'paneer, meat, fish and oils.',
    citation: 'Longvah T, Ananthan R, Bhaskarachary K, Venkaiah K (2017). '
        'Indian Food Composition Tables 2017. National Institute of '
        'Nutrition, Indian Council of Medical Research, Hyderabad.',
    changed: 'Per 100 g as published. The range is the variation IFCT '
        'reports between regions (3–10 %). Foods whose energy does not '
        'match their own protein, carbohydrate and fat are left out.',
  ),
  (
    name: 'Indian Nutrient Databank (INDB 2024)',
    what: 'Indian recipes, per piece or bowl as INDB serves them.',
    citation: 'Vijayakumar A, Jaacks LM et al. (2024). Development of an '
        'Indian Food Composition Database. Current Developments in '
        'Nutrition 8(7):103790.',
    changed: 'A range of ±10 %. Deep-fried recipes are left out: INDB '
        'counts all the oil in the pan, not what the food soaks up. So are '
        'recipes whose energy does not match their macros. Never marked '
        'verified.',
  ),
  (
    name: 'UK CoFID 2021',
    what: "McCance and Widdowson's Composition of Foods Integrated Dataset: "
        'foods measured as eaten, including Indian dishes cooked in the UK '
        'and plain milk and yogurt.',
    citation: 'Public Health England (2021). Crown copyright. Contains '
        'public sector information licensed under the Open Government '
        'Licence v3.0.',
    changed: 'Plain foods ±3 %, dishes ±8 %, at FITOS serving sizes. FITOS '
        'also uses it to check its own mess estimates.',
  ),
  (
    name: 'USDA FoodData Central',
    what: 'Measured foods (Foundation Foods and SR Legacy) and the '
        'ingredients FITOS builds its own recipe estimates from.',
    citation: UsdaAttribution.text,
    changed: 'Exact values as published. FITOS recipes add up USDA '
        'ingredients with a range for the oil and the portion.',
  ),
  (
    name: 'FITOS estimates',
    what: 'Dishes no source measures, such as the VIT mess dishes, worked '
        'out from their recipes.',
    citation: 'FITOS.',
    changed: 'At most ±20 % around the middle. Never marked verified.',
  ),
];

/// Profile → About → Food data sources.
class FoodSourcesScreen extends StatelessWidget {
  const FoodSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dim = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('FOOD DATA SOURCES', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: FitBackdrop(
        child: SafeArea(
          child: ListView(
            key: const ValueKey('foodSources.list'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.lg,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              Text(
                'FITOS shows one number for a food: the middle of its range. '
                'Tap a food or a logged item to see the range and where it '
                'comes from.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.lg),
              for (final s in kFoodDataSources) ...<Widget>[
                HairlineSection(
                  label: s.name,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.what, style: textTheme.bodyLarge),
                      const SizedBox(height: FitSpacing.xs),
                      Text(s.citation, style: dim),
                      const SizedBox(height: FitSpacing.xs),
                      Text('What FITOS changed: ${s.changed}', style: dim),
                    ],
                  ),
                ),
                const SizedBox(height: FitSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
