import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../controllers/food_providers.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/log_controls.dart';
import '../widgets/portion_sheet.dart';

enum LogSource {
  recent('Recent', Icons.history),
  search('Search', Icons.search),
  saved('Saved meals', Icons.bookmark_border),
  quickAdd('Quick add', Icons.bolt_outlined);

  const LogSource(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Search results for the log sheet — its own query, so logging never
/// disturbs the Food Library's search. Ranking is the server's (Phase 7).
final logSearchProvider =
    FutureProvider.autoDispose.family<List<FoodSearchResult>, String>(
  (ref, q) async {
    final r = await ref.read(foodRepositoryProvider).search(q);
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// The log sheet (§31 Phase 8): for one day and meal, Recent · Search ·
/// Saved meals · Quick add. Recent, saved meals, results already on screen
/// and quick add work offline (owner J11); search needs the network.
///
/// ONE vertical scroll (a CustomScrollView). The meal bar and the source bar
/// scroll away; in Search the field is pinned above its results, so with
/// the keyboard open the field stays in view and the results scroll under
/// it. The Scaffold resizes for the keyboard, so nothing is hidden behind it
/// and no height is assumed.
class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({required this.target, super.key});

  /// Day and meal; null → today, the meal by the local hour.
  final LogTarget? target;

  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  late final String _date =
      widget.target?.date ?? ref.read(eatDateProvider.notifier).today;
  late MealSlot _slot =
      widget.target?.slot ?? MealSlot.forHour(ref.read(localHourProvider));
  LogSource _source = LogSource.recent;

  LogTarget get _target => LogTarget(date: _date, slot: _slot);

  Future<void> _logFood(
    Food food, {
    String? rowLabel,
    NutritionBasis? rowBasis,
    double? servings,
  }) async {
    FocusScope.of(context).unfocus();
    final choice = await showPortionSheet(
      context,
      food: food,
      slot: _slot,
      rowLabel: rowLabel,
      rowBasis: rowBasis,
      servings: servings,
    );
    if (choice == null || !mounted) return;
    await ref.read(foodLoggerProvider).logFood(
          food,
          choice.row,
          choice.portion,
          asGrams: choice.asGrams,
          target: LogTarget(date: _date, slot: choice.slot),
        );
    _done();
  }

  void _done() {
    if (!mounted) return;
    context.popOrHome();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(eatDateProvider.notifier).today;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('LOG FOOD', style: textTheme.labelSmall),
            Text(
              EatFormat.dayLabel(_date, today),
              key: const ValueKey('log.day'),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const ValueKey('log.scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: FitSpacing.screen,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('ADD TO', style: textTheme.labelSmall),
                    MealSlotBar(
                      keyPrefix: 'log.slot',
                      selected: _slot,
                      onSelect: (s) => setState(() => _slot = s),
                    ),
                    const SizedBox(height: FitSpacing.md),
                    SegmentBar<LogSource>(
                      keyPrefix: 'log.source',
                      selected: _source,
                      onSelect: (s) => setState(() => _source = s),
                      segments: [
                        for (final s in LogSource.values)
                          Segment(value: s, label: s.label, icon: s.icon),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            switch (_source) {
              LogSource.recent => _RecentPane(onPick: _logFood),
              LogSource.search => _SearchPane(onPick: (f) => _logFood(f)),
              LogSource.saved => _SavedPane(target: _target, onLogged: _done),
              LogSource.quickAdd =>
                _QuickAddPane(target: _target, onLogged: _done),
            },
            const SliverToBoxAdapter(
              child: SizedBox(height: FitSpacing.xl),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ shared -- */

/// A food to pick: name; source badge and the nutrition of its first
/// serving (a range when estimated); an add affordance. Compact, one row.
class LogFoodRow extends StatelessWidget {
  const LogFoodRow({
    required this.food,
    required this.onTap,
    this.detail,
    super.key,
  });

  final Food food;
  final VoidCallback onTap;

  /// A line that replaces the default nutrition summary's lead ("Last: …").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = food.headline;
    final summary = '${FoodFormat.kcal(row)} · '
        '${FoodFormat.range(row.proteinLow, row.proteinHigh)} g protein · '
        '${FoodFormat.servingShort(row)}';
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.sm,
            FitSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      food.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        FoodSourceBadge(food: food),
                        const SizedBox(width: FitSpacing.sm),
                        Expanded(
                          child: Text(
                            detail == null ? summary : '$detail · $summary',
                            style: textTheme.bodyMedium?.copyWith(
                              color: FitColors.ink60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        FitSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: textTheme.labelSmall),
          if (caption != null)
            Text(
              caption!,
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
        ],
      ),
    );
  }
}

/// A message as a sliver: what happened, what to do (§6.6).
class _MessageSliver extends StatelessWidget {
  const _MessageSliver({required this.title, required this.body, this.icon});

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: FitColors.ink60),
              const SizedBox(width: FitSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    body,
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static skeleton rows while a list loads (no spinner, §6.6).
class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) => SliverList.list(
        children: <Widget>[
          for (var i = 0; i < 4; i++)
            Padding(
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
                  Container(width: 200, height: 12, color: FitColors.paper2),
                ],
              ),
            ),
        ],
      );
}

typedef _PickFood = Future<void> Function(
  Food food, {
  String? rowLabel,
  NutritionBasis? rowBasis,
  double? servings,
});

/// Recent foods as slivers (under a title), or nothing when there are none.
List<Widget> _recentSlivers(
  BuildContext context,
  AsyncValue<Cached<List<RecentFood>>> async,
  _PickFood onPick, {
  required bool showEmpty,
}) {
  return switch (async) {
    AsyncData(:final value) when value.value.isEmpty => [
        if (showEmpty)
          const _MessageSliver(
            icon: Icons.history,
            title: 'Nothing logged yet',
            body:
                'Foods you log show up here with the portion you used last, ready to log again.',
          ),
      ],
    AsyncData(:final value) => [
        SliverToBoxAdapter(
          child: _SectionTitle(
            'Recent',
            caption: value.stale ? 'Offline — as last loaded.' : null,
          ),
        ),
        SliverList.separated(
          itemCount: value.value.length,
          separatorBuilder: (_, __) =>
              const Divider(color: FitColors.rule, height: 1),
          itemBuilder: (_, i) {
            final r = value.value[i];
            return LogFoodRow(
              key: ValueKey('recent.${r.food.slug}'),
              food: r.food,
              detail:
                  'Last ${FoodFormat.number(r.lastServings)} × ${r.lastServingLabel}',
              onTap: () => onPick(
                r.food,
                rowLabel: r.lastServingLabel,
                rowBasis: r.lastBasis,
                servings: r.lastServings,
              ),
            );
          },
        ),
      ],
    AsyncError(:final error) => [
        if (showEmpty)
          _MessageSliver(
            icon: Icons.cloud_off_outlined,
            title: 'Recent foods are not available',
            body: failureOf(error) is Offline
                ? 'Offline, and nothing was loaded before. Quick add works offline.'
                : failureOf(error).message,
          ),
      ],
    _ => [if (showEmpty) const _SkeletonSliver()],
  };
}

/* ------------------------------------------------------------ recent -- */

class _RecentPane extends ConsumerWidget {
  const _RecentPane({required this.onPick});

  final _PickFood onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverMainAxisGroup(
      slivers: _recentSlivers(
        context,
        ref.watch(recentFoodsProvider),
        onPick,
        showEmpty: true,
      ),
    );
  }
}

/* ------------------------------------------------------------ search -- */

class _SearchPane extends ConsumerStatefulWidget {
  const _SearchPane({required this.onPick});

  final void Function(Food food) onPick;

  @override
  ConsumerState<_SearchPane> createState() => _SearchPaneState();
}

class _SearchPaneState extends ConsumerState<_SearchPane> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _set(String v) => setState(() => _q = v.trim());

  @override
  Widget build(BuildContext context) {
    final results = _q.isEmpty ? null : ref.watch(logSearchProvider(_q));
    return SliverMainAxisGroup(
      slivers: <Widget>[
        // Pinned: stays above the results — and above the keyboard, since
        // the Scaffold shrinks the viewport for it.
        PinnedHeaderSliver(
          child: ColoredBox(
            color: FitColors.paper,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                FitSpacing.sm,
              ),
              child: TextField(
                key: const ValueKey('log.search'),
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search foods — dal, roti, idly…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            _set('');
                          },
                        ),
                ),
                onChanged: (v) {
                  setState(() {}); // the clear button
                  _debounce?.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 250), () => _set(v));
                },
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _set(v);
                },
              ),
            ),
          ),
        ),
        if (results == null)
          ..._recentSlivers(
            context,
            ref.watch(recentFoodsProvider),
            (food, {rowLabel, rowBasis, servings}) async => widget.onPick(food),
            showEmpty: false,
          )
        else
          ...switch (results) {
            AsyncData(:final value) when value.isEmpty => [
                _MessageSliver(
                  icon: Icons.search_off,
                  title: 'No food matches “$_q”',
                  body:
                      'Try a shorter name, add it from its label in the Food library, or use Quick add.',
                ),
              ],
            AsyncData(:final value) => [
                const SliverToBoxAdapter(child: _SectionTitle('Results')),
                SliverList.separated(
                  key: const ValueKey('log.results'),
                  itemCount: value.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: FitColors.rule, height: 1),
                  itemBuilder: (_, i) => LogFoodRow(
                    key: ValueKey('food.${value[i].food.slug}'),
                    food: value[i].food,
                    onTap: () => widget.onPick(value[i].food),
                  ),
                ),
              ],
            AsyncError(:final error) => [
                _MessageSliver(
                  icon: Icons.cloud_off_outlined,
                  title: 'Search needs a connection',
                  body: failureOf(error) is Offline
                      ? 'Recent foods, saved meals and quick add work offline.'
                      : failureOf(error).message,
                ),
              ],
            _ => [const _SkeletonSliver()],
          },
      ],
    );
  }
}

/* ------------------------------------------------------- saved meals -- */

class _SavedPane extends ConsumerWidget {
  const _SavedPane({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedMealsProvider);
    return SliverMainAxisGroup(
      slivers: switch (async) {
        AsyncData(:final value) when value.value.isEmpty => [
            const _MessageSliver(
              icon: Icons.bookmark_border,
              title: 'No saved meals yet',
              body:
                  'A meal you eat often can be logged in one tap: on EAT, "Save as meal" on a meal you have logged.',
            ),
          ],
        AsyncData(:final value) => [
            SliverToBoxAdapter(
              child: _SectionTitle(
                'Saved meals',
                caption: value.stale
                    ? 'Offline — as last loaded.'
                    : 'One tap logs the whole meal to ${target.slot.label}.',
              ),
            ),
            SliverList.separated(
              key: const ValueKey('log.saved'),
              itemCount: value.value.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: FitColors.rule, height: 1),
              itemBuilder: (_, i) => _SavedMealTile(
                meal: value.value[i],
                target: target,
                onLogged: onLogged,
              ),
            ),
          ],
        AsyncError(:final error) => [
            _MessageSliver(
              icon: Icons.cloud_off_outlined,
              title: 'Saved meals are not available',
              body: failureOf(error) is Offline
                  ? 'Offline, and none were loaded before.'
                  : failureOf(error).message,
            ),
          ],
        _ => [const _SkeletonSliver()],
      },
    );
  }
}

class _SavedMealTile extends ConsumerWidget {
  const _SavedMealTile({
    required this.meal,
    required this.target,
    required this.onLogged,
  });

  final SavedMeal meal;
  final LogTarget target;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final preview = PortionPreview.savedMeal(meal);
    final unavailable = preview == null;
    return Padding(
      key: ValueKey('saved.${meal.id}'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.sm,
        FitSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.bookmark, color: FitColors.ink),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(meal.name, style: textTheme.titleMedium),
                Text(
                  meal.items.map((i) => i.name).join(' · '),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  unavailable
                      ? 'A food in this meal is no longer available.'
                      : '≈ ${EatFormat.kcal(preview.kcalLow, preview.kcalHigh)} kcal · preview',
                  style: textTheme.bodyMedium?.copyWith(
                    color: unavailable ? FitColors.oxide : FitColors.ink60,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('saved.${meal.id}.delete'),
            tooltip: 'Delete saved meal',
            icon: const Icon(Icons.close, size: 18, color: FitColors.ink35),
            onPressed: () async {
              final r = await ref
                  .read(nutritionLogRepositoryProvider)
                  .deleteSavedMeal(meal.id);
              if (!context.mounted) return;
              if (r case Err(:final failure)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      failure is Offline
                          ? 'Deleting a saved meal needs a connection.'
                          : failure.message,
                    ),
                  ),
                );
              } else {
                ref.invalidate(savedMealsProvider);
              }
            },
          ),
          FilledButton(
            key: ValueKey('saved.${meal.id}.log'),
            onPressed: unavailable
                ? null
                : () async {
                    await ref
                        .read(foodLoggerProvider)
                        .logSavedMeal(meal, target: target);
                    onLogged();
                  },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- quick add -- */

/// Owner J6: kcal, protein, carbohydrate and fat required; fibre optional.
class _QuickAddPane extends ConsumerStatefulWidget {
  const _QuickAddPane({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  ConsumerState<_QuickAddPane> createState() => _QuickAddPaneState();
}

class _QuickAddPaneState extends ConsumerState<_QuickAddPane> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carb, _fat, _fibre]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String t) =>
      double.tryParse(t.trim().replaceAll(',', '.'));

  String? Function(String?) _amount({
    required bool required,
    required double max,
  }) =>
      (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return required ? 'Required.' : null;
        final n = _parse(t);
        if (n == null) return 'Enter a number.';
        if (n < 0) return 'Cannot be negative.';
        if (n > max) return 'At most ${max.toStringAsFixed(0)}.';
        return null;
      };

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    await ref.read(foodLoggerProvider).logQuickAdd(
          QuickAdd(
            name: name.isEmpty ? null : name,
            kcal: _parse(_kcal.text)!,
            proteinG: _parse(_protein.text)!,
            carbG: _parse(_carb.text)!,
            fatG: _parse(_fat.text)!,
            fibreG: _parse(_fibre.text),
          ),
          target: widget.target,
        );
    widget.onLogged();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const number = TextInputType.numberWithOptions(decimal: true);
    Widget field(
      String key,
      String label,
      TextEditingController c,
      String? Function(String?) v, {
      bool numeric = true,
    }) =>
        AuthFormField(
          fieldKey: ValueKey('quick.$key'),
          label: label,
          controller: c,
          keyboardType: numeric ? number : null,
          textInputAction: TextInputAction.next,
          validator: v,
        );
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: a),
            const SizedBox(width: FitSpacing.md),
            Expanded(child: b),
          ],
        );
    const gap = SizedBox(height: FitSpacing.md);
    return SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey('log.quick'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.md,
          FitSpacing.screen,
          0,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.bolt_outlined, color: FitColors.ink),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: Text('Quick add', style: textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Numbers from a label or a menu. Calories, protein, carbs and '
                'fat are needed; fibre only if you know it. Logged exactly as '
                'typed, as your own entry.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              gap,
              field(
                'name',
                'Name (optional)',
                _name,
                (v) => (v?.trim().length ?? 0) > 60
                    ? 'At most 60 characters.'
                    : null,
                numeric: false,
              ),
              gap,
              field(
                'kcal',
                'Calories (kcal)',
                _kcal,
                _amount(required: true, max: 5000),
              ),
              gap,
              pair(
                field(
                  'protein',
                  'Protein (g)',
                  _protein,
                  _amount(required: true, max: 500),
                ),
                field(
                  'carb',
                  'Carbs (g)',
                  _carb,
                  _amount(required: true, max: 500),
                ),
              ),
              gap,
              pair(
                field(
                  'fat',
                  'Fat (g)',
                  _fat,
                  _amount(required: true, max: 500),
                ),
                field(
                  'fibre',
                  'Fibre (g, optional)',
                  _fibre,
                  _amount(required: false, max: 500),
                ),
              ),
              const SizedBox(height: FitSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('quick.log'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _submit,
                icon: Icon(mealSlotIcon(widget.target.slot)),
                label: Text('Add to ${widget.target.slot.label}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
