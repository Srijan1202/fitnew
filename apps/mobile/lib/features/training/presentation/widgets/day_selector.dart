import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/program.dart';
import '../../../../shared/widgets/fit_glass.dart';

/// MON … SUN. The selected day is ink with a solid dot; other training days
/// a hollow dot; rest days a faint dash. Fixed at the top of the workout
/// screen so "where am I in the week" is always one glance.
class DaySelector extends StatelessWidget {
  const DaySelector({
    required this.days,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Seven, Monday first.
  final List<ProgramDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      // ADR-029: a floating strip on glass; the hairline-bottomed bar on Paper.
      margin: fitGlass
          ? const EdgeInsets.fromLTRB(12, FitSpacing.sm, 12, 0)
          : EdgeInsets.zero,
      decoration: fitGlass
          ? FitBlock.decoration(radius: const Radius.circular(20))
          : BoxDecoration(
              color: FitColors.paper,
              border: Border(bottom: BorderSide(color: FitColors.rule)),
            ),
      padding: EdgeInsets.symmetric(
        horizontal: fitGlass ? 6 : FitSpacing.sm,
        vertical: fitGlass ? 6 : FitSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          for (final day in days)
            Expanded(
              child: _DayTab(
                key: ValueKey('day.tab.${day.dayOfWeek}'),
                label: kWeekdayLabels[day.dayOfWeek - 1]
                    .substring(0, 3)
                    .toUpperCase(),
                selected: day.dayOfWeek == selected,
                isRest: day.isRest,
                onTap: () => onSelect(day.dayOfWeek),
                textTheme: textTheme,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.label,
    required this.selected,
    required this.isRest,
    required this.onTap,
    required this.textTheme,
    super.key,
  });

  final String label;
  final bool selected;
  final bool isRest;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final pill = fitGlass && selected;
    final color = pill
        ? FitColors.onAccent
        : selected
            ? FitColors.ink
            : isRest
                ? FitColors.ink35
                : FitColors.ink60;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${isRest ? ', rest' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.all(FitRadius.small),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
          decoration: pill
              ? BoxDecoration(
                  color: FitColors.accent,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: FitSpacing.xs),
              _Dot(selected: selected, isRest: isRest, colour: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.selected,
    required this.isRest,
    required this.colour,
  });

  final bool selected;
  final bool isRest;

  /// The selected day's colour (on the accent pill, the type on it).
  final Color colour;

  @override
  Widget build(BuildContext context) {
    if (isRest && !selected) {
      return Container(width: 8, height: 2, color: FitColors.rule);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colour : Colors.transparent,
        border: Border.all(color: selected ? colour : FitColors.ink60),
      ),
    );
  }
}
