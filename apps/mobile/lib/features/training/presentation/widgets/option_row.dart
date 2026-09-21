import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// A labelled row of equal-width choices — "2 3 4 5 6" — in the hairline
/// language: the chosen value is ink with a 2 px underline, the rest ink60.
/// Single select; every option is a 48 px target.
class OptionRow<T> extends StatelessWidget {
  const OptionRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.text,
    this.enabled = true,
    this.keyPrefix,
    super.key,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String Function(T) text;
  final bool enabled;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        Row(
          children: <Widget>[
            for (final option in options)
              Expanded(
                child: _Choice(
                  key: keyPrefix == null
                      ? null
                      : ValueKey('$keyPrefix.${text(option)}'),
                  text: text(option),
                  on: option == selected,
                  enabled: enabled,
                  onTap: () => onSelect(option),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.on,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String text;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
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
            style: textTheme.titleLarge?.copyWith(
              color: on ? FitColors.ink : FitColors.ink60,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
