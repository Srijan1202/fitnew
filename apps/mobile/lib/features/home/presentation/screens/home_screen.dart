import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../health/domain/entities/health.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../domain/home_context.dart';
import '../../domain/home_suggestion_engine.dart';
import '../controllers/home_providers.dart';
import '../widgets/home_sections.dart';
import '../widgets/suggestion_carousel.dart';

/// Phase 6.5 — Home. What to know and do right now, in this order: a
/// compact header; "Your next move" (the engine's carousel, only what is
/// relevant); today's four metrics; recovery; body; this week; the
/// training-volume entry; "More for you". Editorial: hairlines,
/// typography and whitespace, no card soup. Every number is the server's
/// or the health provider's; every missing one says why.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(todayProvider)
      ..invalidate(volumeProvider)
      ..invalidate(historyProvider);
    await ref.read(healthSnapshotProvider.notifier).refreshAll();
  }

  Future<void> _act(BuildContext context, WidgetRef ref, Suggestion s) async {
    switch (s.action) {
      case SuggestionAction.resumeWorkout:
        final id = s.metadata['clientSessionId'];
        if (id != null) await context.push(Routes.session(id));
      case SuggestionAction.startWorkout:
        final repo = ref.read(workoutRepositoryProvider);
        final active = await repo.activeSession();
        if (!context.mounted) return;
        if (active != null) {
          await context.push(Routes.session(active.clientSessionId));
          return;
        }
        final day = ref.read(todayProvider).value;
        final session = await repo.startSession(day: day);
        if (!context.mounted) return;
        await context.push(Routes.session(session.clientSessionId));
      case SuggestionAction.viewSummary:
        final id = s.metadata['sessionId'];
        if (id != null) await context.push(Routes.historyDetail(id));
      case SuggestionAction.viewPlan:
        context.go(Routes.plan);
      case SuggestionAction.logFood:
        context.go(Routes.nutrition);
      case SuggestionAction.viewActivity:
      case SuggestionAction.viewRecovery:
      case SuggestionAction.connectHealth:
        await context.push(Routes.healthData);
      case SuggestionAction.viewVolume:
        await context.push(Routes.volume);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final c = ref.watch(homeContextProvider);
    final suggestions = ref.watch(homeSuggestionsProvider);
    final loading = ref.watch(homeLoadingProvider);
    final carousel = HomeSuggestionEngine.carousel(suggestions);
    final more = HomeSuggestionEngine.more(suggestions);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: FitColors.ink,
          onRefresh: () => _refresh(ref),
          child: SingleChildScrollView(
            key: const ValueKey('home.list'),
            physics: const AlwaysScrollableScrollPhysics(),
            // Room for the floating bar over the last section.
            padding: const EdgeInsets.only(bottom: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HomeHeader(hour: c.hourOfDay, date: c.date),
                if (loading && suggestions.isEmpty)
                  const HomeSkeleton()
                else if (carousel.isNotEmpty) ...<Widget>[
                  const SectionLabel('Your next move'),
                  SuggestionCarousel(
                    key: const ValueKey('home.carousel'),
                    suggestions: carousel,
                    onAction: (s) => _act(context, ref, s),
                  ),
                ],
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Today'),
                TodayMetrics(context: c),
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('Recovery'),
                RecoverySection(context: c),
                if (_showBody(c)) ...<Widget>[
                  const SizedBox(height: FitSpacing.lg),
                  const SectionLabel('Body'),
                  BodySection(context: c),
                ],
                const SizedBox(height: FitSpacing.lg),
                const SectionLabel('This week'),
                WeekSection(week: c.week),
                const SizedBox(height: FitSpacing.md),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
                  child: OutlinedButton(
                    key: const ValueKey('today.volume'),
                    onPressed: () => context.push(Routes.volume),
                    child: const Text('Training volume →'),
                  ),
                ),
                if (more.isNotEmpty) ...<Widget>[
                  const SizedBox(height: FitSpacing.lg),
                  const SectionLabel('More for you'),
                  MoreForYou(
                    key: const ValueKey('home.more'),
                    suggestions: more,
                    onAction: (s) => _act(context, ref, s),
                  ),
                ],
                const SizedBox(height: FitSpacing.lg),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
                  child: Text(
                    _footer(c),
                    key: const ValueKey('home.footer'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Body shows when a body metric is granted or has a value; otherwise
  /// the recovery section already carries the one "connect" line.
  static bool _showBody(HomeContext c) {
    final h = c.health;
    if (h == null) return false;
    return [h.weight, h.bodyFat, h.bmr].any(
      (m) =>
          m.isAvailable ||
          m.availability == HealthAvailability.noData ||
          m.availability == HealthAvailability.temporarilyUnavailable,
    );
  }

  static String _footer(HomeContext c) {
    final h = c.health;
    if (h == null || !c.healthConnected) {
      return 'Health data stays on this phone.';
    }
    return h.fromCache
        ? 'Health data: last reading kept on this phone; Health Connect did not answer just now.'
        : 'Health data read ${HomeSections.ago(h.fetchedAt)} · stays on this phone.';
  }
}
