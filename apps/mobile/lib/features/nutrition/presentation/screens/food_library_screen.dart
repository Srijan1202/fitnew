import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/food.dart';
import '../controllers/food_providers.dart';
import '../widgets/food_widgets.dart';

/// The Nutrition tab (Phase 7): a food library to look things up in. Search,
/// read what a food contains and where the numbers come from, add your own
/// from a label. Nothing here logs a meal or counts toward a target — that
/// is Phase 8, and a control that pretends otherwise is not shown (§6).
class FoodLibraryScreen extends ConsumerStatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  ConsumerState<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends ConsumerState<FoodLibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(foodQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(foodQueryProvider.notifier).set(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    ref.read(foodQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final query = ref.watch(foodQueryProvider);
    final async = ref.watch(foodSearchProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.lg,
                FitSpacing.sm,
                FitSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('NUTRITION', style: textTheme.labelSmall),
                        const SizedBox(height: FitSpacing.xs),
                        Text('Food library', style: textTheme.displaySmall),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('food.add'),
                    onPressed: () => context.push(Routes.foodNew),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a food'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.xs,
                FitSpacing.screen,
                FitSpacing.sm,
              ),
              child: AuthFormField(
                fieldKey: const ValueKey('food.search'),
                label: 'Search foods',
                controller: _search,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (v) {
                  _debounce?.cancel();
                  ref.read(foodQueryProvider.notifier).set(v);
                },
                onChanged: _onChanged,
              ),
            ),
            const Divider(color: FitColors.rule, height: 1),
            Expanded(
              child: query.isEmpty
                  ? const _Intro()
                  : async.when(
                      loading: () => const _ListSkeleton(),
                      error: (e, _) => _SearchFailed(
                        failure: e is Failure ? e : const Unknown(),
                        onRetry: () => ref.invalidate(foodSearchProvider),
                      ),
                      data: (items) => _Results(
                        query: query,
                        items: items ?? const <FoodSearchResult>[],
                        onClear: _clear,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before anything is typed: what the library is, how to search it, and
/// whose data it holds. No counts, no fake "recent foods".
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('food.intro'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.lg,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      children: <Widget>[
        Text(
          'Look up what a food contains.',
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Search by name — Indian spellings work too: dhal, roti, idly, '
          'sambhar. Measured values come from USDA; Indian dishes are FITOS '
          'estimates, shown as a range.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Not here? Add it from its label — only you will see it.',
          style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
        ),
        const SizedBox(height: FitSpacing.xl),
        const Divider(color: FitColors.rule, height: 1),
        const SizedBox(height: FitSpacing.afterRule),
        const UsdaAttribution(),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.items,
    required this.onClear,
  });

  final String query;
  final List<FoodSearchResult> items;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return ListView(
        key: const ValueKey('food.empty'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        children: <Widget>[
          Text('No food matches “$query”', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Check the spelling, try a shorter name, or add it from its label.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          Row(
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey('food.empty.add'),
                onPressed: () => context.push(Routes.foodNew),
                child: const Text('Add from a label'),
              ),
              const SizedBox(width: FitSpacing.sm),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
        ],
      );
    }
    return ListView.separated(
      key: const ValueKey('food.results'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(color: FitColors.rule, height: 1),
      itemBuilder: (context, i) => FoodRow(result: items[i]),
    );
  }
}

/// One result: name (wraps to two lines), "brand · energy · serving", the
/// source badge, an arrow. Tapping opens the food.
class FoodRow extends StatelessWidget {
  const FoodRow({required this.result, super.key});

  final FoodSearchResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final food = result.food;
    final row = food.headline;
    final detail = <String>[
      if (food.brand != null) food.brand!,
      FoodFormat.kcal(row),
      FoodFormat.servingShort(row),
    ].join(' · ');
    return InkWell(
      key: ValueKey('food.${food.slug}'),
      onTap: () => context.push(Routes.foodDetail(food.id), extra: food),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm + 2,
            FitSpacing.sm,
            FitSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      food.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FitSpacing.sm),
              FoodSourceBadge(food: food),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: FitColors.ink60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      itemCount: 6,
      separatorBuilder: (_, __) =>
          const Divider(color: FitColors.rule, height: 1),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.screen,
          vertical: FitSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 140 + (i % 3) * 40.0,
              height: 16,
              color: FitColors.paper2,
            ),
            const SizedBox(height: FitSpacing.sm),
            Container(width: 160, height: 12, color: FitColors.paper2),
          ],
        ),
      ),
    );
  }
}

class _SearchFailed extends StatelessWidget {
  const _SearchFailed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(FitSpacing.screen),
      children: <Widget>[
        Text('Could not search the library', style: textTheme.titleLarge),
        const SizedBox(height: FitSpacing.sm),
        AuthFeedback.error(failure.message),
        const SizedBox(height: FitSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey('food.retry'),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
