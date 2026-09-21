import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';

/// Professional: the structure library. Each row is a structure people
/// already know — days, what each day trains, who runs it, how long. No
/// claims about which is best. Tapping opens a preview; nothing is applied
/// from here.
class TemplateLibraryScreen extends ConsumerWidget {
  const TemplateLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrHome())),
      body: SafeArea(
        child: async.when(
          loading: () => const _LibrarySkeleton(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(templatesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (templates) => ListView(
            padding: const EdgeInsets.only(bottom: FitSpacing.xl),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('PROFESSIONAL', style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      'Choose a training structure',
                      style: textTheme.displaySmall,
                    ),
                    const SizedBox(height: FitSpacing.sm),
                    Text(
                      'Established splits, filled with exercises you can do with your equipment. Preview before you commit.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              for (final t in templates) _TemplateRow(template: t),
              const Divider(color: FitColors.rule, height: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final ProgramTemplate template;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = template;
    final muscles = <String>{
      for (final d in t.days) ...d.muscles.map((m) => m.label),
    };
    return Column(
      children: <Widget>[
        const Divider(color: FitColors.rule, height: 1),
        InkWell(
          key: ValueKey('template.${t.slug}'),
          onTap: () => context.push(Routes.planTemplate(t.slug)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FitSpacing.screen,
              vertical: FitSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${t.daysPerWeek}',
                        style: textTheme.displaySmall?.copyWith(height: 1),
                      ),
                      Text(
                        'DAYS',
                        style: textTheme.labelSmall
                            ?.copyWith(color: FitColors.ink60),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(t.name, style: textTheme.titleLarge),
                      const SizedBox(height: FitSpacing.xs),
                      Text(
                        t.days.map((d) => d.sessionName).join(' · '),
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: FitSpacing.xs),
                      Text(
                        '${t.level.label} · ~${t.approxMinutes} min · ${muscles.length} muscle groups',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.ink60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: FitColors.ink60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 110, height: 11, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.sm),
          Container(width: 240, height: 28, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.lg),
          for (var i = 0; i < 6; i++) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.md),
            Container(width: 200, height: 18, color: FitColors.paper2),
            const SizedBox(height: FitSpacing.md),
          ],
        ],
      ),
    );
  }
}
