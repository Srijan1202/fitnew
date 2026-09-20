import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';

/// The frame every onboarding screen sits in: eyebrow with the step count,
/// title, optional lede, the screen's body, then a back link and the primary
/// action. Submit/busy/error handling lives here once rather than six times.
///
/// No cards, no progress ring (§6.1). Progress is the eyebrow text.
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    required this.screenNumber,
    required this.title,
    required this.child,
    required this.onContinue,
    this.lede,
    this.onBack,
    this.busy = false,
    this.failure,
    this.continueLabel = 'Continue',
    this.canContinue = true,
    super.key,
  });

  final int screenNumber;
  final String title;
  final String? lede;
  final Widget child;
  final VoidCallback? onBack;
  final Future<void> Function() onContinue;
  final bool busy;
  final Failure? failure;
  final String continueLabel;
  final bool canContinue;

  static const int totalScreens = 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.lg,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'STEP $screenNumber OF $totalScreens',
                      style: textTheme.labelSmall,
                    ),
                    const SizedBox(height: FitSpacing.xs),
                    Text(title, style: textTheme.displaySmall),
                    if (lede != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.sm),
                      Text(lede!, style: textTheme.bodyMedium),
                    ],
                    const SizedBox(height: FitSpacing.lg),
                    const Divider(color: FitColors.rule, height: 1),
                    const SizedBox(height: FitSpacing.afterRule),
                    child,
                    if (failure != null) ...<Widget>[
                      const SizedBox(height: FitSpacing.md),
                      AuthFeedback.error(failure!.message),
                    ],
                  ],
                ),
              ),
            ),
            // Sticky footer: the action is always reachable without scrolling
            // past a long list.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitSpacing.screen,
                FitSpacing.sm,
                FitSpacing.screen,
                FitSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  if (onBack != null)
                    TextButton(
                      onPressed: busy ? null : onBack,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: busy || !canContinue ? null : onContinue,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FitColors.paper,
                            ),
                          )
                        : Text(continueLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single-select list in the §6 language: rows separated by hairlines, the
/// chosen row marked by a solid ink bar on the left. No radio circles, no
/// coloured fills — colour is reserved for meaning (§6.2).
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.label,
    this.blurb,
    this.enabled = true,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String Function(T) label;
  final String Function(T)? blurb;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final option in options) ...<Widget>[
          _ChoiceRow(
            selected: option == selected,
            enabled: enabled,
            onTap: () => onSelect(option),
            title: label(option),
            subtitle: blurb?.call(option),
            textTheme: textTheme,
          ),
          const Divider(color: FitColors.rule, height: 1),
        ],
      ],
    );
  }
}

/// Multi-select variant. Same visual language; a selected row shows the ink bar.
class MultiChoiceList<T> extends StatelessWidget {
  const MultiChoiceList({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.label,
    this.enabled = true,
    super.key,
  });

  final List<T> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;
  final String Function(T) label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final option in options) ...<Widget>[
          _ChoiceRow(
            selected: selected.contains(option),
            enabled: enabled,
            onTap: () => onToggle(option),
            title: label(option),
            textTheme: textTheme,
          ),
          const Divider(color: FitColors.rule, height: 1),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.title,
    required this.textTheme,
    this.subtitle,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          // 44pt minimum tap target (§6.8).
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 3,
                height: subtitle == null ? 24 : 40,
                color: selected ? FitColors.ink : Colors.transparent,
              ),
              const SizedBox(width: FitSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
