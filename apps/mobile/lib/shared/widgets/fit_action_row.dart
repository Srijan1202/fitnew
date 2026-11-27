import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// One thing a card lets you do.
class FitAction {
  const FitAction(
    this.label,
    this.onPressed, {
    required this.key,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Key key;
  final IconData? icon;

  /// Drawn in oxide (leaving, ending, removing).
  final bool destructive;
}

/// Beta 6.7 (A4): a card's actions on one line. The first two are text
/// buttons; any more go in a ⋯ menu at the end, so a card never ends in a
/// stack of links.
class FitActionRow extends StatelessWidget {
  const FitActionRow({
    super.key,
    required this.actions,
    this.menuKey = const ValueKey('actions.more'),
    this.shown = 2,
  });

  final List<FitAction> actions;
  final Key menuKey;

  /// How many show as buttons before the rest go in the menu.
  final int shown;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final inline = actions.take(shown).toList();
    final rest = actions.skip(shown).toList();
    return Row(
      children: [
        for (final a in inline)
          TextButton.icon(
            key: a.key,
            onPressed: a.onPressed,
            style: TextButton.styleFrom(
              foregroundColor: a.destructive ? FitColors.oxide : null,
              padding: const EdgeInsets.symmetric(horizontal: FitSpacing.sm),
            ),
            icon: a.icon == null ? null : Icon(a.icon, size: 18),
            label: Text(a.label),
          ),
        const Spacer(),
        if (rest.isNotEmpty)
          PopupMenuButton<int>(
            key: menuKey,
            tooltip: 'More',
            icon: Icon(Icons.more_horiz, color: FitColors.ink60),
            onSelected: (i) => rest[i].onPressed(),
            itemBuilder: (_) => [
              for (final (i, a) in rest.indexed)
                PopupMenuItem<int>(
                  key: a.key,
                  value: i,
                  child: Text(
                    a.label,
                    style: a.destructive
                        ? TextStyle(color: FitColors.oxide)
                        : null,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
