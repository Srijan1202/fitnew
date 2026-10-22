import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../premium/domain/avatars.dart';
import '../../premium/presentation/premium_providers.dart';
import '../../premium/presentation/premium_sheet.dart';
import '../data/weekly_report_api.dart';
import '../../../shared/widgets/fit_glass.dart';

final weeklyReportApiProvider = Provider<WeeklyReportApi>(
  (ref) => DioWeeklyReportApi(ref.watch(dioProvider)),
);

/// The report for a week (null = the current one).
final weeklyReportProvider = FutureProvider.family<WeeklyReport, String?>(
  (ref, week) async {
    requireSession(ref);
    final r = await ref.watch(weeklyReportApiProvider).report(week: week);
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Phase 19 (ADR-027, premium): the weekly report — this week or one of the
/// three before it. A free user sees what premium is instead.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  String? _week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    final report = locked ? null : ref.watch(weeklyReportProvider(_week));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('WEEKLY REPORT', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              if (locked)
                const PremiumPitch(
                  key: ValueKey('weekly.premium'),
                  feature: 'The weekly report',
                )
              else
                ...report!.when(
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.all(FitSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => <Widget>[
                    Text(
                      (e is Failure ? e : const Unknown()).message,
                      key: const ValueKey('weekly.error'),
                    ),
                    if (e is Forbidden && e.issue == 'premium-required')
                      TextButton(
                        onPressed: () => showPremiumSheet(
                          context,
                          feature: 'The weekly report',
                        ),
                        child: const Text('See Premium'),
                      ),
                  ],
                  data: (r) => _body(context, r),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, WeeklyReport r) {
    final textTheme = Theme.of(context).textTheme;
    final i = r.weeks.indexOf(r.isoWeek);
    return <Widget>[
      Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey('weekly.prev'),
            onPressed:
                i > 0 ? () => setState(() => _week = r.weeks[i - 1]) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Earlier week',
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  r.complete ? 'Week of ${r.from}' : 'This week so far',
                  key: const ValueKey('weekly.title'),
                  style: textTheme.titleLarge,
                ),
                Text('${r.from} – ${r.to}', style: textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('weekly.next'),
            onPressed: i >= 0 && i < r.weeks.length - 1
                ? () => setState(() => _week = r.weeks[i + 1])
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Later week',
          ),
        ],
      ),
      const SizedBox(height: FitSpacing.md),
      Container(
        padding: const EdgeInsets.all(FitSpacing.md),
        decoration: fitGlass
            ? FitBlock.decoration(glow: true).copyWith(
                border: Border.all(color: kGold.withValues(alpha: 0.55)),
              )
            : BoxDecoration(border: Border.all(color: kGold)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final h in r.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Text(
                  h,
                  key: ValueKey('weekly.highlight.${r.highlights.indexOf(h)}'),
                  style: textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: FitSpacing.lg),
      _Fact(
        label: 'SESSIONS',
        value: r.sessionsPlanned == null
            ? '${r.sessionsCompleted}'
            : '${r.sessionsCompleted} / ${r.sessionsPlanned}',
      ),
      _Fact(label: 'HARD SETS', value: _num(r.totalHardSets)),
      _Fact(label: 'PERSONAL RECORDS', value: '${r.prCount}'),
      _Fact(
        label: 'PROTEIN DAYS',
        value: r.judgedDays == 0 ? '—' : '${r.proteinMet} / ${r.judgedDays}',
      ),
      _Fact(
        label: 'CALORIE DAYS ON TARGET',
        value: r.judgedDays == 0 ? '—' : '${r.caloriesOn} / ${r.judgedDays}',
      ),
      _Fact(
        label: 'TREND WEIGHT',
        value: r.weightChangeKg == null
            ? '—'
            : '${r.weightChangeKg! > 0 ? '+' : ''}${r.weightChangeKg!.toStringAsFixed(1)} kg',
      ),
    ];
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.rule)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: textTheme.labelSmall)),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}
