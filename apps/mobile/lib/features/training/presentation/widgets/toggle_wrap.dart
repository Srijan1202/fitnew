import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Multi-select toggles that wrap — muscle groups, weekdays. Hairline
/// underline off, 2 px ink underline on; no filled chips. 44 px targets.
class ToggleWrap<T> extends StatelessWidget {
  const ToggleWrap({
    required this.options,
    required this.isSelected,
    required this.onTap,
    required this.label,
    this.enabled = true,
    this.keyPrefix,
    super.key,
  });

  final List<T> options;
  final bool Function(T) isSelected;
  final ValueChanged<T> onTap;
  final String Function(T) label;
  final bool enabled;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: FitSpacing.md,
      runSpacing: FitSpacing.xs,
      children: <Widget>[
        for (final option in options)
          _Toggle(
            key: keyPrefix == null
                ? null
                : ValueKey('$keyPrefix.${label(option)}'),
            text: label(option),
            on: isSelected(option),
            enabled: enabled,
            onTap: () => onTap(option),
            textTheme: textTheme,
          ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.text,
    required this.on,
    required this.enabled,
    required this.onTap,
    required this.textTheme,
    super.key,
  });

  final String text;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
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
