import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../../mess/presentation/widgets/mess_widgets.dart';
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food_log.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../widgets/eat_widgets.dart';
import '../widgets/log_controls.dart';

/// The Nutrition tab (Phase 8): EAT.
///
///   EAT                               Food library
///   ‹            Today · Thu 24 Sep            ›
///   REMAINING
///   1,240–1,420                     (the hero)
///   kcal left of 2,400
///   PROTEIN · CARBS · FAT strip, eaten, fibre
///   [ Log food ]
///   Breakfast / Lunch / Snacks / Dinner, each with "Add"
///
/// One vertical scroll (a ListView under pull-to-refresh). Every total is the
/// server's; a log not yet confirmed is listed as "Not synced yet" with a
/// preview and is NOT in any total (owner J10).
class EatScreen extends ConsumerWidget {
  const EatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(eatDateProvider);
    final today = ref.watch(eatDateProvider.notifier).today;
    final view = ref.watch(nutritionDayViewProvider(date));
    final refresh = ref.watch(nutritionDayRefreshProvider(date));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nutritionDayRefreshProvider(date));
            await ref.read(nutritionDayRefreshProvider(date).future);
          },
          child: ListView(
            key: const ValueKey('eat.list'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.md,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              _Header(date: date, today: today),
              const SizedBox(height: FitSpacing.md),
              ...view.when(
                loading: () => const <Widget>[_HeroSkeleton()],
                error: (e, _) => <Widget>[
                  AuthFeedback.error(failureOf(e).message),
                ],
                data: (v) => _dayBody(context, ref, v, refresh, today),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _dayBody(
    BuildContext context,
    WidgetRef ref,
    DayView v,
    AsyncValue<Result<NutritionDay>> refresh,
    String today,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final server = v.server;
    final refreshFailure = switch (refresh) {
      AsyncData(value: Err(:final failure)) => failure,
      AsyncError(:final error) => failureOf(error),
      _ => null,
    };
    final loggable = canLogOn(v.date, today);

    final notices = <Widget>[
      if (refreshFailure != null && server != null)
        EatNotice(
          key: const ValueKey('eat.stale'),
          text: refreshFailure is Offline
              ? 'Offline — showing this day as it was last loaded${_at(v.storedAt)}.'
              : 'Could not refresh — showing this day as it was last loaded${_at(v.storedAt)}.',
        ),
      if (v.parkedCount > 0)
        EatNotice(
          key: const ValueKey('eat.parked'),
          text:
              '${v.parkedCount} food ${v.parkedCount == 1 ? 'change' : 'changes'} not synced',
          action: 'Retry',
          colour: FitColors.oxide,
          onAction: () =>
              ref.read(nutritionLogRepositoryProvider).retryParked(),
        )
      else if (v.unsyncedCount > 0)
        EatNotice(
          key: const ValueKey('eat.unsynced'),
          text:
              '${v.unsyncedCount} waiting to sync — totals update when FITOS has them.',
        ),
    ];

    final meals = _meals(v, server, loggable);

    if (server == null) {
      return <Widget>[
        ...notices,
        if (refresh.isLoading) const _HeroSkeleton(),
        if (refreshFailure != null) ...<Widget>[
          Text('Could not load this day', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFeedback.error(refreshFailure.message),
          const SizedBox(height: FitSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey('eat.retryLoad'),
              onPressed: () =>
                  ref.invalidate(nutritionDayRefreshProvider(v.date)),
              child: const Text('Try again'),
            ),
          ),
          const SizedBox(height: FitSpacing.lg),
        ],
        if (loggable) _LogButton(date: v.date),
        if (v.pending.isNotEmpty) ...meals,
      ];
    }

    final empty = server.totals.isEmpty && v.pending.isEmpty;
    return <Widget>[
      ...notices,
      _Hero(day: server),
      if (empty) ...<Widget>[
        const SizedBox(height: FitSpacing.sm),
        Text(
          v.date == today
              ? 'Nothing logged today.'
              : 'Nothing logged on this day.',
          key: const ValueKey('eat.empty'),
          style: textTheme.bodyLarge,
        ),
        if (!loggable)
          Text(
            'Food can be logged up to 30 days back.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
      ],
      const SizedBox(height: FitSpacing.md),
      if (loggable) _LogButton(date: v.date),
      // Phase 9: today's mess menu, for anyone with a mess (hidden otherwise).
      if (v.date == today) TodaysMessStrip(today: today),
      const SizedBox(height: FitSpacing.md),
      ...meals,
    ];
  }

  static String _at(String? storedAt) {
    if (storedAt == null) return '';
    final t = DateTime.tryParse(storedAt)?.toLocal();
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return ' at $hh:$mm';
  }

  /// All four meals, always: an empty meal says so and offers "Add".
  List<Widget> _meals(DayView v, NutritionDay? server, bool loggable) => [
        for (final slot in MealSlot.values)
          _MealSection(
            date: v.date,
            slot: slot,
            logs: server?.logs.where((l) => l.mealSlot == slot).toList() ??
                const <FoodLog>[],
            pending: v.pending.where((p) => p.mealSlot == slot).toList(),
            deleting: v.deleting,
            loggable: loggable,
          ),
      ];
}

class _Header extends ConsumerWidget {
  const _Header({required this.date, required this.today});

  final String date;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(eatDateProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('EAT', style: textTheme.labelSmall),
            const Spacer(),
            // Flexible: at 200 % text the label ellipsises instead of overflowing.
            Flexible(
              child: TextButton.icon(
                key: const ValueKey('eat.library'),
                onPressed: () => context.push(Routes.foodLibrary),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text(
                  'Food library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        // ‹  Today · Thu 24 Sep  ›  — compact; tap the date to come back to today.
        Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey('eat.prev'),
              tooltip: 'Previous day',
              onPressed: notifier.previous,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                onTap: date == today ? null : notifier.toToday,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        EatFormat.dayLabel(date, today),
                        key: const ValueKey('eat.date'),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        date == today
                            ? EatFormat.shortDate(date)
                            : 'Tap to go back to today',
                        style: textTheme.bodyMedium?.copyWith(
                          color: FitColors.ink60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('eat.next'),
              tooltip: 'Next day',
              onPressed: date == today ? null : notifier.next,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const Divider(color: FitColors.rule, height: 1),
      ],
    );
  }
}

/// Remaining against the target as the hero (§31 Phase 8), then the macro
/// strip. Every number is the server's; this only formats.
class _Hero extends StatelessWidget {
  const _Hero({required this.day});

  final NutritionDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = day.totals;
    final targets = day.targets;
    final remaining = day.remaining;
    final estimated = t.kcalLow != t.kcalHigh ||
        t.proteinLow != t.proteinHigh ||
        t.carbLow != t.carbHigh ||
        t.fatLow != t.fatHigh;
    final over = remaining?.kcal.state == RemainingState.over;

    return Column(
      key: const ValueKey('eat.hero'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (remaining != null) ...<Widget>[
          Text(
            over ? 'OVER TARGET' : 'REMAINING',
            style: textTheme.labelSmall,
          ),
          // Scales down to the width; a range never wraps onto two lines.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              EatFormat.heroKcal(remaining.kcal).value,
              key: const ValueKey('eat.hero.value'),
              maxLines: 1,
              style: textTheme.displayMedium?.copyWith(
                color: over ? FitColors.oxide : FitColors.ink,
              ),
            ),
          ),
          Text(
            EatFormat.heroKcal(remaining.kcal).caption,
            key: const ValueKey('eat.hero.caption'),
            style: textTheme.bodyLarge,
          ),
        ] else ...<Widget>[
          Text(
            'No targets yet',
            key: const ValueKey('eat.noTargets'),
            style: textTheme.titleLarge,
          ),
          Text(
            'Set a goal in Profile and FITOS works out your targets.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
        ],
        const SizedBox(height: FitSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: MacroCell(
                label: 'Protein',
                value: remaining == null
                    ? EatFormat.grams(t.proteinLow, t.proteinHigh)
                    : EatFormat.proteinShort(remaining.protein),
                caption: targets == null ? null : 'of ${targets.proteinG} g',
                valueKey: const ValueKey('eat.protein'),
              ),
            ),
            Expanded(
              child: MacroCell(
                label: 'Carbs',
                value: EatFormat.grams(t.carbLow, t.carbHigh),
                caption: targets == null ? 'eaten' : 'of ${targets.carbG} g',
              ),
            ),
            Expanded(
              child: MacroCell(
                label: 'Fat',
                value: EatFormat.grams(t.fatLow, t.fatHigh),
                caption: targets == null ? 'eaten' : 'of ${targets.fatG} g',
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Eaten ${EatFormat.kcal(t.kcalLow, t.kcalHigh)} kcal',
          key: const ValueKey('eat.eaten'),
          style: textTheme.bodyLarge,
        ),
        Text(
          EatFormat.fibre(t, targets),
          key: const ValueKey('eat.fibre'),
          style: textTheme.bodyMedium?.copyWith(
            color: t.fibreUnknownItems > 0 ? FitColors.ink60 : null,
          ),
        ),
        if (estimated)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'Includes estimates, so totals are ranges.',
              key: const ValueKey('eat.estimated'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
            ),
          ),
      ],
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.date,
    required this.slot,
    required this.logs,
    required this.pending,
    required this.deleting,
    required this.loggable,
  });

  final String date;
  final MealSlot slot;
  final List<FoodLog> logs;
  final List<PendingLog> pending;
  final Set<String> deleting;
  final bool loggable;

  Future<void> _saveMeal(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameDialog(initial: slot.label),
    );
    if (name == null || !context.mounted) return;
    final repo = ref.read(nutritionLogRepositoryProvider);
    final result = await repo.createSavedMeal(
      CreateSavedMealRequest(
        clientMealId: const Uuid().v4(),
        name: name,
        fromClientLogIds: [
          for (final l in logs)
            if (!deleting.contains(l.clientLogId)) l.clientLogId,
        ],
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (result) {
            Ok() => 'Saved "$name" to your meals.',
            Err(:final failure) => failure is Offline
                ? 'Saving a meal needs a connection.'
                : failure.message,
          },
        ),
      ),
    );
    if (result is Ok) ref.invalidate(savedMealsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final canSave = logs.any((l) => !deleting.contains(l.clientLogId));
    final empty = logs.isEmpty && pending.isEmpty;
    return Column(
      key: ValueKey('eat.slot.${slot.wire}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(color: FitColors.rule, height: 1),
        Row(
          children: <Widget>[
            Icon(mealSlotIcon(slot), size: 20, color: FitColors.ink),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Text(
                slot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Icon-only: stays one row at any text size.
            if (canSave)
              IconButton(
                key: ValueKey('eat.save.${slot.wire}'),
                tooltip: 'Save as meal',
                onPressed: () => _saveMeal(context, ref),
                icon: const Icon(
                  Icons.bookmark_add_outlined,
                  size: 20,
                  color: FitColors.ink60,
                ),
              ),
            if (loggable)
              Flexible(
                child: TextButton.icon(
                  key: ValueKey('eat.add.${slot.wire}'),
                  onPressed: () => context.push(
                    Routes.foodLog,
                    extra: LogTarget(date: date, slot: slot),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(
              left: 28,
              bottom: FitSpacing.sm,
            ),
            child: Text(
              loggable ? 'Nothing yet — add food.' : 'Nothing logged.',
              key: ValueKey('eat.slot.${slot.wire}.empty'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          ),
        for (final log in logs)
          _LogEntry(log: log, deleting: deleting.contains(log.clientLogId)),
        for (final p in pending) _PendingEntry(pending: p),
        const SizedBox(height: FitSpacing.sm),
      ],
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('The whole entry is removed from this day.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey('delete.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

/// One logged food, compact: name over portion; kcal over protein on the
/// right. A range stays a range.
class _ItemLine extends StatelessWidget {
  const _ItemLine({
    required this.name,
    required this.portion,
    required this.kcal,
    required this.protein,
    this.muted = false,
    this.struck = false,
  });

  final String name;
  final String portion;
  final String kcal;
  final String? protein;
  final bool muted;
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dim = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    final deco = struck ? TextDecoration.lineThrough : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: (muted ? dim : textTheme.bodyLarge)
                      ?.copyWith(decoration: deco),
                ),
                Text(portion, style: dim?.copyWith(decoration: deco)),
              ],
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          // The numbers take what the name leaves (up to two fifths) and
          // scale down rather than overflow at large text sizes.
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    kcal,
                    maxLines: 1,
                    style: (muted ? dim : textTheme.titleMedium)
                        ?.copyWith(decoration: deco),
                  ),
                ),
                if (protein != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(protein!, maxLines: 1, style: dim),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry extends ConsumerWidget {
  const _LogEntry({required this.log, required this.deleting});

  final FoodLog log;
  final bool deleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      key: ValueKey('log.${log.clientLogId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final item in log.items)
                _ItemLine(
                  name: item.foodName,
                  portion: EatFormat.portion(item),
                  kcal: '${EatFormat.kcal(item.kcalLow, item.kcalHigh)} kcal',
                  protein:
                      '${EatFormat.grams(item.proteinLow, item.proteinHigh)} protein',
                  muted: deleting,
                  struck: deleting,
                ),
              if (deleting)
                Text(
                  'Deleting — totals update when FITOS confirms.',
                  key: ValueKey('log.${log.clientLogId}.deleting'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
            ],
          ),
        ),
        if (!deleting)
          IconButton(
            key: ValueKey('log.${log.clientLogId}.delete'),
            tooltip: 'Delete entry',
            icon: const Icon(Icons.close, size: 18, color: FitColors.ink35),
            onPressed: () async {
              if (await _confirmDelete(context)) {
                await ref
                    .read(nutritionLogRepositoryProvider)
                    .delete(log.clientLogId);
              }
            },
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

/// A log the server has not confirmed: a PREVIEW (owner J10), clearly not
/// counted in the totals above.
class _PendingEntry extends ConsumerWidget {
  const _PendingEntry({required this.pending});

  final PendingLog pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      key: ValueKey('pending.${pending.clientLogId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final item in pending.preview.items)
                _ItemLine(
                  name: item.name,
                  portion: item.portion,
                  kcal: item.preview == null
                      ? ''
                      : '≈ ${EatFormat.kcal(item.preview!.kcalLow, item.preview!.kcalHigh)} kcal',
                  protein: null,
                  muted: true,
                ),
              Text(
                pending.parked
                    ? 'Not synced: ${pending.error ?? 'FITOS refused it'}'
                    : 'Not synced yet — not in the totals until FITOS has it.',
                key: ValueKey('pending.${pending.clientLogId}.state'),
                style: textTheme.bodyMedium?.copyWith(
                  color: pending.parked ? FitColors.oxide : FitColors.amber,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('pending.${pending.clientLogId}.delete'),
          tooltip: 'Delete entry',
          icon: const Icon(Icons.close, size: 18, color: FitColors.ink35),
          onPressed: () async {
            if (await _confirmDelete(context)) {
              await ref
                  .read(nutritionLogRepositoryProvider)
                  .delete(pending.clientLogId);
            }
          },
        ),
      ],
    );
  }
}

class _LogButton extends ConsumerWidget {
  const _LogButton({required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      key: const ValueKey('eat.log'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: () => context.push(
        Routes.foodLog,
        extra: LogTarget(
          date: date,
          slot: MealSlot.forHour(ref.read(localHourProvider)),
        ),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Log food'),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _name.text.trim().isNotEmpty && _name.text.trim().length <= 60;
    return AlertDialog(
      title: const Text('Save as a meal'),
      content: TextField(
        key: const ValueKey('savedMeal.name'),
        controller: _name,
        autofocus: true,
        maxLength: 60,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('savedMeal.save'),
          onPressed:
              valid ? () => Navigator.of(context).pop(_name.text.trim()) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(width: 80, height: 12, color: FitColors.paper2),
        const SizedBox(height: FitSpacing.sm),
        Container(width: 200, height: 48, color: FitColors.paper2),
        const SizedBox(height: FitSpacing.sm),
        Container(width: 160, height: 14, color: FitColors.paper2),
      ],
    );
  }
}
