import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';

/// One destination on the bottom bar. Order is the branch order.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String location;
}

/// The five destinations of the app shell (owner decision 2026-09-21).
/// AI, Nutrition and Market are placeholders until their phases.
const List<ShellDestination> kShellDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    location: '/',
  ),
  ShellDestination(
    label: 'Training',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
    location: '/plan',
  ),
  ShellDestination(
    label: 'AI',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    location: '/chat',
  ),
  ShellDestination(
    label: 'Nutrition',
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
    location: '/nutrition',
  ),
  ShellDestination(
    label: 'Market',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    location: '/market',
  ),
];

/// The app shell: a persistent bottom bar over five stateful branches
/// (`StatefulShellRoute.indexedStack`), so switching tabs keeps each tab's
/// state and scroll position. Deeper screens (editors, the picker, the
/// library, profile) are pushed on the ROOT navigator above the shell and
/// hide the bar; they never nest a second bar.
///
/// Android back is deterministic: a deeper screen pops; a non-home tab at
/// its root returns to Home; Home at its root leaves the app. go_router pops
/// the innermost navigator that can pop before it reaches this widget, so
/// the [PopScope] here only ever sees "nothing deeper to pop".
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the current tab again returns it to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: FitBottomBar(selected: index, onSelect: _select),
      ),
    );
  }
}

/// The bar itself, in the §6 language: paper, a hairline on top, ink for
/// the selected destination, ink35 for the rest; no filled indicator pill.
class FitBottomBar extends StatelessWidget {
  const FitBottomBar({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: FitColors.paper,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FitColors.rule)),
          ),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < kShellDestinations.length; i++)
                Expanded(
                  child: _BarItem(
                    key: ValueKey('nav.${kShellDestinations[i].label}'),
                    destination: kShellDestinations[i],
                    on: i == selected,
                    onTap: () => onSelect(i),
                    textTheme: textTheme,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.on,
    required this.onTap,
    required this.textTheme,
    super.key,
  });

  final ShellDestination destination;
  final bool on;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = on ? FitColors.ink : FitColors.ink35;
    return Semantics(
      button: true,
      selected: on,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              on ? destination.selectedIcon : destination.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
