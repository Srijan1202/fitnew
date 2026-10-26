part of 'what_to_eat.dart';

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
                Icon(
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
                Icon(
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
      decoration: BoxDecoration(
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
              '${FoodFormat.capitalised(FoodFormat.about(p.gapLow, p.gapHigh))} g protein below this meal\'s ${g(p.target)} g.'
              '${p.menuCanMeet ? '' : ' No plate from this menu reaches it (at most ${g(p.menuMax)} g).'}',
              key: const ValueKey('rec.shortfall.protein'),
              style: textTheme.bodyMedium,
            ),
          if (k != null)
            Text(
              '${FoodFormat.capitalised(FoodFormat.about(k.gapLow, k.gapHigh))} kcal below this meal\'s ${g(k.target)} kcal.'
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
              Icon(Icons.chevron_right, color: FitColors.ink60),
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
  const _Note({required this.text, this.colour, super.key});

  final String text;

  /// Ink 60 unless given.
  final Color? colour;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colour ?? FitColors.ink60),
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
