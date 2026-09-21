import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/toggle_wrap.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_providers.dart';
import '../widgets/filter_button.dart';

/// Exercise library and — in [pickMode] — the picker the programme editors
/// open. Built for choosing quickly: a search field, three filter buttons
/// (muscle, equipment, pattern) that open a sheet, then a compact list where
/// each row is the name, "primary muscle · equipment" and an arrow. Nothing
/// else: instructions, alternatives and contraindications belong to the
/// detail screen (progressive disclosure). Every filter change is a
/// request; the list is whatever the server says is performable (§30).
class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  const ExerciseBrowserScreen({this.pickMode = false, super.key});

  /// When true, tapping a row returns it to the caller (`context.pop(item)`)
  /// instead of opening its detail; the detail is one tap away on the row.
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

  /// One sheet per filter. Multi-select for equipment, exclusive otherwise;
  /// the list behind it refreshes as toggles change, so "Done" is just close.
  Future<void> _openSheet(String title, Widget Function(BuildContext) body) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: FitColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: FitRadius.medium),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          // Never taller than most of the screen; the options scroll.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.md,
              FitSpacing.screen,
              FitSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: Theme.of(ctx).textTheme.labelSmall,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('filters.done'),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: FitSpacing.sm),
                Flexible(child: SingleChildScrollView(child: body(ctx))),
                const SizedBox(height: FitSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMuscle() => _openSheet(
        'Muscle',
        (_) => Consumer(
          builder: (context, ref, __) {
            final filters = ref.watch(exerciseFiltersProvider);
            final notifier = ref.read(exerciseFiltersProvider.notifier);
            return ToggleWrap<MuscleGroup>(
              keyPrefix: 'muscle',
              options: MuscleGroup.values,
              isSelected: (m) => filters.muscle == m,
              onTap: (m) => notifier.setMuscle(filters.muscle == m ? null : m),
              label: (m) => m.label,
            );
          },
        ),
      );

  void _openEquipment() => _openSheet(
        'Equipment I have',
        (_) => Consumer(
          builder: (context, ref, __) {
            final filters = ref.watch(exerciseFiltersProvider);
            final notifier = ref.read(exerciseFiltersProvider.notifier);
            return ToggleWrap<Equipment>(
              keyPrefix: 'equipment',
              options: Equipment.values,
              isSelected: filters.equipment.contains,
              onTap: notifier.toggleEquipment,
              label: (e) => e.label,
            );
          },
        ),
      );

  void _openPattern() => _openSheet(
        'Movement pattern',
        (_) => Consumer(
          builder: (context, ref, __) {
            final filters = ref.watch(exerciseFiltersProvider);
            final notifier = ref.read(exerciseFiltersProvider.notifier);
            return ToggleWrap<MovementPattern>(
              keyPrefix: 'pattern',
              options: MovementPattern.values,
              isSelected: (p) => filters.pattern == p,
              onTap: (p) =>
                  notifier.setPattern(filters.pattern == p ? null : p),
              label: (p) => p.label,
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filters = ref.watch(exerciseFiltersProvider);
    final notifier = ref.read(exerciseFiltersProvider.notifier);
    final async = ref.watch(exerciseListProvider);
    final kit = filters.equipment.length;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(
          widget.pickMode ? 'ADD EXERCISE' : 'LIBRARY',
          style: textTheme.labelSmall,
        ),
        centerTitle: false,
        actions: <Widget>[
          if (filters.hasFilters)
            TextButton(
              key: const ValueKey('filters.clear'),
              onPressed: () {
                _search.clear();
                notifier.clear();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.xs,
                FitSpacing.screen,
                FitSpacing.sm,
              ),
              child: AuthFormField(
                fieldKey: const ValueKey('exercises.search'),
                label: 'Search exercises',
                controller: _search,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => notifier.setSearch(_search.text),
                onChanged: _onSearchChanged,
              ),
            ),
            // Three buttons that read as what they filter on, and say what
            // is chosen. They share the width so all three fit a 360 px
            // phone, and open sheets: the whole vocabulary on one row was
            // the clutter, and its tail ran off the screen.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilterButton(
                      key: const ValueKey('filter.muscle'),
                      label: 'Muscle',
                      value: filters.muscle?.label,
                      onTap: _openMuscle,
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: FilterButton(
                      key: const ValueKey('filter.equipment'),
                      label: 'Equipment',
                      value: kit == 0
                          ? null
                          : kit == 1
                              ? filters.equipment.first.label
                              : '$kit items',
                      onTap: _openEquipment,
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: FilterButton(
                      key: const ValueKey('filter.pattern'),
                      label: 'Pattern',
                      value: filters.pattern?.label,
                      onTap: _openPattern,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.sm),
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
        return ExerciseRow(item: item, pickMode: pickMode);
      },
    );
  }
}

/// One row: name (wraps, never clips), "primary muscle · equipment"
/// (one line, ellipsis), an arrow. 56 px minimum, 18 px gutters. In pick
/// mode the row picks and the small "i" opens the detail.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({required this.item, required this.pickMode, super.key});

  final ExerciseSummary item;
  final bool pickMode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primary = item.primaryMuscles.isEmpty
        ? item.movementPattern.label
        : item.primaryMuscles.first.label;
    final kit = item.equipment.map((e) => e.label).join(' + ');
    return InkWell(
      key: ValueKey('exercise.${item.slug}'),
      onTap: () => pickMode
          ? context.popOrHome<ExerciseSummary>(item)
          : context.push(Routes.exerciseDetail(item.id)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$primary · $kit',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (pickMode)
                IconButton(
                  key: ValueKey('exercise.${item.slug}.info'),
                  tooltip: 'About ${item.name}',
                  onPressed: () => context.push(Routes.exerciseDetail(item.id)),
                  icon: const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: FitColors.ink60,
                  ),
                ),
              Icon(
                pickMode ? Icons.arrow_forward : Icons.chevron_right,
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
