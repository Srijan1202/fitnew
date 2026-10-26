part of 'progress_screen.dart';

/* ------------------------------------------------------------ get started -- */

/// What a section with nothing to show becomes: one line in "Get started",
/// with the way to give it something.
enum _Start { weight, training, food, measurement, photo, health }

class _GetStarted extends ConsumerWidget {
  const _GetStarted({required this.items});

  final List<_Start> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];
    for (final item in items) {
      if (rows.isNotEmpty) rows.add(const _RowRule());
      rows.add(
        switch (item) {
          // The same keys as the buttons the sections have once drawn.
          _Start.weight => _StartRow(
              rowKey: 'progress.weight.log',
              icon: Icons.monitor_weight_outlined,
              title: 'Log your weight',
              body: 'A few readings a week, and your trend line starts.',
              onTap: () => showWeightSheet(context),
            ),
          _Start.training => _StartRow(
              rowKey: 'progress.start.training',
              icon: Icons.fitness_center,
              title: 'Log a training session',
              body: 'Sessions, weekly volume and your best lifts appear here.',
              onTap: () => context.go(Routes.plan),
            ),
          _Start.food => _StartRow(
              rowKey: 'progress.start.food',
              icon: Icons.restaurant_outlined,
              title: 'Log a day of food',
              body: 'The days you meet your protein and calorie targets.',
              onTap: () => context.go(Routes.nutrition),
            ),
          _Start.measurement => _StartRow(
              rowKey: 'progress.measurement.log',
              icon: Icons.straighten,
              title: 'Add a measurement',
              body: 'Waist, chest, arm, thigh or hip — once a week is enough.',
              onTap: () => showMeasurementSheet(context),
            ),
          _Start.photo => _StartRow(
              rowKey: 'progress.start.photo',
              icon: Icons.add_a_photo_outlined,
              title: 'Take a progress photo',
              body:
                  'Kept on this phone only. The change is easier to see than to weigh.',
              onTap: () => addProgressPhoto(context, ref),
            ),
          _Start.health => _StartRow(
              rowKey: 'progress.start.health',
              icon: Icons.favorite_border,
              title: 'Connect Health data',
              body:
                  'Sleep and resting heart rate from this phone; never part of readiness.',
              onTap: () => context.push(Routes.healthData),
            ),
        },
      );
    }
    return Column(
      key: const ValueKey('progress.start'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String rowKey;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey(rowKey),
      onTap: onTap,
      child: _Pad(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 2),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: FitColors.ink60),
              const SizedBox(width: FitSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style:
                          textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FitSpacing.sm),
              Icon(Icons.chevron_right, color: FitColors.ink35),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------- recovery -- */

/// What the Recovery section has to go on: the server's readiness, and the
/// phone's own sleep and resting heart rate — or the check-in's sleep when
/// Health Connect has none.
class _RecoveryFacts {
  _RecoveryFacts._(this.home, this.today);

  factory _RecoveryFacts.of(WidgetRef ref) => _RecoveryFacts._(
        ref.watch(homeContextProvider),
        ref.watch(recoveryTodayProvider).value?.today,
      );

  final HomeContext home;
  final RecoveryToday? today;

  Readiness? get readiness => today?.readiness;
  HealthMetric? get sleep => home.health?.sleep;
  HealthMetric? get rhr => home.health?.restingHeartRate;
  double? get loggedSleep => today?.log?.sleepHours;

  static bool readable(HealthMetric? m) =>
      m != null &&
      (m.availability == HealthAvailability.available ||
          m.availability == HealthAvailability.noData ||
          m.availability == HealthAvailability.temporarilyUnavailable);

  bool get anyGranted => readable(sleep) || readable(rhr);

  /// Health Connect is on this phone but nothing is allowed yet.
  bool get canConnect => !home.healthUnsupported && !anyGranted;

  /// Something to draw: a readiness, or a sleep or heart-rate reading.
  bool get shown => readiness != null || anyGranted || loggedSleep != null;
}

/// Recovery: what went into today's readiness (ADR-019), then sleep and
/// resting heart rate as rows — or one line when Health Connect has none.
/// Health Connect data is never sent to the server and never part of
/// readiness (owner D1).
class _RecoveryDetails extends StatelessWidget {
  const _RecoveryDetails({required this.facts});

  final _RecoveryFacts facts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final f = facts;
    final sleep = f.sleep;
    final rhr = f.rhr;
    final logged = f.loggedSleep;
    final short = sleep != null &&
        sleep.isAvailable &&
        sleep.value! < HomeSuggestionEngine.lowSleepMinutes;
    final rows = <Widget>[
      // Sleep: the phone's reading first; the check-in's when there is none.
      if (sleep != null && sleep.isAvailable)
        _MetricRow(
          label: 'Sleep',
          value: HomeSections.hm(sleep.value!),
          line: 'Last night',
          valueKey: 'progress.sleep',
          onTap: () => context.push(Routes.healthData),
        )
      else if (logged != null)
        _MetricRow(
          label: 'Sleep',
          value: HomeSections.hm(logged * 60),
          line: 'From your check-in',
          valueKey: 'progress.sleep',
        )
      else if (_RecoveryFacts.readable(sleep))
        _MetricRow(
          label: 'Sleep',
          value: sleep!.availability.blockText,
          line: 'Last night',
          valueKey: 'progress.sleep',
          muted: true,
          onTap: () => context.push(Routes.healthData),
        ),
      if (_RecoveryFacts.readable(rhr))
        _MetricRow(
          label: 'Resting HR',
          value: rhr!.isAvailable
              ? '${rhr.value!.round()} bpm'
              : rhr.availability.blockText,
          line: rhr.isAvailable
              ? HomeSections.recorded(rhr.start, f.home.date)
              : 'Resting heart rate',
          valueKey: 'progress.rhr',
          muted: !rhr.isAvailable,
          onTap: () => context.push(Routes.healthData),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (f.readiness case final r?) ...<Widget>[
          _Pad(child: ReadinessDetails(readiness: r)),
          if (rows.isNotEmpty || !f.anyGranted) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            const _RowRule(),
          ],
        ],
        for (final (i, row) in rows.indexed) ...<Widget>[
          if (i > 0) const _RowRule(),
          row,
        ],
        if (!f.anyGranted)
          _Pad(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    f.home.healthUnsupported
                        ? 'Sleep and resting heart rate need Health Connect, which is not on this phone.'
                        : 'Connect Health data for sleep and resting heart rate from this phone.',
                    key: const ValueKey('progress.recovery.empty'),
                    style:
                        textTheme.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                  if (f.canConnect)
                    TextButton(
                      key: const ValueKey('progress.recovery.connect'),
                      onPressed: () => context.push(Routes.healthData),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(child: Text('Connect Health data')),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (short)
          _Pad(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm),
              child: Text(
                'Last night was under six hours. An easy day is a good day.',
                key: const ValueKey('progress.recovery.advisory'),
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        if (f.anyGranted)
          _Pad(
            child: Padding(
              padding: const EdgeInsets.only(top: FitSpacing.sm),
              child: Text(
                f.home.health?.fromCache ?? false
                    ? 'Health Connect did not answer just now; the last reading kept on this phone is shown. Not part of readiness.'
                    : 'Health Connect stays on this phone. Information only — not part of readiness.',
                key: const ValueKey('progress.recovery.note'),
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
              ),
            ),
          ),
      ],
    );
  }
}

/// A reading as a row: what it is, the value, and when.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.line,
    required this.valueKey,
    this.muted = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String line;
  final String valueKey;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final quiet = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    return InkWell(
      onTap: onTap,
      child: _Pad(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm + 2),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  key: ValueKey(valueKey),
                  style: muted
                      ? textTheme.bodyMedium?.copyWith(color: FitColors.ink60)
                      : textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: FitSpacing.sm),
              Flexible(
                flex: 3,
                child: Text(line, textAlign: TextAlign.end, style: quiet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
