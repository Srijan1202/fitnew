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
                const _Note(
                  key: ValueKey('rec.failed'),
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
          const _Note(
            key: ValueKey('rec.nothingSafe'),
            text:
                'Nothing at this meal is confirmed safe for your diet and allergies, so there is no plate.',
            colour: FitColors.oxide,
          ),
          whyNot,
        ];
      case RecommendationStatus.nothingFits:
        return [
          ...logged,
          safety,
          const _Note(
            key: ValueKey('rec.nothingFits'),
            text: 'No dish at this meal fits what is left of your calories.',
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
            const _Note(
              key: ValueKey('rec.inferred'),
              text:
                  'Based on the inferred menu — the mess has not published this day.',
              colour: FitColors.amber,
            ),
          const SizedBox(height: FitSpacing.sm),
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

/// The active hard filters, and what "free" means (requirement 4).
class _SafetyLine extends StatelessWidget {
  const _SafetyLine({required this.rec});

  final MessRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: const ValueKey('rec.filters'),
      onTap: () => context.push(Routes.profileFood),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: FitColors.pine,
                ),
                const SizedBox(width: FitSpacing.xs),
                Expanded(
                  child: Text(
                    ReasonText.filters(rec.diet, rec.allergies),
                    key: const ValueKey('rec.filters.text'),
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: FitColors.ink60,
                ),
              ],
            ),
            if (rec.allergies.isNotEmpty)
              Text(
                'Ingredient status confirmed by FITOS rules from dish names. Shared mess kitchens can have cross-contact FITOS cannot rule out.',
                key: const ValueKey('rec.crossContact'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shortfall extends StatelessWidget {
  const _Shortfall({required this.rec});

  final MessRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String g(double v) => FoodFormat.number(v);
    final p = rec.proteinShortfall;
    final k = rec.kcalShortfall;
    return Container(
      key: const ValueKey('rec.shortfall'),
      margin: const EdgeInsets.only(top: FitSpacing.sm),
      padding: const EdgeInsets.all(FitSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: FitColors.amber, width: 3)),
        color: FitColors.paper2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'FALLS SHORT',
            style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
          ),
          if (p != null)
            Text(
              '${g(p.gapLow)}–${g(p.gapHigh)} g protein below this meal\'s ${g(p.target)} g.'
              '${p.menuCanMeet ? '' : ' No plate from this menu reaches it (at most ${g(p.menuMax)} g).'}',
              key: const ValueKey('rec.shortfall.protein'),
              style: textTheme.bodyMedium,
            ),
          if (k != null)
            Text(
              '${g(k.gapLow)}–${g(k.gapHigh)} kcal below this meal\'s ${g(k.target)} kcal.'
              '${k.menuCanMeet ? '' : ' No plate from this menu reaches it (at most ${g(k.menuMax)} kcal).'}',
              key: const ValueKey('rec.shortfall.kcal'),
              style: textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _PlateRow extends StatelessWidget {
  const _PlateRow({
    required this.index,
    required this.item,
    required this.diet,
  });

  final int index;
  final PlateItem item;
  final DietClass? diet;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dim = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    return Padding(
      key: ValueKey('rec.item.${item.dishSlug}'),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text('$index', style: textTheme.titleMedium),
          ),
          if (diet != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: FitSpacing.xs),
              child: DietMark(diet: diet!),
            ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                Text(
                  '${item.servings} × ${item.servingLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dim,
                ),
              ],
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${EatFormat.kcal(item.macros.kcalLow, item.macros.kcalHigh)} kcal',
                    maxLines: 1,
                    style: textTheme.titleMedium,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${EatFormat.grams(item.macros.proteinLow, item.macros.proteinHigh)} protein',
                    maxLines: 1,
                    style: dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherPlate extends StatelessWidget {
  const _OtherPlate({required this.plate, required this.onTap});

  final Plate plate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('rec.plate.${plate.rank}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plate.items
                          .map((i) => '${i.name} ×${i.servings}')
                          .join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      '${EatFormat.kcal(plate.totals.kcalLow, plate.totals.kcalHigh)} kcal · ${EatFormat.grams(plate.totals.proteinLow, plate.totals.proteinHigh)} protein',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Why not …?": every dish that is not on a plate, and why.
class _WhyNot extends StatelessWidget {
  const _WhyNot({
    required this.rec,
    required this.open,
    required this.onToggle,
  });

  final MessRecommendation rec;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final off = rec.dishes.where((d) => !d.onPlate).toList();
    if (off.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('rec.whyNot'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onToggle,
            icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text('Why not the other ${off.length} dishes?'),
          ),
        ),
        if (open)
          for (final d in off)
            Padding(
              key: ValueKey('rec.why.${d.dishSlug}'),
              padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: DietMark(diet: d.diet),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(d.name, style: textTheme.bodyLarge),
                        for (final r in d.reasons)
                          Text(
                            ReasonText.dish(r, rec.diet),
                            style: textTheme.bodyMedium
                                ?.copyWith(color: FitColors.ink60),
                          ),
                        // Each "/" alternative, classified on its own (D3).
                        for (final a in d.alternatives)
                          Text(
                            'or ${a.name} — ${a.diet.label.toLowerCase()}',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: FitColors.ink60),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.colour = FitColors.ink60, super.key});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
        child: Text(
          text,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: colour),
        ),
      );
}

/// The thali: a plate rim with one katori per dish, numbered to match the
/// rows below, each with its diet colour. Drawn, not an image; the palette
/// is the design system's (§6.2).
class ThaliView extends StatelessWidget {
  const ThaliView({required this.items, required this.diets, super.key});

  final List<PlateItem> items;
  final Map<String, DietClass> diets;

  @override
  Widget build(BuildContext context) {
    final label = [
      for (final (i, item) in items.indexed)
        '${i + 1}: ${item.name}, ${item.servings} × ${item.servingLabel}',
    ].join('; ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 200.0);
        return Semantics(
          label: 'Plate of ${items.length} dishes. $label',
          excludeSemantics: true,
          child: CustomPaint(
            size: Size.square(size),
            painter: _ThaliPainter(
              count: items.length,
              colours: [
                for (final i in items) _dietColour(diets[i.dishSlug]),
              ],
              textStyle: Theme.of(context).textTheme.titleMedium!,
            ),
          ),
        );
      },
    );
  }

  static Color _dietColour(DietClass? d) => switch (d) {
        DietClass.veg => FitColors.pine,
        DietClass.egg => FitColors.amber,
        DietClass.nonveg => FitColors.oxide,
        _ => FitColors.ink35,
      };
}

class _ThaliPainter extends CustomPainter {
  _ThaliPainter({
    required this.count,
    required this.colours,
    required this.textStyle,
  });

  final int count;
  final List<Color> colours;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = FitColors.ink;
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FitColors.rule;
    canvas
      ..drawCircle(c, r - 1, Paint()..color = FitColors.paper2)
      ..drawCircle(c, r - 1, rim)
      ..drawCircle(c, r * 0.9, hairline);
    if (count == 0) return;
    final katori = count == 1 ? r * 0.34 : r * (count > 5 ? 0.2 : 0.24);
    for (var i = 0; i < count; i++) {
      final at = count == 1
          ? c
          : c +
              Offset.fromDirection(
                -math.pi / 2 + 2 * math.pi * i / count,
                r * 0.56,
              );
      canvas
        ..drawCircle(at, katori, Paint()..color = FitColors.paper)
        ..drawCircle(
          at,
          katori,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colours[i],
        );
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ThaliPainter old) =>
      old.count != count || old.colours != colours;
}
