part of 'eat_screen.dart';

/// One logged food, compact: name over portion; kcal over protein on the
/// right. A range stays a range.
/// Beta 3.7: an estimate's line opens its range ([range]) on a tap.
class _ItemLine extends StatefulWidget {
  const _ItemLine({
    required this.name,
    required this.portion,
    required this.kcal,
    required this.protein,
    this.range,
    this.muted = false,
    this.struck = false,
    super.key,
  });

  final String name;
  final String portion;
  final String kcal;
  final String? protein;
  final String? range;
  final bool muted;
  final bool struck;

  @override
  State<_ItemLine> createState() => _ItemLineState();
}

class _ItemLineState extends State<_ItemLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dim = textTheme.bodyMedium?.copyWith(color: FitColors.ink60);
    final range = widget.range;
    final line = _line(textTheme, dim);
    if (range == null || widget.muted) return line;
    return Semantics(
      button: true,
      hint: _open ? 'Hide the range' : 'Show the range',
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            line,
            if (_open)
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Text(
                  range,
                  key: const ValueKey('log.item.range'),
                  style: dim,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(TextTheme textTheme, TextStyle? dim) {
    final name = widget.name;
    final portion = widget.portion;
    final kcal = widget.kcal;
    final protein = widget.protein;
    final muted = widget.muted;
    final deco = widget.struck ? TextDecoration.lineThrough : null;
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
                    child: Text(protein, maxLines: 1, style: dim),
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
                  key: ValueKey('log.item.${item.id}'),
                  name: item.foodName,
                  portion: EatFormat.portion(item),
                  kcal: '${EatFormat.kcal(item.kcalLow, item.kcalHigh)} kcal',
                  protein:
                      '${EatFormat.grams(item.proteinLow, item.proteinHigh)} protein',
                  range: FoodFormat.rangeLine(
                    kcalLow: item.kcalLow,
                    kcalHigh: item.kcalHigh,
                    proteinLow: item.proteinLow,
                    proteinHigh: item.proteinHigh,
                    source: item.foodSource,
                  ),
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
            icon: Icon(Icons.close, size: 18, color: FitColors.ink35),
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
                      : '${EatFormat.kcal(item.preview!.kcalLow, item.preview!.kcalHigh)} kcal',
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
          icon: Icon(Icons.close, size: 18, color: FitColors.ink35),
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
