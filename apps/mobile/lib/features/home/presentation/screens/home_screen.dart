import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../health/domain/entities/health.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../nutrition/domain/entities/food_log.dart';
import '../../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../../nutrition/presentation/controllers/food_logger.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../today/domain/today.dart';
import '../../../today/presentation/today_providers.dart';
import '../../../today/presentation/today_why_sheet.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../../workout/presentation/widgets/orphan_session_notice.dart';
import '../../domain/home_context.dart';
import '../../domain/home_suggestion_engine.dart';
import '../controllers/home_providers.dart';
import '../widgets/home_sections.dart';
import '../widgets/name_prompt.dart';
import '../widgets/suggestion_carousel.dart';

/// Phase 6.5 — Home, the TODAY surface. What to know and do right now, in
/// this order: a compact header; "Your next move" (Phase 11: the server's
/// TODAY actions merged with the device-only suggestions, at most four);
/// today's four metrics; recovery; body; this week; the training-volume
/// entry. Editorial: hairlines, typography and whitespace, no card soup.
/// Every number is the server's or the health provider's; every missing one
/// says why. The phone records how the user responds to a server action —
/// shown, opened, accepted, "Not today", completed — and never makes one.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(todayProvider)
      ..invalidate(todayPlanProvider)
      ..invalidate(volumeProvider)
      ..invalidate(historyProvider);
    await ref.read(healthSnapshotProvider.notifier).refreshAll();
  }

  static bool _messConfigured(WidgetRef ref) =>
      ref.watch(profileControllerProvider).value?.profile.mess != null;

  Future<void> _record(
    WidgetRef ref,
    Suggestion s,
    TodayEventName event,
  ) async {
    final a = s.today;
    if (a == null) return;
    await ref.read(todayRepositoryProvider).record(a.ref, s.planDate!, event);
  }

  /// The primary action: `accepted` for a server action, then its flow.
  Future<void> _act(BuildContext context, WidgetRef ref, Suggestion s) async {
    final a = s.today;
    if (a != null) {
      await _record(ref, s, TodayEventName.accepted);
      if (!context.mounted) return;
      await _go(context, ref, a, s.planDate!);
      return;
    }
    switch (s.action) {
      case SuggestionAction.resumeWorkout:
        final id = s.metadata['clientSessionId'];
        if (id != null) await context.push(Routes.session(id));
      case SuggestionAction.viewActivity:
      case SuggestionAction.viewRecovery:
      case SuggestionAction.connectHealth:
        await context.push(Routes.healthData);
      case SuggestionAction.today:
        break;
    }
  }

  /// Into the existing flow for the action's kind (plan §6). `completed`
  /// is sent later, once that flow has finished on the server.
  Future<void> _go(
    BuildContext context,
    WidgetRef ref,
    TodayAction a,
    String planDate,
  ) async {
    switch (a.kind!) {
      case TodayKind.startWorkout:
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
      case TodayKind.deload:
      case TodayKind.injuredLimitation:
      case TodayKind.progressLoad:
      case TodayKind.muscleNeglected:
      case TodayKind.restDay:
        context.go(Routes.plan);
      case TodayKind.eatProtein:
      case TodayKind.eatMeal:
        if (ref.read(profileControllerProvider).value?.profile.mess != null) {
          // MESS opens on the same next meal TODAY chose (the Phase 10 rule).
          await context.push(Routes.mess);
        } else {
          await context.push(
            Routes.foodLog,
            extra: LogTarget(
              date: planDate,
              slot: MealSlot.fromWire(a.subjectKey),
            ),
          );
        }
      case TodayKind.celebratePr:
        final id = ref.read(completedTodayProvider).value?.id;
        await context
            .push(id == null ? Routes.history : Routes.historyDetail(id));
      case TodayKind.logWeight:
        await context.push(Routes.personalDetails);
      case TodayKind.calorieAdjust:
        // Accepting applies it on the server (a new target row). Deliver the
        // event now, then show the targets where they live.
        await ref.read(todayRepositoryProvider).drain();
        ref
          ..invalidate(profileControllerProvider)
          ..invalidate(nutritionDayRefreshProvider(planDate));
        if (!context.mounted) return;
        context.go(Routes.nutrition);
    }
  }

  /// A server card tapped: `opened`, then its "why" with the same choices.
  Future<void> _open(BuildContext context, WidgetRef ref, Suggestion s) async {
    final a = s.today;
    if (a == null) return;
    await _record(ref, s, TodayEventName.opened);
    if (!context.mounted) return;
    final recorded = ref.read(todayRecordedProvider)[a.id] ?? const {};
    final choice = await showTodayWhySheet(
      context,
      action: a,
      messConfigured:
          ref.read(profileControllerProvider).value?.profile.mess != null,
      canDismiss: !recorded.contains(TodayEventName.accepted),
      cached: s.cached,
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case WhyChoice.primary:
        await _act(context, ref, s);
      case WhyChoice.dismiss:
        await _dismiss(ref, s);
    }
  }

  /// "Not today": `dismissed`; the card leaves Home for the rest of the day.
  Future<void> _dismiss(WidgetRef ref, Suggestion s) =>
      _record(ref, s, TodayEventName.dismissed);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final c = ref.watch(homeContextProvider);
    final carousel = ref.watch(homeNextMovesProvider);
    final loading = ref.watch(homeLoadingProvider);
    final status = _planStatus(ref, ref.watch(todayPlanProvider).value);

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
                HomeHeader(
                  hour: c.hourOfDay,
                  date: c.date,
                  name: c.displayName,
                ),
                if (ref.watch(askForNameProvider)) const NamePrompt(),
                if (ref.watch(homeServerFailureProvider) case final f?)
                  ServerNotice(
                    message: f.message,
                    onRetry: () => _refresh(ref),
                  ),
                // Phase 6.6 Gate 7: a session FITOS holds that this phone
                // lost (sign-out / cleared data) blocks every new one.
                if (ref.watch(orphanedSessionProvider).value != null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      FitSpacing.screen,
                      0,
                      FitSpacing.screen,
                      FitSpacing.md,
                    ),
                    child: OrphanSessionNotice(),
                  ),
                if (loading && carousel.isEmpty)
                  const HomeSkeleton()
                else if (carousel.isNotEmpty || status != null) ...<Widget>[
                  const SectionLabel('Your next move'),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FitSpacing.screen,
                        0,
                        FitSpacing.screen,
                        FitSpacing.sm,
                      ),
                      child: Text(
                        status.$2,
                        key: ValueKey(status.$1),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.ink60),
                      ),
                    ),
                  if (carousel.isNotEmpty)
                    SuggestionCarousel(
                      key: const ValueKey('home.carousel'),
                      suggestions: carousel,
                      recorded: ref.watch(todayRecordedProvider),
                      messConfigured: _messConfigured(ref),
                      onAction: (s) => _act(context, ref, s),
                      onOpen: (s) => _open(context, ref, s),
                      onDismiss: (s) => _dismiss(ref, s),
                      onShown: (s) => _record(ref, s, TodayEventName.shown),
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

  /// The honest line above the cards when the server's plan is not live:
  /// the cached plan for today while offline (never passed off as fresh),
  /// or why there are no server suggestions at all (D8 as amended).
  static (String, String)? _planStatus(WidgetRef ref, TodayPlanView? view) {
    if (view == null) return null;
    switch (view.source) {
      case TodayPlanSource.live:
        return null;
      case TodayPlanSource.cached:
        final at = DateTime.tryParse(view.storedAt ?? '');
        final zone = ref.watch(userTimezoneProvider);
        final local =
            at == null ? null : tz.TZDateTime.from(at, userLocation(zone));
        final hhmm = local == null
            ? ''
            : ' from ${local.hour.toString().padLeft(2, '0')}:'
                '${local.minute.toString().padLeft(2, '0')}';
        return (
          'home.today.cached',
          'Offline — showing your plan$hhmm. What you do here is saved '
              'and sent when you are back online.',
        );
      case TodayPlanSource.unavailable:
        return (
          'home.today.unavailable',
          view.offline
              ? 'Suggestions need a connection.'
              : 'Suggestions are unavailable right now.',
        );
    }
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
