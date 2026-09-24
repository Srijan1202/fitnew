import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/portion_preview.dart';
import 'food_widgets.dart';
import 'log_controls.dart';

/// What the portion step hands back: the row, the resolved portion, whether
/// it was entered in grams, and the slot.
class PortionChoice {
  const PortionChoice({
    required this.row,
    required this.portion,
    required this.asGrams,
    required this.slot,
  });

  final FoodNutrition row;
  final PortionResult portion;
  final bool asGrams;
  final MealSlot slot;
}

/// Opens the portion step for [food] and returns the choice, or null.
Future<PortionChoice?> showPortionSheet(
  BuildContext context, {
  required Food food,
  required MealSlot slot,
  String? rowLabel,
  NutritionBasis? rowBasis,
  double? servings,
  Widget? footer,
}) {
  return showModalBottomSheet<PortionChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: FitRadius.medium),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: PortionSheet(
        food: food,
        slot: slot,
        rowLabel: rowLabel,
        rowBasis: rowBasis,
        servings: servings,
        footer: footer,
      ),
    ),
  );
}

/// The portion step: which row (per katori / per 100 g / a USDA portion),
/// how much (servings in 0.01 steps, or grams where the row has a weight),
/// which meal. The line under it is a DISPLAY-ONLY preview (owner J10); the
/// server computes what is stored when the log reaches it.
class PortionSheet extends StatefulWidget {
  const PortionSheet({
    required this.food,
    required this.slot,
    this.rowLabel,
    this.rowBasis,
    this.servings,
    this.footer,
    super.key,
  });

  /// Phase 9: shown under the preview (a mess dish's estimate note and its
  /// "Report wrong nutrition" action).
  final Widget? footer;

  final Food food;
  final MealSlot slot;
  final String? rowLabel;
  final NutritionBasis? rowBasis;
  final double? servings;

  @override
  State<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<PortionSheet> {
  late FoodNutrition _row;
  late MealSlot _slot = widget.slot;
  bool _asGrams = false;
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rows = widget.food.nutrition;
    _row = rows.firstWhere(
      (r) => r.servingLabel == widget.rowLabel && r.basis == widget.rowBasis,
      orElse: () => widget.food.headline,
    );
    // A per-100 g row is entered in grams — how people weigh food.
    _asGrams = _row.basis == NutritionBasis.per100g;
    final servings = widget.servings ?? 1;
    _amount.text = FoodFormat.number(_asGrams ? servings * 100 : servings);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool get _gramsPossible => PortionPreview.gramsPerServing(_row) != null;

  double? get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  PortionResult get _portion {
    final v = _value;
    if (v == null) return const PortionResult.invalid('Enter an amount.');
    return _asGrams
        ? PortionPreview.resolve(_row, grams: v)
        : PortionPreview.resolve(_row, servings: v);
  }

  void _step(double by) {
    final v = (_value ?? 0) + by;
    final min = _asGrams ? 1.0 : PortionPreview.servingsMin;
    setState(() => _amount.text = FoodFormat.number(v < min ? min : v));
  }

  void _setMode(bool grams) {
    if (grams == _asGrams) return;
    final p = _portion;
    setState(() {
      _asGrams = grams;
      if (p.ok) {
        _amount.text = grams
            ? FoodFormat.number(p.grams ?? 100)
            : FoodFormat.number(
                (p.servings! * 100).roundToDouble() / 100 < 0.1
                    ? 0.1
                    : (p.servings! * 100).roundToDouble() / 100,
              );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final portion = _portion;
    final preview =
        portion.ok ? PortionPreview.scale(_row, portion.servings!) : null;
    final rows = widget.food.nutrition;
    String g(double lo, double hi) => '${FoodFormat.range(lo, hi)} g';

    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('portion.sheet'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.md,
          FitSpacing.screen,
          FitSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The food.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(widget.food.name, style: textTheme.titleLarge),
                ),
                const SizedBox(width: FitSpacing.sm),
                FoodSourceBadge(food: widget.food),
              ],
            ),
            const SizedBox(height: FitSpacing.md),
            // Which row the amount is of.
            Text('PORTION OF', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            ChoiceWrap<FoodNutrition>(
              keyPrefix: 'portion.row',
              options: rows,
              selected: _row,
              label: FoodFormat.serving,
              onSelect: (r) => setState(() {
                _row = r;
                _asGrams = r.basis == NutritionBasis.per100g;
                _amount.text = _asGrams ? '100' : '1';
              }),
            ),
            if (_gramsPossible &&
                _row.basis == NutritionBasis.perServing) ...<Widget>[
              const SizedBox(height: FitSpacing.sm),
              SegmentBar<bool>(
                keyPrefix: 'portion.mode',
                height: 44,
                selected: _asGrams,
                onSelect: _setMode,
                segments: const [
                  Segment(value: false, label: 'Servings'),
                  Segment(value: true, label: 'Grams'),
                ],
              ),
            ],
            const SizedBox(height: FitSpacing.md),
            // How much: [ - ]  1.5  [ + ]
            Row(
              children: <Widget>[
                IconButton.outlined(
                  key: const ValueKey('portion.less'),
                  tooltip: 'Less',
                  onPressed: () => _step(_asGrams ? -10 : -0.5),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: FitSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('portion.amount'),
                    controller: _amount,
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      helperText: _asGrams ? 'grams' : '× ${_row.servingLabel}',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                IconButton.outlined(
                  key: const ValueKey('portion.more'),
                  tooltip: 'More',
                  onPressed: () => _step(_asGrams ? 10 : 0.5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: FitSpacing.md),
            // What it will log — a PREVIEW (owner J10); the server computes
            // what is stored, from the food as it is when the log arrives.
            if (!portion.ok)
              Text(
                portion.problem!,
                key: const ValueKey('portion.problem'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Text('PREVIEW', style: textTheme.labelSmall),
                  const SizedBox(width: FitSpacing.sm),
                  if (portion.grams != null)
                    Text(
                      '${FoodFormat.number(portion.grams!)} g',
                      key: const ValueKey('portion.grams'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Wrap(
                spacing: FitSpacing.lg,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  MacroCell(
                    label: 'Calories',
                    value:
                        '${FoodFormat.range(preview!.kcalLow, preview.kcalHigh)} kcal',
                    valueKey: const ValueKey('portion.preview.kcal'),
                  ),
                  MacroCell(
                    label: 'Protein',
                    value: g(preview.proteinLow, preview.proteinHigh),
                    valueKey: const ValueKey('portion.preview.protein'),
                  ),
                  MacroCell(
                    label: 'Carbs',
                    value: g(preview.carbLow, preview.carbHigh),
                  ),
                  MacroCell(
                    label: 'Fat',
                    value: g(preview.fatLow, preview.fatHigh),
                  ),
                  MacroCell(
                    label: 'Fibre',
                    value: preview.fibreLow == null
                        ? 'Not known'
                        : g(preview.fibreLow!, preview.fibreHigh!),
                    muted: preview.fibreLow == null,
                    valueKey: const ValueKey('portion.preview.fibre'),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'Preview only — FITOS works out what is logged when it saves.',
                key: const ValueKey('portion.preview.note'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ],
            if (widget.footer != null) ...<Widget>[
              const SizedBox(height: FitSpacing.sm),
              widget.footer!,
            ],
            const SizedBox(height: FitSpacing.md),
            Text('MEAL', style: textTheme.labelSmall),
            MealSlotBar(
              keyPrefix: 'portion.slot',
              selected: _slot,
              onSelect: (s) => setState(() => _slot = s),
            ),
            const SizedBox(height: FitSpacing.lg),
            FilledButton(
              key: const ValueKey('portion.log'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: portion.ok
                  ? () => Navigator.of(context).pop(
                        PortionChoice(
                          row: _row,
                          portion: portion,
                          asGrams: _asGrams,
                          slot: _slot,
                        ),
                      )
                  : null,
              child: Text('Log to ${_slot.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
