import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/food_log.dart';

/// Compact controls for the Phase 8 logging screens. Each sizes to its
/// content or shares the row equally — never a full-width stack of labels —
/// and every target is at least 44 dp.

IconData mealSlotIcon(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => Icons.free_breakfast_outlined,
      MealSlot.lunch => Icons.lunch_dining_outlined,
      MealSlot.snacks => Icons.cookie_outlined,
      MealSlot.dinner => Icons.dinner_dining_outlined,
    };

/// One segment of a [SegmentBar].
class Segment<T> {
  const Segment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Equal-width segments in one row: an icon over a short label, the chosen
/// one in ink with a 2 px rule, the rest ink60 over a hairline. Labels scale
/// down rather than wrap or overflow on a narrow phone.
class SegmentBar<T> extends StatelessWidget {
  const SegmentBar({
    required this.segments,
    required this.selected,
    required this.onSelect,
    required this.keyPrefix,
    this.height = 56,
    super.key,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelect;
  final String keyPrefix;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Grows with the text scale (to 200 %, §6.8) from a 56 dp minimum; the
    // segments share the width and stretch to the tallest one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final s in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: s.value == selected,
                label: s.label,
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('$keyPrefix.${s.label}'),
                  onTap: () => onSelect(s.value),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: s.value == selected
                              ? FitColors.ink
                              : FitColors.rule,
                          width: s.value == selected ? 2 : 1,
                        ),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (s.icon != null)
                            Icon(
                              s.icon,
                              size: 20,
                              color: s.value == selected
                                  ? FitColors.ink
                                  : FitColors.ink60,
                            ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.label,
                              maxLines: 1,
                              style: textTheme.bodyLarge?.copyWith(
                                color: s.value == selected
                                    ? FitColors.ink
                                    : FitColors.ink60,
                                fontWeight: s.value == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The four meals as one compact bar.
class MealSlotBar extends StatelessWidget {
  const MealSlotBar({
    required this.selected,
    required this.onSelect,
    required this.keyPrefix,
    super.key,
  });

  final MealSlot selected;
  final ValueChanged<MealSlot> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => SegmentBar<MealSlot>(
        keyPrefix: keyPrefix,
        selected: selected,
        onSelect: onSelect,
        segments: [
          for (final s in MealSlot.values)
            Segment(value: s, label: s.label, icon: mealSlotIcon(s)),
        ],
      );
}

/// Content-width choices that wrap (a food's rows: "Per 100 g", "1 tbsp").
class ChoiceWrap<T> extends StatelessWidget {
  const ChoiceWrap({
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelect,
    required this.keyPrefix,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: FitSpacing.sm,
      runSpacing: FitSpacing.sm,
      children: <Widget>[
        for (final o in options)
          Semantics(
            button: true,
            selected: o == selected,
            child: InkWell(
              key: ValueKey('$keyPrefix.${label(o)}'),
              onTap: () => onSelect(o),
              borderRadius: const BorderRadius.all(FitRadius.medium),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: FitSpacing.md,
                  vertical: FitSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: o == selected ? FitColors.ink : null,
                  border: Border.all(
                    color: o == selected ? FitColors.ink : FitColors.rule,
                  ),
                  borderRadius: const BorderRadius.all(FitRadius.medium),
                ),
                child: Text(
                  label(o),
                  style: textTheme.bodyLarge?.copyWith(
                    color: o == selected ? FitColors.paper : FitColors.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A labelled number in a strip (Protein 38–45 g left).
class MacroCell extends StatelessWidget {
  const MacroCell({
    required this.label,
    required this.value,
    this.caption,
    this.valueKey,
    this.muted = false,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final Key? valueKey;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: textTheme.labelSmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            style: textTheme.titleMedium?.copyWith(
              color: muted ? FitColors.ink60 : FitColors.ink,
            ),
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
      ],
    );
  }
}
