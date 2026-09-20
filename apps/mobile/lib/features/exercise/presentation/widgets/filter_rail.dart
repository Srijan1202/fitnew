import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// A horizontal row of toggles in the §6 language: text with a hairline
/// underline, ink when on, no pills, no filled chips. Colour is reserved for
/// meaning (§6.2), and "selected" is a state, not a meaning.
class FilterRail<T> extends StatelessWidget {
  const FilterRail({
    required this.options,
    required this.isSelected,
    required this.onTap,
    required this.label,
    this.railKey,
    super.key,
  });

  final List<T> options;
  final bool Function(T) isSelected;
  final ValueChanged<T> onTap;
  final String Function(T) label;

  /// Prefix for per-option keys (`<railKey>.<wire>`), for tests.
  final String? railKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
      child: Row(
        children: <Widget>[
          for (final option in options) ...<Widget>[
            _Toggle(
              key: railKey == null
                  ? null
                  : ValueKey('$railKey.${label(option)}'),
              text: label(option),
              on: isSelected(option),
              onTap: () => onTap(option),
              textTheme: textTheme,
            ),
            const SizedBox(width: FitSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.text,
    required this.on,
    required this.onTap,
    required this.textTheme,
    super.key,
  });

  final String text;
  final bool on;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? FitColors.ink : FitColors.rule,
                width: on ? 2 : 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: textTheme.titleMedium?.copyWith(
              color: on ? FitColors.ink : FitColors.ink60,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
