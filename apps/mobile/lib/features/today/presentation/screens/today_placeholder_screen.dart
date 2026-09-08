import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';

/// Phase 0 placeholder for the TODAY screen.
///
/// It renders the design language from §6 and nothing else. There is
/// deliberately no data, no API call and no computation here: §7.3 and §30
/// place every fitness calculation on the backend, and §"Never fake
/// functionality" forbids a mocked dashboard that looks like a working one.
///
/// The real screen is built in Phase 11, fed by `GET /today`.
class TodayPlaceholderScreen extends StatelessWidget {
  const TodayPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('FITOS', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),

              // Numbers are the hero (§6.3). This one is a literal, not a
              // computed value — the engine that produces it lives on the
              // backend and is wired in Phase 11.
              Text('Phase 0', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Foundation only. No features are wired yet.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.lg),

              const HairlineSection(
                label: 'What this screen proves',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Line(text: 'Paper ground, ink type, hairline sections.'),
                    _Line(text: 'Type scale carries hierarchy, not boxes.'),
                    _Line(text: 'Riverpod, go_router and the theme are wired.'),
                  ],
                ),
              ),
              const SizedBox(height: FitSpacing.lg),

              const HairlineSection(
                label: 'Semantic colour',
                child: Row(
                  children: <Widget>[
                    _Swatch(color: FitColors.pine, label: 'On track'),
                    SizedBox(width: FitSpacing.md),
                    _Swatch(color: FitColors.amber, label: 'Estimated'),
                    SizedBox(width: FitSpacing.md),
                    _Swatch(color: FitColors.oxide, label: 'Fatigue'),
                  ],
                ),
              ),
              const SizedBox(height: FitSpacing.lg),

              HairlineSection(
                label: 'Build',
                child: Text(
                  'Flavour ${Env.flavor} · API ${Env.apiBaseUrl}',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Every metric carries a screen-reader label — a colour or number without
    // one is meaningless aurally (§6.8).
    return Semantics(
      label: '$label indicator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(FitRadius.small),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
