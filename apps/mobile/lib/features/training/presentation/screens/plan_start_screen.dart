import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';

/// Three ways to get a programme (Phase 4 rework): three deliberate modes,
/// each a full-width panel with a number, a name and one honest sentence.
/// Shown when there is no programme, and from "Change programme".
class PlanStartScreen extends StatelessWidget {
  const PlanStartScreen({this.canGoBack = false, super.key});

  /// From the plan's menu there is a plan to go back to; on first use there is not.
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.screen,
            FitSpacing.xl,
          ),
          children: <Widget>[
            Text('TRAINING PLAN', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('How do you want to train?', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              canGoBack
                  ? 'Choosing a new plan replaces the current one. The old one is kept, not deleted.'
                  : 'Pick one. You can change it any time, and edit any day of it.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: FitSpacing.lg),
            _Mode(
              modeKey: const ValueKey('start.generate'),
              number: '01',
              title: 'Generate',
              body:
                  'FitOS builds a week from your goal, level, days, equipment and limitations. Every exercise comes with its reason. Adapts as you train.',
              action: 'Generate for me',
              onTap: () => context.push(Routes.planGenerate),
            ),
            _Mode(
              modeKey: const ValueKey('start.professional'),
              number: '02',
              title: 'Professional',
              body:
                  'Recognised structures — push / pull / legs, upper / lower, bro split and more — filled with exercises you can actually do. Preview first, then make it yours.',
              action: 'Browse structures',
              onTap: () => context.push(Routes.planTemplates),
            ),
            _Mode(
              modeKey: const ValueKey('start.custom'),
              number: '03',
              title: 'Custom',
              body:
                  'Your days, your muscle groups, your exercises, your sets and starting weights. Built step by step.',
              action: 'Build my own',
              onTap: () => context.push(Routes.planCustom),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode({
    required this.modeKey,
    required this.number,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final Key modeKey;
  final String number;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: modeKey,
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: FitColors.ink, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.lg),
        margin: const EdgeInsets.only(bottom: FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(number, style: textTheme.labelSmall),
                const SizedBox(width: FitSpacing.md),
                Text(title, style: textTheme.displaySmall),
              ],
            ),
            const SizedBox(height: FitSpacing.sm),
            Text(body, style: textTheme.bodyMedium),
            const SizedBox(height: FitSpacing.md),
            Row(
              children: <Widget>[
                Text(action, style: textTheme.titleMedium),
                const SizedBox(width: FitSpacing.xs),
                const Icon(Icons.arrow_forward, size: 18, color: FitColors.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
