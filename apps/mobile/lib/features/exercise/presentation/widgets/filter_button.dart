import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// "Muscle ▾" / "Chest ▾": a filter that opens a sheet. Hairline border,
/// ink text; a chosen value makes it bold — a state, not a colour.
class FilterButton extends StatelessWidget {
  const FilterButton({
    required this.label,
    required this.onTap,
    this.value,
    super.key,
  });

  final String label;

  /// What is currently chosen, or null for "any".
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final on = value != null;
    return Semantics(
      button: true,
      selected: on,
      label: on ? '$label: $value' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(FitRadius.medium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: FitSpacing.sm + 2),
          decoration: BoxDecoration(
            border: Border.all(color: on ? FitColors.ink : FitColors.rule),
            borderRadius: const BorderRadius.all(FitRadius.medium),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  on ? value! : label,
                  style: textTheme.titleMedium?.copyWith(
                    color: FitColors.ink,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: FitSpacing.xs),
              const Icon(Icons.expand_more, size: 18, color: FitColors.ink60),
            ],
          ),
        ),
      ),
    );
  }
}
