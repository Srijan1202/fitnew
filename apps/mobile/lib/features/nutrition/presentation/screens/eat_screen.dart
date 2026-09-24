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
import '../../data/nutrition_log_repository.dart';
import '../../domain/entities/food_log.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../widgets/eat_widgets.dart';

/// The Nutrition tab (Phase 8): EAT. What is left against today's target
/// is the hero, then the day's meals, then "Log food". Every total is the
/// server's (its snapshots, summed by it); a log this phone has not had
/// confirmed yet is listed as "Not synced yet" with a preview, and is NOT
/// in the totals until the server has it (owner J10). ‹ › walks back
/// through past days (day history), never into the future.
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
              FitSpacing.lg,
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
        ],
        ..._meals(context, ref, v, null, loggable),
        if (loggable) _LogButton(date: v.date),
      ];
    }

    final empty = server.totals.isEmpty && v.pending.isEmpty;
    return <Widget>[
      ...notices,
      _Hero(day: server),
      const SizedBox(height: FitSpacing.lg),
      if (empty) ...<Widget>[
        Text(
          v.date == today
              ? 'Nothing logged today.'
              : 'Nothing logged on this day.',
          key: const ValueKey('eat.empty'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FitSpacing.xs),
        Text(
          loggable
              ? 'Log what you eat to see what is left of your target.'
              : 'Food can be logged up to 30 days back.',
          style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
        ),
        const SizedBox(height: FitSpacing.md),
      ] else
        ..._meals(context, ref, v, server, loggable),
      if (loggable) _LogButton(date: v.date),
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

  List<Widget> _meals(
    BuildContext context,
    WidgetRef ref,
    DayView v,
    NutritionDay? server,
    bool loggable,
  ) {
    final out = <Widget>[];
    for (final slot in MealSlot.values) {
      final logs = server?.logs.where((l) => l.mealSlot == slot).toList() ??
          const <FoodLog>[];
      final pending = v.pending.where((p) => p.mealSlot == slot).toList();
      if (logs.isEmpty && pending.isEmpty) continue;
      out.add(
        _MealSection(
          slot: slot,
          logs: logs,
          pending: pending,
          deleting: v.deleting,
        ),
      );
    }
    return out;
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.date, required this.today});

  final String date;
  final String today;

  static String label(String date, String today) {
    if (date == today) return 'Today';
    if (date == shiftDate(today, -1)) return 'Yesterday';
    final p = date.split('-').map(int.parse).toList();
    final d = DateTime.utc(p[0], p[1], p[2]);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(eatDateProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('NUTRITION', style: textTheme.labelSmall)),
            TextButton(
              key: const ValueKey('eat.library'),
              onPressed: () => context.push(Routes.foodLibrary),
              child: const Text('Food library'),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey('eat.prev'),
              tooltip: 'Previous day',
              onPressed: notifier.previous,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: GestureDetector(
                onTap: date == today ? null : notifier.toToday,
                child: Text(
                  label(date, today),
                  key: const ValueKey('eat.date'),
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
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
      ],
    );
  }
}

/// Remaining macros as the hero (§31 Phase 8). The numbers are the server's.
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

    return Column(
      key: const ValueKey('eat.hero'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (remaining != null) ...<Widget>[
          Text(
            EatFormat.heroKcal(remaining.kcal).value,
            key: const ValueKey('eat.hero.value'),
            style: textTheme.displayLarge?.copyWith(
              color: remaining.kcal.state == RemainingState.over
                  ? FitColors.oxide
                  : null,
            ),
          ),
          Text(
            EatFormat.heroKcal(remaining.kcal).caption,
            key: const ValueKey('eat.hero.caption'),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: FitSpacing.sm),
          Text(
            EatFormat.protein(remaining.protein),
            key: const ValueKey('eat.protein'),
            style: textTheme.titleMedium,
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
        const SizedBox(height: FitSpacing.sm),
        const Divider(color: FitColors.rule, height: 1),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Eaten ${EatFormat.kcal(t.kcalLow, t.kcalHigh)} kcal',
          key: const ValueKey('eat.eaten'),
          style: textTheme.bodyLarge,
        ),
        Text(
          EatFormat.consumedLine(
            'Protein',
            t.proteinLow,
            t.proteinHigh,
            targets?.proteinG,
          ),
          style: textTheme.bodyMedium,
        ),
        Text(
          EatFormat.consumedLine(
            'Carbohydrate',
            t.carbLow,
            t.carbHigh,
            targets?.carbG,
          ),
          style: textTheme.bodyMedium,
        ),
        Text(
          EatFormat.consumedLine('Fat', t.fatLow, t.fatHigh, targets?.fatG),
          style: textTheme.bodyMedium,
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
    required this.slot,
    required this.logs,
    required this.pending,
    required this.deleting,
  });

  final MealSlot slot;
  final List<FoodLog> logs;
  final List<PendingLog> pending;
  final Set<String> deleting;

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
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: Column(
        key: ValueKey('eat.slot.${slot.wire}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(color: FitColors.rule, height: 1),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    Text(slot.label.toUpperCase(), style: textTheme.labelSmall),
              ),
              if (canSave)
                TextButton(
                  key: ValueKey('eat.save.${slot.wire}'),
                  onPressed: () => _saveMeal(context, ref),
                  child: const Text('Save as meal'),
                ),
            ],
          ),
          for (final log in logs)
            _LogRow(log: log, deleting: deleting.contains(log.clientLogId)),
          for (final p in pending) _PendingRow(pending: p),
        ],
      ),
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

class _LogRow extends ConsumerWidget {
  const _LogRow({required this.log, required this.deleting});

  final FoodLog log;
  final bool deleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    return Padding(
      key: ValueKey('log.${log.clientLogId}'),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final item in log.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${item.foodName} · ${EatFormat.portion(item)}',
                            style: deleting
                                ? muted?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          '${EatFormat.kcal(item.kcalLow, item.kcalHigh)} kcal',
                          style: deleting ? muted : textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                if (deleting)
                  Text(
                    'Deleting — totals update when FITOS confirms.',
                    key: ValueKey('log.${log.clientLogId}.deleting'),
                    style: muted,
                  ),
              ],
            ),
          ),
          if (!deleting)
            IconButton(
              key: ValueKey('log.${log.clientLogId}.delete'),
              tooltip: 'Delete entry',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: FitColors.ink60,
              ),
              onPressed: () async {
                if (await _confirmDelete(context)) {
                  await ref
                      .read(nutritionLogRepositoryProvider)
                      .delete(log.clientLogId);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// A log the server has not confirmed: its items with a PREVIEW (owner J10),
/// clearly not counted in the totals above.
class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.pending});

  final PendingLog pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    return Padding(
      key: ValueKey('pending.${pending.clientLogId}'),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final item in pending.preview.items)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item.name} · ${item.portion}',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        item.preview == null
                            ? ''
                            : '≈ ${EatFormat.kcal(item.preview!.kcalLow, item.preview!.kcalHigh)} kcal',
                        style: muted,
                      ),
                    ],
                  ),
                Text(
                  pending.parked
                      ? 'Not synced: ${pending.error ?? 'FITOS refused it'}'
                      : 'Not synced yet — not in the totals until FITOS has it.',
                  key: ValueKey('pending.${pending.clientLogId}.state'),
                  style: pending.parked
                      ? textTheme.bodyMedium?.copyWith(color: FitColors.oxide)
                      : muted,
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('pending.${pending.clientLogId}.delete'),
            tooltip: 'Delete entry',
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: FitColors.ink60,
            ),
            onPressed: () async {
              if (await _confirmDelete(context)) {
                await ref
                    .read(nutritionLogRepositoryProvider)
                    .delete(pending.clientLogId);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _LogButton extends ConsumerWidget {
  const _LogButton({required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.sm),
      child: FilledButton.icon(
        key: const ValueKey('eat.log'),
        onPressed: () => context.push(
          Routes.foodLog,
          extra: LogTarget(
            date: date,
            slot: MealSlot.forHour(ref.read(localHourProvider)),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Log food'),
      ),
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
        Container(width: 180, height: 48, color: FitColors.paper2),
        const SizedBox(height: FitSpacing.sm),
        Container(width: 220, height: 14, color: FitColors.paper2),
        const SizedBox(height: FitSpacing.sm),
        Container(width: 160, height: 14, color: FitColors.paper2),
      ],
    );
  }
}
