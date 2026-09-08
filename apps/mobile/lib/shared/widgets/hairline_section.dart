import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Section separation by a 1px hairline plus 14px, not by card margins (§6.4).
///
/// This exists so no screen reaches for a Card. The prohibited list in §6.1
/// starts with "card soup" and "uniform rounded cards"; giving the layout a
/// first-class separator makes the correct thing the easy thing.
class HairlineSection extends StatelessWidget {
  const HairlineSection({
    required this.child,
    this.label,
    super.key,
  });

  final Widget child;

  /// Optional eyebrow above the rule.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(color: FitColors.rule, thickness: 1, height: 1),
        const SizedBox(height: FitSpacing.afterRule),
        if (label != null) ...<Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: FitSpacing.sm),
        ],
        child,
      ],
    );
  }
}
