import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../../shared/widgets/fit_glass.dart';

/// The frame every onboarding screen sits in: eyebrow with the step count,
/// title, optional lede, the screen's body, then a back link and the primary
/// action. Submit/busy/error handling lives here once rather than six times.
///
/// No progress ring (§6.1): the eyebrow says the step, and (owner,
/// 2026-10-22) a thin line across the very top fills in the glow colour.
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
      body: FitBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              FitProgressLine(step: screenNumber, total: totalScreens),
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
                      const FitRule(),
                      SizedBox(height: fitGlass ? 0 : FitSpacing.afterRule),
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
                          ? SizedBox.square(
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
    return _ChoiceGroup(
      rows: <Widget>[
        for (final option in options)
          _ChoiceRow(
            selected: option == selected,
            enabled: enabled,
            onTap: () => onSelect(option),
            title: label(option),
            subtitle: blurb?.call(option),
            textTheme: textTheme,
          ),
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
    return _ChoiceGroup(
      rows: <Widget>[
        for (final option in options)
          _ChoiceRow(
            selected: selected.contains(option),
            enabled: enabled,
            onTap: () => onToggle(option),
            title: label(option),
            textTheme: textTheme,
            multi: true,
          ),
      ],
    );
  }
}

/// The rows of a choice list: hairlines under each on Paper; one rounded
/// group with inset hairlines on glass (ADR-029).
class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (!fitGlass) {
      return Column(
        children: <Widget>[
          for (final r in rows) ...<Widget>[
            r,
            Divider(color: FitColors.rule, height: 1),
          ],
        ],
      );
    }
    return FitBlock(
      child: Column(
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                color: FitColors.rule.withValues(alpha: 0.6),
                height: 1,
                indent: FitSpacing.md,
                endIndent: FitSpacing.md,
              ),
            rows[i],
          ],
        ],
      ),
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
    this.multi = false,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final TextTheme textTheme;

  /// A multi-select row: a square check rather than a round one (glass).
  final bool multi;

  @override
  Widget build(BuildContext context) {
    if (fitGlass) return _glass();
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

  /// ADR-029: the chosen row tinted, with an accent check on the right.
  Widget _glass() {
    final mark = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? FitColors.accent : Colors.transparent,
        shape: multi ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multi ? const BorderRadius.all(Radius.circular(7)) : null,
        border: Border.all(
          color: selected ? FitColors.accent : FitColors.ink35,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: FitColors.onAccent)
          : null,
    );
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: selected
              ? FitPalette.current.glow.withValues(alpha: 0.10)
              : Colors.transparent,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
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
              const SizedBox(width: FitSpacing.sm),
              mark,
            ],
          ),
        ),
      ),
    );
  }
}
