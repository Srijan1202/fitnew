part of 'eat_screen.dart';

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
              'Includes estimates, so these numbers are about right. Tap an '
              'item to see its range.',
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
    // ADR-029: each meal a block on the glass palettes.
    return FitBlock(
      key: ValueKey('eat.slot.${slot.wire}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const FitRule(),
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
                  icon: Icon(
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
