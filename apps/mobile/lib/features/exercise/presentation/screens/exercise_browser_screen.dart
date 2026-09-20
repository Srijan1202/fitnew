import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_providers.dart';
import '../widgets/filter_rail.dart';

/// Exercise browser (§31 Phase 3). Search, then three rails: the equipment
/// you have, a muscle, a pattern. Every change is a request; the list is
/// whatever the server says is performable.
class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  const ExerciseBrowserScreen({this.pickMode = false, super.key});

  /// When true, tapping a row returns it to the caller (`context.pop(item)`)
  /// instead of opening its detail — the programme editors use this.
  final bool pickMode;

  @override
  ConsumerState<ExerciseBrowserScreen> createState() =>
      _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState extends ConsumerState<ExerciseBrowserScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(exerciseFiltersProvider).q;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(exerciseFiltersProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filters = ref.watch(exerciseFiltersProvider);
    final notifier = ref.read(exerciseFiltersProvider.notifier);
    final async = ref.watch(exerciseListProvider);

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.pickMode ? 'ADD TO YOUR DAY' : 'LIBRARY',
                    style: textTheme.labelSmall,
                  ),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    widget.pickMode ? 'Pick an exercise' : 'Exercises',
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: FitSpacing.md),
                  AuthFormField(
                    fieldKey: const ValueKey('exercises.search'),
                    label: 'Search',
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => notifier.setSearch(_search.text),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: FitSpacing.md),
                  Text('I HAVE', style: textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.xs),
            FilterRail<Equipment>(
              railKey: 'equipment',
              options: Equipment.values,
              isSelected: filters.equipment.contains,
              onTap: notifier.toggleEquipment,
              label: (e) => e.label,
            ),
            const SizedBox(height: FitSpacing.sm),
            FilterRail<MuscleGroup>(
              railKey: 'muscle',
              options: MuscleGroup.values,
              isSelected: (m) => filters.muscle == m,
              onTap: (m) => notifier.setMuscle(filters.muscle == m ? null : m),
              label: (m) => m.label,
            ),
            const SizedBox(height: FitSpacing.sm),
            FilterRail<MovementPattern>(
              railKey: 'pattern',
              options: MovementPattern.values,
              isSelected: (p) => filters.pattern == p,
              onTap: (p) =>
                  notifier.setPattern(filters.pattern == p ? null : p),
              label: (p) => p.label,
            ),
            const SizedBox(height: FitSpacing.md),
            const Divider(color: FitColors.rule, height: 1),
            Expanded(
              child: async.when(
                loading: () => const _ListSkeleton(),
                error: (e, _) => _ListFailed(
                  failure: e is Failure ? e : const Unknown(),
                  onRetry: () => ref.invalidate(exerciseListProvider),
                ),
                data: (page) => _ExerciseList(
                  page: page,
                  pickMode: widget.pickMode,
                  hasFilters: filters.hasFilters,
                  onClear: () {
                    _search.clear();
                    notifier.clear();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.page,
    required this.pickMode,
    required this.hasFilters,
    required this.onClear,
  });

  final ExerciseListResponse page;
  final bool pickMode;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (page.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Nothing matches', style: textTheme.titleLarge),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Nothing in the library can be done with exactly that. Try fewer filters.',
              style: textTheme.bodyMedium,
            ),
            if (hasFilters) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }
    final shown = page.items.length;
    return ListView.separated(
      key: const ValueKey('exercises.list'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
      itemCount: shown + 1,
      separatorBuilder: (_, __) =>
          const Divider(color: FitColors.rule, height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.sm,
            ),
            child: Text(
              shown == page.total
                  ? '${page.total} exercises'
                  : '$shown of ${page.total} exercises',
              style: textTheme.labelSmall,
            ),
          );
        }
        final item = page.items[index - 1];
        return _ExerciseRow(item: item, pickMode: pickMode);
      },
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.item, required this.pickMode});

  final ExerciseSummary item;
  final bool pickMode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muscles = item.primaryMuscles.map((m) => m.label).join(', ');
    final kit = item.equipment.map((e) => e.label).join(' + ');
    return InkWell(
      key: ValueKey('exercise.${item.slug}'),
      onTap: () => pickMode
          ? context.pop(item)
          : context.push(Routes.exerciseDetail(item.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.screen,
          vertical: FitSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.name, style: textTheme.titleLarge),
            const SizedBox(height: FitSpacing.xs),
            Text(
              '$muscles · ${item.movementPattern.label} · $kit',
              style: textTheme.bodyMedium,
            ),
          ],
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
      itemCount: 8,
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
              height: 18,
              color: FitColors.paper2,
            ),
            const SizedBox(height: FitSpacing.sm),
            Container(width: 220, height: 12, color: FitColors.paper2),
          ],
        ),
      ),
    );
  }
}

class _ListFailed extends StatelessWidget {
  const _ListFailed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Could not load the library', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFeedback.error(failure.message),
          const SizedBox(height: FitSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
