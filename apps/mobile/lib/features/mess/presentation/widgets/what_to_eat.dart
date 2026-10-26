import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../nutrition/domain/entities/food_log.dart';
import '../../../nutrition/domain/portion_preview.dart';
import '../../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../../nutrition/presentation/controllers/food_logger.dart';
import '../../../nutrition/presentation/widgets/eat_widgets.dart';
import '../../../nutrition/presentation/widgets/food_widgets.dart';
import '../../../nutrition/presentation/widgets/log_controls.dart';
import '../../domain/mess.dart';
import '../../domain/recommendation.dart';
import '../mess_providers.dart';
import 'mess_widgets.dart';
import 'recommend_words.dart';

part 'what_to_eat_plate.dart';

/// Phase 10 — "What should I eat?" for one meal of the menu on screen.
///
/// Everything shown is the server's: the plates, every range, the shortfall
/// and the reason codes (worded by [ReasonText]). Offline or on failure there
/// is no plate — never an earlier one (requirement 22). Today's plate can be
/// logged in one tap; tomorrow's is for planning.
class WhatToEatSection extends ConsumerStatefulWidget {
  const WhatToEatSection({required this.date, required this.code, super.key});

  /// The menu date on screen.
  final String date;

  /// The mess browsed (null = mine).
  final String? code;

  @override
  ConsumerState<WhatToEatSection> createState() => _WhatToEatSectionState();
}

class _WhatToEatSectionState extends ConsumerState<WhatToEatSection>
    with AutomaticKeepAliveClientMixin {
  MealSlot? _slot;
  int _rank = 1;
  bool _whyNot = false;
  bool _busy = false;

  @override
  void didUpdateWidget(WhatToEatSection old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date || old.code != widget.code) {
      _slot = null;
      _rank = 1;
    }
  }

  /// The MESS list is lazy: kept alive, scrolling down the menu and back
  /// neither refetches the suggestion nor loses the chosen meal or plate.
  @override
  bool get wantKeepAlive => true;

  RecommendKey get _key =>
      (date: widget.date, code: widget.code, slot: _slot?.wire);

  Future<void> _log(MessRecommendation rec, Plate plate) async {
    setState(() => _busy = true);
    await ref.read(foodLoggerProvider).logMessPlate(
      messCode: rec.mess.code,
      menuDate: rec.date,
      target: LogTarget(date: rec.date, slot: rec.slot),
      items: [
        for (final i in plate.items)
          (
            dishSlug: i.dishSlug,
            name: i.name,
            servings: i.servings,
            servingLabel: i.servingLabel,
            preview: PreviewNutrition(
              kcalLow: i.macros.kcalLow,
              kcalHigh: i.macros.kcalHigh,
              proteinLow: i.macros.proteinLow,
              proteinHigh: i.macros.proteinHigh,
              carbLow: i.macros.carbLow,
              carbHigh: i.macros.carbHigh,
              fatLow: i.macros.fatLow,
              fatHigh: i.macros.fatHigh,
              fibreLow: null,
              fibreHigh: null,
            ),
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged plate ${plate.rank} to ${rec.slot.label}.'),
      ),
    );
    ref.invalidate(messRecommendProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(messDateProvider.notifier).today;
    final inRange = widget.date == today || widget.date == shiftDate(today, 1);

    final header = Text(
      'WHAT SHOULD I EAT?',
      key: const ValueKey('rec.section'),
      style: textTheme.labelSmall,
    );
    if (!inRange) {
      return Padding(
        padding: const EdgeInsets.only(top: FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            const SizedBox(height: FitSpacing.xs),
            Text(
              'Suggestions are for today and tomorrow.',
              key: const ValueKey('rec.outOfRange'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          ],
        ),
      );
    }

    final state = ref.watch(messRecommendProvider(_key));
    final rec = switch (state.value) {
      RecommendLoaded(:final recommendation) => recommendation,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          const SizedBox(height: FitSpacing.xs),
          MealSlotBar(
            keyPrefix: 'rec.slot',
            selected: _slot ?? rec?.slot ?? MealSlot.lunch,
            onSelect: (s) => setState(() {
              _slot = s;
              _rank = 1;
            }),
          ),
          const SizedBox(height: FitSpacing.sm),
          ...switch (state) {
            AsyncData(value: final RecommendLoaded loaded) =>
              _body(context, loaded.recommendation),
            AsyncData(value: RecommendOffline()) => <Widget>[
                const _Note(
                  key: ValueKey('rec.offline'),
                  text:
                      'Suggestions need a connection. The menu below is the one saved on this phone.',
                ),
              ],
            AsyncData(value: RecommendNoMess()) => const <Widget>[],
            AsyncData(value: RecommendFailed(:final failure)) => <Widget>[
                _Note(
                  key: const ValueKey('rec.failed'),
                  text: failure is ServiceUnavailable
                      ? 'FITOS is not answering right now — no suggestion.'
                      : 'Could not work out a plate: ${failure.message}',
                  colour: FitColors.oxide,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('rec.retry'),
                    onPressed: () =>
                        ref.invalidate(messRecommendProvider(_key)),
                    child: const Text('Try again'),
                  ),
                ),
              ],
            AsyncError() => <Widget>[
                _Note(
                  key: const ValueKey('rec.failed'),
                  text: 'Could not work out a plate.',
                  colour: FitColors.oxide,
                ),
              ],
            _ => <Widget>[
                Text(
                  'Working out your plate…',
                  key: const ValueKey('rec.loading'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
          },
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, MessRecommendation rec) {
    final textTheme = Theme.of(context).textTheme;
    final safety = _SafetyLine(rec: rec);
    final whyNot = _WhyNot(
      rec: rec,
      open: _whyNot,
      onToggle: () => setState(() => _whyNot = !_whyNot),
    );
    final logged = rec.slotAlreadyLogged
        ? <Widget>[
            _Note(
              key: const ValueKey('rec.alreadyLogged'),
              text:
                  'You have already logged ${rec.slot.label.toLowerCase()} today — this is for anything more.',
            ),
          ]
        : const <Widget>[];

    switch (rec.status) {
      case RecommendationStatus.noTargets:
        return [
          const _Note(
            key: ValueKey('rec.noTargets'),
            text: 'Set a goal in Profile and FITOS can suggest a plate.',
          ),
        ];
      case RecommendationStatus.menuUnavailable:
        return [
          const _Note(
            key: ValueKey('rec.unavailable'),
            text: 'There is no menu for this day, so there is no suggestion.',
          ),
        ];
      case RecommendationStatus.mealNotServed:
        return [
          _Note(
            key: const ValueKey('rec.notServed'),
            text:
                '${rec.slot.label} is not on this menu, so there is no suggestion.',
          ),
        ];
      case RecommendationStatus.targetReached:
        final protein = rec.target?.protein ?? 0;
        return [
          ...logged,
          _Note(
            key: const ValueKey('rec.targetReached'),
            text: protein > 0
                ? 'You have reached today\'s calories. You still need about ${FoodFormat.number(protein)} g protein, but FITOS will not suggest a plate over your calories.'
                : 'You have reached today\'s calories — no plate to suggest.',
          ),
        ];
      case RecommendationStatus.nothingSafe:
        return [
          ...logged,
          safety,
          _Note(
            key: const ValueKey('rec.nothingSafe'),
            text:
                'Nothing at this meal is confirmed safe for your diet and allergies, so there is no plate.',
            colour: FitColors.oxide,
          ),
          whyNot,
        ];
      case RecommendationStatus.noMeal:
        return [
          ...logged,
          safety,
          _Note(
            key: const ValueKey('rec.noMeal'),
            text:
                'No meal can be made from what this menu offers you: there is no staple (rice, roti, idli…) or protein dish that fits your diet and allergies. A drink, dessert or side on its own is never suggested as a meal.',
            colour: FitColors.oxide,
          ),
          whyNot,
        ];
      case RecommendationStatus.nothingFits:
        final smallest = rec.smallestMealKcal;
        final left = rec.target?.dayRemainingKcal;
        return [
          ...logged,
          safety,
          _Note(
            key: const ValueKey('rec.nothingFits'),
            text: smallest != null && left != null
                ? 'There is a meal on this menu, but even the smallest (about ${FoodFormat.number(smallest)} kcal) is more than you have left today (${FoodFormat.number(left)} kcal), so FITOS does not suggest one.'
                : 'There is a meal on this menu, but even the smallest is more than you have left today.',
          ),
          whyNot,
        ];
      case RecommendationStatus.ok:
        final plate = rec.plates.firstWhere(
          (p) => p.rank == _rank,
          orElse: () => rec.plates.first,
        );
        final names = {
          for (final p in rec.plates)
            for (final i in p.items) i.dishSlug: i.name,
        };
        final diets = {for (final d in rec.dishes) d.dishSlug: d.diet};
        return [
          ...logged,
          safety,
          if (rec.basis == 'inferred')
            _Note(
              key: const ValueKey('rec.inferred'),
              text:
                  'Based on the inferred menu — the mess has not published this day.',
              colour: FitColors.amber,
            ),
          const SizedBox(height: FitSpacing.sm),
          Text(
            ReasonText.structure(plate.structure),
            key: const ValueKey('rec.structure'),
            style: textTheme.titleSmall?.copyWith(
              color: switch (plate.structure.kind) {
                StructureKind.limited ||
                StructureKind.limitedNoStaple =>
                  FitColors.amber,
                _ => FitColors.ink,
              },
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Center(
            child: ThaliView(
              key: ValueKey('rec.thali.${plate.rank}'),
              items: plate.items,
              diets: diets,
            ),
          ),
          const SizedBox(height: FitSpacing.sm),
          for (final (index, item) in plate.items.indexed)
            _PlateRow(index: index + 1, item: item, diet: diets[item.dishSlug]),
          const SizedBox(height: FitSpacing.sm),
          Wrap(
            spacing: FitSpacing.lg,
            runSpacing: FitSpacing.sm,
            children: <Widget>[
              MacroCell(
                label: 'Calories',
                value:
                    '${EatFormat.kcal(plate.totals.kcalLow, plate.totals.kcalHigh)} kcal',
                valueKey: const ValueKey('rec.kcal'),
              ),
              MacroCell(
                label: 'Protein',
                value: EatFormat.grams(
                  plate.totals.proteinLow,
                  plate.totals.proteinHigh,
                ),
                valueKey: const ValueKey('rec.protein'),
              ),
              MacroCell(
                label: 'Carbs',
                value: EatFormat.grams(
                  plate.totals.carbLow,
                  plate.totals.carbHigh,
                ),
              ),
              MacroCell(
                label: 'Fat',
                value:
                    EatFormat.grams(plate.totals.fatLow, plate.totals.fatHigh),
              ),
            ],
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'Estimate · ${plate.confidence} confidence · fibre not known',
            key: const ValueKey('rec.confidence'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
          ),
          if (rec.target != null)
            Text(
              'This meal\'s share: ${FoodFormat.number(rec.target!.kcal)} kcal · ${FoodFormat.number(rec.target!.protein)} g protein',
              key: const ValueKey('rec.target'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          if (plate.rank == 1 &&
              (rec.proteinShortfall != null || rec.kcalShortfall != null))
            _Shortfall(rec: rec),
          const SizedBox(height: FitSpacing.sm),
          for (final r in plate.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '· ${ReasonText.plate(r, names)}',
                key: ValueKey('rec.reason.${r.code}'),
                style: textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: FitSpacing.md),
          if (rec.loggable)
            FilledButton(
              key: const ValueKey('rec.log'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : () => _log(rec, plate),
              child: Text('Log this plate to ${rec.slot.label}'),
            )
          else
            _Note(
              key: const ValueKey('rec.planning'),
              text:
                  'Planning for ${EatFormat.shortDate(rec.date)} — log it on the day.',
            ),
          if (rec.plates.length > 1) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            Text('OTHER PLATES', style: textTheme.labelSmall),
            for (final p in rec.plates.where((p) => p.rank != plate.rank))
              _OtherPlate(
                plate: p,
                onTap: () => setState(() => _rank = p.rank),
              ),
          ],
          whyNot,
        ];
    }
  }
}
