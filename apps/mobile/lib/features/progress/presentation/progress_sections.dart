part of 'progress_screen.dart';

/* ---------------------------------------------------------------- weight -- */

/// Drawn only once there is a trend weight; before that, "Get started".
class _WeightSection extends ConsumerWidget {
  const _WeightSection({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final w = summary.weight;
    final device = ref.watch(healthSnapshotProvider).value?.weight;
    final latest = w.points.isEmpty ? null : w.points.last;
    final enough = w.points.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // §13.2: the trend is the headline; the raw reading is small below it.
              Text(
                '${ProgressScreen.kg(w.currentTrendKg!)} kg',
                key: const ValueKey('progress.weight.trend'),
                style: textTheme.displayMedium,
              ),
              Text(
                'Trend weight',
                style: textTheme.titleMedium?.copyWith(color: FitColors.ink60),
              ),
              if (latest != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Latest reading ${ProgressScreen.kg(latest.rawKg)} kg on ${ProgressScreen.date(latest.date)}',
                    key: const ValueKey('progress.weight.raw'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                  ),
                ),
            ],
          ),
        ),
        // With one reading the panel below says it all; the tiles wait for two.
        if (enough) ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          _StatGrid([
            w.weeklyChangeKg == null
                ? _Stat(
                    label: 'Weekly rate',
                    value: 'After 10 days of readings',
                    caption: '${w.daysOfData} so far',
                    valueKey: const ValueKey('progress.weight.rate'),
                    muted: true,
                  )
                : _Stat(
                    label: 'Weekly rate',
                    value:
                        '${ProgressScreen.signed(w.weeklyChangeKg!, 'kg')} / week',
                    caption: 'From the trend',
                    valueKey: const ValueKey('progress.weight.rate'),
                  ),
            w.windowChangeKg == null
                ? const _Stat(
                    label: 'Change',
                    value: 'Once readings span 7 days',
                    caption: 'Never day to day',
                    muted: true,
                  )
                : _Stat(
                    label: 'Change',
                    value: ProgressScreen.signed(w.windowChangeKg!, 'kg'),
                    caption: 'Over ${w.windowChangeDays} days',
                    valueKey: const ValueKey('progress.weight.change'),
                  ),
          ]),
          const SizedBox(height: FitSpacing.md),
          _Pad(
            child: TrendChart(
              points: w.points,
              from: summary.from,
              to: summary.today,
              height: 200,
            ),
          ),
        ] else ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          const _Pad(
            child: _Panel(
              panelKey: ValueKey('progress.weight.sparse'),
              title: 'Your trend line starts with the next reading',
              body:
                  'One reading so far. Weigh in on a few different days and the line appears here, smoothing out the daily ups and downs.',
            ),
          ),
        ],
        const SizedBox(height: FitSpacing.md),
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Note(
                ProgressScreen.fluctuation,
                textKey: ValueKey('progress.weight.fluctuation'),
              ),
              if (device != null && device.isAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.xs),
                  child: Text(
                    // Owner D10: device data, never part of the trend.
                    'Health Connect: ${ProgressScreen.kg(device.value!)} kg · on this phone, not in the trend',
                    key: const ValueKey('progress.weight.healthConnect'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                  ),
                ),
              const SizedBox(height: FitSpacing.md),
              FilledButton.icon(
                key: const ValueKey('progress.weight.log'),
                onPressed: () => showWeightSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log weight'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ body -- */

/// Tape measurements (when there are any) and the photos card.
class _BodySection extends ConsumerWidget {
  const _BodySection({required this.summary, required this.photos});

  final ProgressSummary summary;

  /// Beta 3.4 (ADR-035): photos, kept on this phone only — when switched on.
  final bool photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // Beta 4.1.1 (owner): cm or inches; the server keeps centimetres.
    final unit = ref.watch(lengthUnitProvider);
    final present = {for (final m in summary.measurements) m.site};
    final missing =
        MeasurementSite.values.where((s) => !present.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary.measurements.isNotEmpty) ...<Widget>[
          const _Pad(
            child: Align(
              alignment: Alignment.centerRight,
              child: LengthUnitSwitch(),
            ),
          ),
          const SizedBox(height: FitSpacing.md),
          _StatGrid([
            for (final m in summary.measurements)
              _Stat(
                label: m.site.label,
                value:
                    '${ProgressScreen.kg(unit.fromCm(m.latestCm))} ${unit.label}',
                caption: m.changeCm == null
                    ? 'Change shows after 7 days'
                    : '${ProgressScreen.signed(unit.fromCm(m.changeCm!), unit.label)} over ${m.changeDays} days',
                valueKey: ValueKey('progress.measurement.${m.site.wire}'),
                captionKey:
                    ValueKey('progress.measurement.${m.site.wire}.change'),
              ),
          ]),
          if (missing.isNotEmpty)
            _Pad(
              child: Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(
                  'Not measured yet: ${missing.map((s) => s.label.toLowerCase()).join(', ')}',
                  key: const ValueKey('progress.measurement.missing'),
                  style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                ),
              ),
            ),
          const SizedBox(height: FitSpacing.md),
          _Pad(
            child: OutlinedButton.icon(
              key: const ValueKey('progress.measurement.log'),
              style: _squareOutline,
              onPressed: () => showMeasurementSheet(context),
              icon: const Icon(Icons.straighten, size: 18),
              label: const Text('Add measurement'),
            ),
          ),
        ],
        if (photos) ...<Widget>[
          if (summary.measurements.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            const _RowRule(),
            const SizedBox(height: FitSpacing.md),
          ],
          // Beta 3.9: inset like every other section's content.
          const _Pad(child: ProgressPhotosCard()),
        ],
      ],
    );
  }
}

/* --------------------------------------------------------------- strength -- */

/// The best lifts, then the newest record — the rest a tap away.
class _StrengthSection extends StatefulWidget {
  const _StrengthSection({required this.summary});

  final ProgressSummary summary;

  /// Lifts shown before "Show all".
  static const shown = 5;

  @override
  State<_StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends State<_StrengthSection> {
  bool _all = false;
  bool _records = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lifts = widget.summary.bestLifts;
    final prs = widget.summary.prs;
    final visible = _all ? lifts : lifts.take(_StrengthSection.shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final b in visible) ...<Widget>[
          if (b != visible.first) const _RowRule(),
          _Pad(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(b.exerciseName, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'From ${ProgressScreen.kg(b.weightKg)} kg × ${b.reps} · ${ProgressScreen.date(b.date)}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: FitColors.ink60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  // At large text sizes the number shrinks rather than
                  // pushing past the edge (found at 200 % on 360 px).
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${ProgressScreen.kg(b.estimated1RmKg)} kg',
                            key: ValueKey('progress.best.${b.exerciseId}'),
                            style: textTheme.displaySmall,
                          ),
                          Text(
                            'est. 1RM',
                            style: textTheme.bodySmall
                                ?.copyWith(color: FitColors.ink60),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (lifts.length > _StrengthSection.shown)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: FitSpacing.sm),
              child: TextButton(
                key: const ValueKey('progress.strength.more'),
                onPressed: () => setState(() => _all = !_all),
                child: Text(
                  _all ? 'Show fewer' : 'Show all ${lifts.length} lifts',
                ),
              ),
            ),
          ),
        if (lifts.isNotEmpty)
          _Pad(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Text(
                'Estimated 1RM (Epley) is a guide, not a target.',
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
              ),
            ),
          ),
        if (prs.isNotEmpty) ...<Widget>[
          if (lifts.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            const _RowRule(),
          ],
          // Beta 3.9: the newest record in Strength, the rest a tap away.
          if (_records)
            for (final p in prs)
              _Record(record: p, rowKey: 'progress.pr.${p.id}')
          else
            _Record(
              record: prs.reduce(
                (a, b) => b.achievedOn.compareTo(a.achievedOn) > 0 ? b : a,
              ),
              rowKey: 'progress.records.latest',
            ),
          if (prs.length > 1)
            InkWell(
              key: const ValueKey('progress.records.toggle'),
              onTap: () => setState(() => _records = !_records),
              child: _Pad(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _records
                              ? 'Newest only'
                              : 'All ${prs.length} records this period',
                          key: const ValueKey('progress.records.count'),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.ink60),
                        ),
                      ),
                      Icon(
                        _records ? Icons.expand_less : Icons.expand_more,
                        color: FitColors.ink60,
                        semanticLabel:
                            _records ? 'Hide records' : 'Show records',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A record: the lift and the day, then the record's own words (server).
class _Record extends StatelessWidget {
  const _Record({required this.record, required this.rowKey});

  final PrRecord record;
  final String rowKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = record;
    return _Pad(
      key: ValueKey(rowKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: FitColors.pine,
              ),
            ),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'New best: ${p.exerciseName} · ${ProgressScreen.date(p.achievedOn)}',
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    p.reason,
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------- training -- */

/// Sessions against the plan week by week, then the weekly volume per
/// muscle (when there is any) and the way into Training volume.
class _TrainingSection extends StatelessWidget {
  const _TrainingSection({required this.summary, required this.volume});

  final ProgressSummary summary;

  /// True when the Volume screen's weeks have something to draw.
  final bool volume;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = summary.consistency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Pad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                c.planned == null
                    ? '${c.completed}'
                    : '${c.completed} / ${c.planned}',
                key: const ValueKey('progress.consistency'),
                style: textTheme.displaySmall,
              ),
              Text(
                c.planned == null
                    ? 'Completed · no programme to compare'
                    : 'Planned sessions done${c.percent == null ? '' : ' · ${c.percent}%'}',
                key: const ValueKey('progress.consistency.caption'),
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
              ),
              if (c.planned != null && c.weeks.isNotEmpty) ...<Widget>[
                const SizedBox(height: FitSpacing.md),
                Wrap(
                  spacing: FitSpacing.md,
                  runSpacing: FitSpacing.sm,
                  children: <Widget>[
                    for (final w in c.weeks) _WeekDots(week: w),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (volume) const _VolumeHeatmap(),
        _Pad(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('progress.volume.open'),
              onPressed: () => context.push(Routes.volume),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: Text('Training volume')),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Monday an ISO week ("2026-W38") starts on, as "14 Sep".
String _weekOf(String isoWeek) {
  final year = int.parse(isoWeek.substring(0, 4));
  final week = int.parse(isoWeek.substring(6));
  final jan4 = DateTime.utc(year, 1, 4);
  final monday = jan4
      .subtract(Duration(days: jan4.weekday - 1))
      .add(Duration(days: 7 * (week - 1)));
  return ProgressScreen.date(monday.toIso8601String().substring(0, 10));
}

/// One ISO week, named by its Monday: a dot per planned session — filled
/// when done, a hollow ring when not (no red for a missed one, §17 rule 4).
/// At most [maxDots] dots; sessions beyond them are a "+N" (found on the
/// S24: 24 sessions in a 4-session week drew 24 and overflowed the row).
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.week});

  final WeekConsistency week;

  static const maxDots = 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dots =
        (week.planned > 0 ? week.planned : week.completed).clamp(0, maxDots);
    final filled = week.completed.clamp(0, dots);
    final extra = week.completed - filled;
    final from = _weekOf(week.isoWeek);
    return Semantics(
      label: 'Week of $from: ${week.completed} of ${week.planned} sessions',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < dots; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < filled ? FitColors.ink : null,
                      border: Border.all(
                        color: i < filled ? FitColors.ink : FitColors.ink35,
                        width: 1.5,
                      ),
                    ),
                  ),
                if (extra > 0)
                  Text(
                    '+$extra',
                    key: ValueKey('progress.consistency.${week.isoWeek}.extra'),
                    style: textTheme.bodySmall?.copyWith(
                      color: FitColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dots == 0 && extra == 0)
                  Text('—', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '$from · ${week.completed}/${week.planned}',
              key: ValueKey('progress.consistency.${week.isoWeek}'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same weeks, statuses and words as the Volume screen (reused, not recomputed).
class _VolumeHeatmap extends ConsumerWidget {
  const _VolumeHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final v = ref.watch(volumeProvider).value!;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final weeks = v.weeks;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.lg),
      child: _Pad(
        child: Column(
          key: const ValueKey('progress.volume'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Weekly volume per muscle', style: textTheme.titleSmall),
            const SizedBox(height: FitSpacing.sm),
            for (final muscle in v.owned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Text(
                        muscle.label,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final (i, w) in weeks.indexed)
                      Expanded(
                        flex: 2,
                        child: _Cell(
                          key: ValueKey('progress.volume.${muscle.wire}.$i'),
                          status: w.muscles
                                  .where((m) => m.muscle == muscle)
                                  .firstOrNull
                                  ?.status ??
                              LandmarkStatus.none,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: FitSpacing.sm),
            Wrap(
              spacing: FitSpacing.md,
              runSpacing: FitSpacing.xs,
              children: <Widget>[
                // Beta 4.1.1: from too little to too much, then none.
                for (final s in [
                  ...VolumeLegend.order,
                  LandmarkStatus.none,
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(width: 14, child: _Cell(status: s, height: 10)),
                      const SizedBox(width: FitSpacing.xs),
                      Text(VolumeWording.label(s), style: muted),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'Oldest week on the left; this week on the right.',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.status, this.height = 18, super.key});

  final LandmarkStatus status;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: VolumeWording.label(status),
        child: Container(
          height: height,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: status == LandmarkStatus.none
                ? null
                : VolumeWording.color(status).withValues(alpha: 0.8),
            border: Border.all(color: FitColors.rule),
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
        ),
      );
}

/* ------------------------------------------------------------- adherence -- */

class _AdherenceSection extends StatelessWidget {
  const _AdherenceSection({required this.summary});

  final ProgressSummary summary;

  static _Stat _tile(String label, AdherenceCount c, String key) => c.of == 0
      ? _Stat(
          label: label,
          value: '—',
          caption: 'No logged days with a target yet',
          valueKey: ValueKey(key),
          captionKey: ValueKey('$key.days'),
          muted: true,
        )
      : _Stat(
          label: label,
          value: c.percent == null ? '${c.met}/${c.of}' : '${c.percent}%',
          caption: '${c.met} of ${c.of} logged days',
          valueKey: ValueKey(key),
          captionKey: ValueKey('$key.days'),
          bar: c.met / c.of,
        );

  @override
  Widget build(BuildContext context) {
    final a = summary.adherence;
    return _StatGrid([
      _tile('Protein target met', a.protein, 'progress.adherence.protein'),
      _tile('Calories on target', a.calories, 'progress.adherence.calories'),
    ]);
  }
}
