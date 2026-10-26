part of 'home_sections.dart';

/// Sleep · Resting heart rate, or one honest line.
class RecoverySection extends StatelessWidget {
  const RecoverySection({
    required this.context,
    this.checkIn,
    super.key,
  });

  final HomeContext context;

  /// Phase 13: today's check-in and readiness from FITOS (null when there is
  /// none, or it has not loaded). The check-in's sleep stands in when Health
  /// Connect has none — found on the S24: a logged sleep still read
  /// "No data yet" here.
  final RecoveryToday? checkIn;

  @override
  Widget build(BuildContext buildContext) {
    final textTheme = Theme.of(buildContext).textTheme;
    final c = context;
    final h = c.health;
    final sleep = h?.sleep;
    final rhr = h?.restingHeartRate;
    bool readable(HealthMetric? m) =>
        m != null &&
        (m.availability == HealthAvailability.available ||
            m.availability == HealthAvailability.noData ||
            m.availability == HealthAvailability.temporarilyUnavailable);
    final anyGranted = readable(sleep) || readable(rhr);
    final loggedSleep = checkIn?.log?.sleepHours;
    final readiness = checkIn?.readiness;
    final unsupported = c.healthUnsupported;
    final connect = TextButton(
      key: const ValueKey('home.recovery.connect'),
      onPressed: () => buildContext.push(Routes.healthData),
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
    );
    if (!anyGranted && loggedSleep == null && readiness == null) {
      return FitBlock(
        margin: const EdgeInsets.symmetric(horizontal: FitSpacing.md),
        padding: const EdgeInsets.all(FitSpacing.md),
        flatPadding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              unsupported
                  ? 'Recovery metrics need Health Connect, which is not on this phone.'
                  : c.healthConnected
                      ? 'Allow sleep and heart-rate data to see recovery metrics.'
                      : 'Connect Health data to see recovery metrics.',
              key: const ValueKey('home.recovery.empty'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            if (!unsupported) connect,
          ],
        ),
      );
    }

    // Sleep: the phone's reading first; the check-in's when there is none.
    final _Block sleepBlock;
    if (sleep != null && sleep.isAvailable) {
      sleepBlock = _Block(
        label: 'Sleep',
        value: HomeSections.hm(sleep.value!),
        line: 'Last night',
        valueKey: const ValueKey('home.sleep'),
        onTap: () => buildContext.push(Routes.healthData),
      );
    } else if (loggedSleep != null) {
      sleepBlock = _Block(
        label: 'Sleep',
        value: HomeSections.hm(loggedSleep * 60),
        line: 'From your check-in',
        valueKey: const ValueKey('home.sleep'),
        onTap: () => buildContext.go(Routes.progress),
      );
    } else {
      sleepBlock = _Block(
        label: 'Sleep',
        value: sleep?.availability.blockText ?? 'Not logged',
        line: sleep == null ? 'Add it in your check-in' : 'Last night',
        valueKey: const ValueKey('home.sleep'),
        muted: true,
        onTap: () => sleep == null
            ? buildContext.go(Routes.progress)
            : buildContext.push(Routes.healthData),
      );
    }
    final blocks = <Widget>[
      sleepBlock,
      if (readable(rhr))
        _Block(
          label: 'Resting HR',
          value: rhr!.isAvailable
              ? '${rhr.value!.round()} bpm'
              : rhr.availability.blockText,
          line: rhr.isAvailable
              ? HomeSections.recorded(rhr.start, c.date)
              : 'Resting heart rate',
          valueKey: const ValueKey('home.rhr'),
          muted: !rhr.isAvailable,
          onTap: () => buildContext.push(Routes.healthData),
        ),
      if (readiness != null)
        _Block(
          label: 'Readiness',
          value: '${readiness.score}',
          line: readiness.band.label,
          valueKey: const ValueKey('home.readiness'),
          onTap: () => buildContext.go(Routes.progress),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Grid(blocks: blocks),
        if (!anyGranted && !unsupported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FitSpacing.screen),
            child: connect,
          ),
      ],
    );
  }
}

/// Weight · Body fat · BMR with the measurement's own date.
class BodySection extends StatelessWidget {
  const BodySection({required this.context, super.key});

  final HomeContext context;

  @override
  Widget build(BuildContext buildContext) {
    final c = context;
    final h = c.health!;
    _Block block(
      String label,
      HealthMetric m,
      String Function(double) fmt,
      String k,
    ) =>
        _Block(
          label: label,
          value: m.isAvailable ? fmt(m.value!) : m.availability.blockText,
          line: m.isAvailable ? HomeSections.recorded(m.start, c.date) : label,
          valueKey: ValueKey(k),
          muted: !m.isAvailable,
          onTap: () => buildContext.push(Routes.healthData),
        );
    return _Grid(
      blocks: <Widget>[
        // Phase 12 (§13.2): a Health Connect reading is raw device data — the
        // FITOS trend lives on Progress; this block is labelled as the raw one.
        block(
          'Weight · raw (device)',
          h.weight,
          (v) => '${HomeSections.kg(v)} kg',
          'home.weight',
        ),
        block(
          'Body fat',
          h.bodyFat,
          (v) => '${HomeSections.kg(v)}%',
          'home.bodyFat',
        ),
        if (h.bmr.availability != HealthAvailability.permissionDenied)
          block(
            'BMR',
            h.bmr,
            (v) => '${HomeSections.group(v)} kcal/day',
            'home.bmr',
          ),
      ],
    );
  }
}

/// Training · Movement · Sleep as "n / m" with seven dots each.
class WeekSection extends StatelessWidget {
  const WeekSection({required this.week, super.key});

  final WeekContext week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(String label, int done, int total, String key) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fitGlass ? FitSpacing.md : FitSpacing.screen,
            vertical: FitSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Text(label, style: textTheme.titleMedium),
              ),
              Expanded(
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < total; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i < done
                              ? (fitGlass ? FitColors.accent : FitColors.ink)
                              : Colors.transparent,
                          border: Border.all(
                            color: i < done
                                ? (fitGlass ? FitColors.accent : FitColors.ink)
                                : FitColors.ink35,
                          ),
                          // Dots on glass; the §6 squares on Paper.
                          shape:
                              fitGlass ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: fitGlass
                              ? null
                              : BorderRadius.all(FitRadius.small),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$done / $total',
                key: ValueKey(key),
                style: textTheme.titleMedium,
              ),
            ],
          ),
        );
    return FitBlock(
      margin: const EdgeInsets.symmetric(horizontal: FitSpacing.md),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      child: Column(
        children: <Widget>[
          const FitRule(),
          if (week.trainingPlanned > 0)
            row(
              'Training',
              week.trainingDone,
              week.trainingPlanned,
              'home.week.training',
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fitGlass ? FitSpacing.md : FitSpacing.screen,
                vertical: FitSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text('Training', style: textTheme.titleMedium),
                  ),
                  Expanded(
                    child: Text(
                      'No programme yet',
                      key: const ValueKey('home.week.training'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ),
                ],
              ),
            ),
          if (week.movementDays != null)
            row('Movement', week.movementDays!, 7, 'home.week.movement'),
          if (week.sleepDays != null)
            row('Sleep', week.sleepDays!, 7, 'home.week.sleep'),
          const FitRule(),
        ],
      ),
    );
  }
}

/// Phase 6.6 Gate 6: when the FITOS server cannot be reached and there is
/// nothing cached to show, say so in one line — with the failure's own words
/// (offline, signed out, server error) and a way to try again. Health data
/// below it still comes from the phone.
class ServerNotice extends StatelessWidget {
  const ServerNotice({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('home.serverNotice'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: FitColors.ink),
            bottom: BorderSide(color: FitColors.rule),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text("Can't reach FITOS", style: textTheme.titleMedium),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      '$message Your training plan and today\'s session need the server; Health data still shows from your phone.',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('home.serverNotice.retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
