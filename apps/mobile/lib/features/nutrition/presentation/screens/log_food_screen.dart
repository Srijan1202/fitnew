import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/toggle_wrap.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../controllers/food_providers.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/portion_sheet.dart';
import 'food_library_screen.dart';

enum LogSource {
  recent('Recent'),
  search('Search'),
  saved('Saved meals'),
  quickAdd('Quick add');

  const LogSource(this.label);
  final String label;
}

/// Search results for the log sheet — its own query, so logging never
/// disturbs the Food Library's search.
final logSearchProvider =
    FutureProvider.autoDispose.family<List<FoodSearchResult>, String>(
  (ref, q) async {
    final r = await ref.read(foodRepositoryProvider).search(q);
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// The log sheet (§31 Phase 8): Recent · Search · Saved meals · Quick add,
/// for one day and meal. Recent, saved meals, results already on screen and
/// quick add all work offline (owner J11); search needs the network.
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
    final dayText = _date == today ? 'today' : _date;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(
          'LOG FOOD · ${dayText.toUpperCase()}',
          style: textTheme.labelSmall,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ToggleWrap<MealSlot>(
                    keyPrefix: 'log.slot',
                    options: MealSlot.values,
                    isSelected: (s) => s == _slot,
                    onTap: (s) => setState(() => _slot = s),
                    label: (s) => s.label,
                  ),
                  const SizedBox(height: FitSpacing.xs),
                  ToggleWrap<LogSource>(
                    keyPrefix: 'log.source',
                    options: LogSource.values,
                    isSelected: (s) => s == _source,
                    onTap: (s) => setState(() => _source = s),
                    label: (s) => s.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.sm),
            const Divider(color: FitColors.rule, height: 1),
            Expanded(
              child: switch (_source) {
                LogSource.recent => _RecentList(onPick: _logFood),
                LogSource.search => _SearchPane(onPick: (f) => _logFood(f)),
                LogSource.saved =>
                  _SavedMeals(target: _target, onLogged: _done),
                LogSource.quickAdd =>
                  _QuickAddForm(target: _target, onLogged: _done),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.onPick});

  final Future<void> Function(
    Food food, {
    String? rowLabel,
    NutritionBasis? rowBasis,
    double? servings,
  }) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(recentFoodsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        title: 'Recent foods are not available',
        body: failureOf(e) is Offline
            ? 'Offline, and nothing was loaded before. Quick add works offline.'
            : failureOf(e).message,
      ),
      data: (cached) {
        if (cached.value.isEmpty) {
          return const _Message(
            title: 'Nothing logged yet',
            body: 'Foods you log show up here, with the portion you used last.',
          );
        }
        return ListView(
          key: const ValueKey('log.recent'),
          children: <Widget>[
            if (cached.stale)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: FitSpacing.screen),
                child: EatNotice(
                  text: 'Offline — your recent foods as last loaded.',
                ),
              ),
            for (final r in cached.value)
              ListTile(
                key: ValueKey('recent.${r.food.slug}'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
                title: Text(r.food.name, style: textTheme.titleMedium),
                subtitle: Text(
                  'Last: ${FoodFormat.number(r.lastServings)} × ${r.lastServingLabel}',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                trailing: FoodSourceBadge(food: r.food),
                onTap: () => onPick(
                  r.food,
                  rowLabel: r.lastServingLabel,
                  rowBasis: r.lastBasis,
                  servings: r.lastServings,
                ),
              ),
          ],
        );
      },
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final results = _q.isEmpty ? null : ref.watch(logSearchProvider(_q));
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.sm,
          ),
          child: AuthFormField(
            fieldKey: const ValueKey('log.search'),
            label: 'Search foods',
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 250),
                () => setState(() => _q = v.trim()),
              );
            },
            onFieldSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        Expanded(
          child: results == null
              ? const _Message(
                  title: 'Search the library',
                  body: 'Indian spellings work too: dhal, roti, idly.',
                )
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Message(
                    title: 'Search needs a connection',
                    body: failureOf(e) is Offline
                        ? 'Recent foods, saved meals and quick add work offline.'
                        : failureOf(e).message,
                  ),
                  data: (items) => items.isEmpty
                      ? _Message(
                          title: 'No food matches “$_q”',
                          body:
                              'Add it from its label in the Food library, or use quick add.',
                        )
                      : ListView.separated(
                          key: const ValueKey('log.results'),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: FitColors.rule, height: 1),
                          itemBuilder: (_, i) => FoodRow(
                            result: items[i],
                            onTap: () => widget.onPick(items[i].food),
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

class _SavedMeals extends ConsumerWidget {
  const _SavedMeals({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(savedMealsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        title: 'Saved meals are not available',
        body: failureOf(e) is Offline
            ? 'Offline, and none were loaded before.'
            : failureOf(e).message,
      ),
      data: (cached) {
        if (cached.value.isEmpty) {
          return const _Message(
            title: 'No saved meals yet',
            body:
                'On the EAT screen, "Save as meal" keeps a meal you logged for one-tap logging.',
          );
        }
        return ListView(
          key: const ValueKey('log.saved'),
          children: <Widget>[
            if (cached.stale)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: FitSpacing.screen),
                child: EatNotice(
                  text: 'Offline — your saved meals as last loaded.',
                ),
              ),
            for (final meal in cached.value)
              _SavedMealTile(
                meal: meal,
                target: target,
                onLogged: onLogged,
                textTheme: textTheme,
              ),
          ],
        );
      },
    );
  }
}

class _SavedMealTile extends ConsumerWidget {
  const _SavedMealTile({
    required this.meal,
    required this.target,
    required this.onLogged,
    required this.textTheme,
  });

  final SavedMeal meal;
  final LogTarget target;
  final VoidCallback onLogged;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(meal.name, style: textTheme.titleMedium),
                Text(
                  meal.items.map((i) => i.name).join(', '),
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
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: FitColors.ink60,
            ),
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

/// Owner J6: kcal, protein, carbohydrate and fat required; fibre optional.
class _QuickAddForm extends ConsumerStatefulWidget {
  const _QuickAddForm({required this.target, required this.onLogged});

  final LogTarget target;
  final VoidCallback onLogged;

  @override
  ConsumerState<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<_QuickAddForm> {
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
    Widget field(
      String key,
      String label,
      TextEditingController c,
      String? Function(String?) v, {
      bool number = true,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: FitSpacing.sm),
          child: AuthFormField(
            fieldKey: ValueKey('quick.$key'),
            label: label,
            controller: c,
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            textInputAction: TextInputAction.next,
            validator: v,
          ),
        );
    return Form(
      key: _form,
      child: ListView(
        key: const ValueKey('log.quick'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        children: <Widget>[
          field(
            'name',
            'Name (optional)',
            _name,
            (v) =>
                (v?.trim().length ?? 0) > 60 ? 'At most 60 characters.' : null,
            number: false,
          ),
          field(
            'kcal',
            'Energy (kcal)',
            _kcal,
            _amount(required: true, max: 5000),
          ),
          field(
            'protein',
            'Protein (g)',
            _protein,
            _amount(required: true, max: 500),
          ),
          field(
            'carb',
            'Carbohydrate (g)',
            _carb,
            _amount(required: true, max: 500),
          ),
          field('fat', 'Fat (g)', _fat, _amount(required: true, max: 500)),
          field(
            'fibre',
            'Fibre (g) — leave empty if you do not know',
            _fibre,
            _amount(required: false, max: 500),
          ),
          const SizedBox(height: FitSpacing.sm),
          FilledButton(
            key: const ValueKey('quick.log'),
            onPressed: _submit,
            child: Text('Log to ${widget.target.slot.label}'),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(FitSpacing.screen),
      children: <Widget>[
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: FitSpacing.sm),
        Text(
          body,
          style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
        ),
      ],
    );
  }
}
