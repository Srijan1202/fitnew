import 'dart:ui' show ImageFilter;

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
/// Phase 12: the fifth tab is Progress (Progress & Recovery), which replaced
/// the Market placeholder.
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
    label: 'Progress',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    location: '/progress',
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
        // Phase 6.5: the bar floats over the content, so the body extends
        // under it; screens keep their bottom SafeArea / padding.
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: FitBottomBar(selected: index, onSelect: _select),
      ),
    );
  }
}

/// The bar itself, in the §6 language and, since Phase 6.5, floating: a
/// translucent paper surface with a light blur, a hairline border, a
/// restrained shadow, corners at the medium radius (not a pill), 60 px of
/// content above the bottom safe area; ink for the selected destination,
/// ink35 for the rest; no filled indicator pill. Touch targets stay the
/// full item height.
class FitBottomBar extends StatelessWidget {
  const FitBottomBar({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  static const double contentHeight = 60;
  static const double sideMargin = 12;
  static const double bottomMargin = 10;

  /// Paper at 88%: the content shows through, the labels stay legible.
  static const Color surface = Color(0xE0EDEBE4);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: bottomMargin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: sideMargin),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(FitRadius.medium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              key: const ValueKey('nav.bar'),
              height: contentHeight,
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: FitColors.rule),
                borderRadius: const BorderRadius.all(FitRadius.medium),
              ),
              decoration: const BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.all(FitRadius.medium),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A17171A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
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
