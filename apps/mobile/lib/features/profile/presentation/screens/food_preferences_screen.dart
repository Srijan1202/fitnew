import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../mess/presentation/mess_providers.dart';
import '../../../onboarding/presentation/screens/steps/food_step.dart'
    show AllergyRow;
import '../../../onboarding/presentation/widgets/onboarding_step.dart'
    show ChoiceList;
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/vocabulary.dart';

/// The diet and allergies every food suggestion obeys (`GET
/// /user/diet-preferences`), for the Profile row and the editor.
final dietPreferencesProvider = FutureProvider.autoDispose<DietPreferences>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(profileRepositoryProvider).getDiet();
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// "Vegetarian · peanut (severe), milk (mild)".
String foodSummary(DietPreferences d) {
  if (d.allergies.isEmpty) return '${d.dietType.label} · no allergies';
  final a = d.allergies
      .map(
        (x) =>
            '${x.allergen.label.toLowerCase()} (${x.severity.label.toLowerCase()})',
      )
      .join(', ');
  return '${d.dietType.label} · $a';
}

/// Profile: "Food — Vegetarian · peanut (severe)   Edit".
class FoodSettingRow extends ConsumerWidget {
  const FoodSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final diet = ref.watch(dietPreferencesProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text('Food', style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              switch (diet) {
                AsyncData(:final value) => foodSummary(value),
                AsyncError() => 'Not set',
                _ => '…',
              },
              key: const ValueKey('profile.food'),
              style: textTheme.bodyLarge,
            ),
          ),
          TextButton(
            key: const ValueKey('profile.food.edit'),
            onPressed: () => context.push(Routes.profileFood),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

/// Profile → Food: diet type and allergies (Phase 10, owner D17). These are
/// hard rules for every suggestion: an allergy excludes every dish not
/// confirmed free of it, whatever its severity.
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() =>
      _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  DietType? _diet;
  Map<Allergen, AllergySeverity> _allergies = {};
  bool _loaded = false;
  bool _busy = false;
  Failure? _failure;

  void _seed(DietPreferences d) {
    if (_loaded) return;
    _loaded = true;
    _diet = d.dietType;
    _allergies = {for (final a in d.allergies) a.allergen: a.severity};
  }

  Future<void> _save() async {
    final diet = _diet;
    if (diet == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(profileRepositoryProvider).putDiet(
      diet,
      [
        for (final a in Allergen.values)
          if (_allergies.containsKey(a))
            Allergy(allergen: a, severity: _allergies[a]!),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
          ..invalidate(dietPreferencesProvider)
          ..invalidate(messRecommendProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. Suggestions now follow it.')),
        );
        context.popOrHome();
      case Err(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loaded = ref.watch(dietPreferencesProvider);
    if (loaded case AsyncData(:final value)) _seed(value);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Food'),
      ),
      body: SafeArea(
        top: false,
        child: switch (loaded) {
          AsyncError(:final error) when !_loaded => Padding(
              padding: const EdgeInsets.all(FitSpacing.screen),
              child: AuthFeedback.error(
                error is Failure ? error.message : 'Could not load.',
              ),
            ),
          AsyncLoading() when !_loaded => const Center(child: Text('Loading…')),
          _ => ListView(
              key: const ValueKey('food.list'),
              padding: const EdgeInsets.all(FitSpacing.screen),
              children: <Widget>[
                Text(
                  'Diet type and allergies are hard rules for every food suggestion. '
                  'An allergy keeps off every dish FITOS cannot confirm is free of it — whatever its severity.',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                const SizedBox(height: FitSpacing.lg),
                Text('DIET', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.xs),
                ChoiceList<DietType>(
                  options: DietType.values,
                  selected: _diet,
                  enabled: !_busy,
                  onSelect: (d) => setState(() => _diet = d),
                  label: (d) => d.label,
                ),
                const SizedBox(height: FitSpacing.lg),
                Text('ALLERGIES', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.xs),
                for (final a in Allergen.values) ...<Widget>[
                  AllergyRow(
                    allergen: a,
                    severity: _allergies[a],
                    enabled: !_busy,
                    onToggle: () => setState(() {
                      if (_allergies.remove(a) == null) {
                        _allergies[a] = AllergySeverity.moderate;
                      }
                    }),
                    onSeverity: (s) => setState(() => _allergies[a] = s),
                  ),
                  const Divider(color: FitColors.rule, height: 1),
                ],
                const SizedBox(height: FitSpacing.md),
                Text(
                  'Shared mess kitchens can have cross-contact that FITOS cannot rule out.',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                if (_failure != null) ...<Widget>[
                  const SizedBox(height: FitSpacing.sm),
                  AuthFeedback.error(
                    _failure is Offline
                        ? 'Saving needs a connection.'
                        : _failure!.message,
                  ),
                ],
                const SizedBox(height: FitSpacing.lg),
                FilledButton(
                  key: const ValueKey('food.save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy || _diet == null ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save'),
                ),
              ],
            ),
        },
      ),
    );
  }
}
