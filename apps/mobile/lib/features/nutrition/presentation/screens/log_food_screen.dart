import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../ai/presentation/controllers/ai_providers.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../mess/data/mess_repository.dart';
import '../../../mess/domain/mess.dart';
import '../../../mess/presentation/mess_providers.dart';
import '../../../mess/presentation/widgets/mess_sheets.dart';
import '../../../mess/presentation/widgets/mess_widgets.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../controllers/food_providers.dart';
import '../widgets/ask_to_add_food.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/food_widgets.dart';
import '../widgets/log_controls.dart';
import '../widgets/portion_sheet.dart';
import 'describe_meal_screen.dart';
import '../../../../shared/widgets/fit_glass.dart';

part 'log_food_panes.dart';
part 'log_food_saved.dart';

enum LogSource {
  /// Phase 9: the day's mess menu — offered when the user has a mess.
  mess('Mess', Icons.restaurant_outlined),
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
    final items = r.when(ok: (v) => v, err: (f) => throw f);
    if (items.isEmpty) ref.read(missingFoodReporterProvider).foundNothing(q);
    return items;
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
  LogSource? _chosen;

  /// Mess first when the user has one and it has a menu for the day
  /// (Phase 9); otherwise the Phase 8 order, Recent first.
  LogSource _source(bool hasMess) => _chosen == LogSource.mess && !hasMess
      ? LogSource.recent
      : _chosen ?? (hasMess ? LogSource.mess : LogSource.recent);

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
    final hasMess = ref.watch(messMenuProvider((date: _date, code: null))).value
        is MenuLoaded;
    final source = _source(hasMess);
    final aiOn = ref.watch(aiAvailableProvider);
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
      body: FitBackdrop(
        child: SafeArea(
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
                      // Phase 14: a meal in words, read by FITOS AI into a
                      // draft the user checks. Only while AI is on and set up.
                      if (aiOn) ...<Widget>[
                        _DescribeEntry(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            if (await showDescribeMeal(context, _target)) {
                              _done();
                            }
                          },
                        ),
                        const SizedBox(height: FitSpacing.md),
                      ],
                      SegmentBar<LogSource>(
                        keyPrefix: 'log.source',
                        selected: source,
                        onSelect: (s) => setState(() => _chosen = s),
                        segments: [
                          for (final s in LogSource.values)
                            if (s != LogSource.mess || hasMess)
                              Segment(value: s, label: s.label, icon: s.icon),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              switch (source) {
                LogSource.mess => _MessPane(
                    date: _date,
                    slot: _slot,
                    onLogged: _done,
                  ),
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
      ),
    );
  }
}

/// Phase 14: the way into "Describe your meal".
class _DescribeEntry extends StatelessWidget {
  const _DescribeEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: const ValueKey('log.describe'),
      onTap: onTap,
      customBorder: fitGlass
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(FitRadius.block),
            )
          : null,
      child: DecoratedBox(
        // ADR-029: a glowing block on glass.
        decoration: fitGlass
            ? FitBlock.decoration(glow: true)
            : BoxDecoration(border: Border.all(color: FitColors.ink)),
        child: Padding(
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_outlined, color: FitColors.ink),
              const SizedBox(width: FitSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Describe your meal', style: textTheme.titleMedium),
                    Text(
                      'Type what you ate; you check it before it is logged.',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}
