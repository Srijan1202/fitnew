import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// A destination that exists on the bar before its feature does. Honest
/// and quiet: the name, "Coming soon", one line on what will live here.
/// No fake content, no disabled controls (§6, never fake functionality).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    required this.title,
    required this.blurb,
    super.key,
  });

  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title.toUpperCase(), style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Text('Coming soon', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.lg),
              const Divider(color: FitColors.rule, height: 1),
              const SizedBox(height: FitSpacing.afterRule),
              Text(blurb, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// The remaining placeholder, named once so the router and tests agree.
class MarketplacePlaceholderScreen extends StatelessWidget {
  const MarketplacePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
        title: 'Marketplace',
        blurb: 'Supplements and gear from campus vendors will live here.',
      );
}
