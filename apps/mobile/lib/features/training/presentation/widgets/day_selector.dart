import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/program.dart';

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
      decoration: const BoxDecoration(
        color: FitColors.paper,
        border: Border(bottom: BorderSide(color: FitColors.rule)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: FitSpacing.sm,
        vertical: FitSpacing.xs,
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
    final color = selected
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
        borderRadius: const BorderRadius.all(FitRadius.small),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
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
              _Dot(selected: selected, isRest: isRest),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.selected, required this.isRest});

  final bool selected;
  final bool isRest;

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
        color: selected ? FitColors.ink : Colors.transparent,
        border: Border.all(color: selected ? FitColors.ink : FitColors.ink60),
      ),
    );
  }
}
