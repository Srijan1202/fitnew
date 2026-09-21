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

/// A template materialised for this user, before anything is stored:
/// Monday → Push … with the exercises it would give you, and any shortfall
/// (in amber, verbatim). One button applies it; then it is yours to edit.
class TemplatePreviewScreen extends ConsumerStatefulWidget {
  const TemplatePreviewScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<TemplatePreviewScreen> createState() =>
      _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  bool _busy = false;
  Failure? _failure;

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref
        .read(programControllerProvider.notifier)
        .applyTemplate(widget.slug);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
    if (failure == null) context.go(Routes.plan);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(templatePreviewProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(
        leading:
            BackButton(onPressed: _busy ? null : () => context.popOrHome()),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const _PreviewSkeleton(),
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
                  onPressed: () =>
                      ref.invalidate(templatePreviewProvider(widget.slug)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (preview) => Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: FitSpacing.lg),
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
                          Text(
                            '${preview.template.daysPerWeek} DAYS · ${preview.template.level.label} · ~${preview.template.approxMinutes} MIN'
                                .toUpperCase(),
                            style: textTheme.labelSmall,
                          ),
                          const SizedBox(height: FitSpacing.xs),
                          Text(
                            preview.template.name,
                            style: textTheme.displaySmall,
                          ),
                          const SizedBox(height: FitSpacing.sm),
                          Text(
                            preview.template.summary,
                            style: textTheme.bodyMedium,
                          ),
                          if (preview.shortfalls.isNotEmpty) ...<Widget>[
                            const SizedBox(height: FitSpacing.md),
                            for (final s in preview.shortfalls)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: FitSpacing.xs,
                                ),
                                child: Text(
                                  s.detail,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(color: FitColors.amber),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    for (final day in preview.days) _PreviewDayRow(day: day),
                    const Divider(color: FitColors.rule, height: 1),
                    if (_failure != null)
                      Padding(
                        padding: const EdgeInsets.all(FitSpacing.screen),
                        child: AuthFeedback.error(_failure!.message),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: FitColors.rule)),
                ),
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Exercises are chosen for your equipment. Edit any day after.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: FitSpacing.md),
                    FilledButton(
                      key: const ValueKey('template.use'),
                      onPressed: _busy ? null : _apply,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FitColors.paper,
                              ),
                            )
                          : const Text('Use this program'),
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

class _PreviewDayRow extends StatelessWidget {
  const _PreviewDayRow({required this.day});

  final PreviewDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekday = kWeekdayLabels[day.dayOfWeek - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(color: FitColors.rule, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FitSpacing.screen,
            vertical: FitSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Text(
                  weekday.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: day.isRest ? FitColors.ink35 : FitColors.ink,
                  ),
                ),
              ),
              Expanded(
                child: day.isRest
                    ? Text(
                        'Rest',
                        style: textTheme.titleMedium
                            ?.copyWith(color: FitColors.ink35),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '→ ${day.sessionName}',
                            key: ValueKey('preview.day.${day.dayOfWeek}'),
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: FitSpacing.xs),
                          Text(
                            '${day.focus.map((m) => m.label).join(' · ')} · ~${day.estimatedMinutes} min',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: FitColors.ink60),
                          ),
                          const SizedBox(height: FitSpacing.sm),
                          for (final x in day.exercises)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      x.name,
                                      style: textTheme.bodyLarge,
                                    ),
                                  ),
                                  Text(
                                    '${x.setCount} × ${x.repMin == x.repMax ? x.repMin : '${x.repMin}–${x.repMax}'}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 140, height: 11, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.sm),
          Container(width: 220, height: 28, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.lg),
          for (var i = 0; i < 5; i++) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.md),
            Container(width: 260, height: 16, color: FitColors.paper2),
            const SizedBox(height: FitSpacing.md),
          ],
        ],
      ),
    );
  }
}
