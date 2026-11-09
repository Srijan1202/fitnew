import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../auth/domain/entities/auth_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../premium/domain/avatars.dart';
import '../../premium/presentation/premium_providers.dart';
import '../../premium/presentation/premium_sheet.dart';
import '../data/monthly_report_api.dart';
import 'monthly_report_pdf.dart';

final monthlyReportApiProvider = Provider<MonthlyReportApi>(
  (ref) => DioMonthlyReportApi(ref.watch(dioProvider)),
);

/// The report for a month (null = this one).
final monthlyReportProvider = FutureProvider.family<MonthlyReport, String?>(
  (ref, month) async {
    requireSession(ref);
    final r = await ref.watch(monthlyReportApiProvider).report(month: month);
    return r.when(ok: (v) => v, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Hands the PDF to the system share sheet (save to Files, Drive, WhatsApp…).
abstract class ReportSharer {
  Future<void> share(Uint8List pdf, String fileName);
}

class SystemReportSharer implements ReportSharer {
  @override
  Future<void> share(Uint8List pdf, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdf, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'My FITOS monthly report',
      ),
    );
  }
}

final reportSharerProvider =
    Provider<ReportSharer>((_) => SystemReportSharer());

/// Beta 6.1 (premium): the monthly report — this month or one of the 12
/// before it — on screen, and as a PDF made on the phone.
class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  String? _month;
  bool _making = false;

  Future<void> _share(MonthlyReport r) async {
    setState(() => _making = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? name;
      try {
        final auth = ref.read(authControllerProvider).value;
        if (auth is AuthSignedIn) name = auth.profile.displayName;
      } on Object {
        // No name on the PDF, then.
      }
      final pdf = await monthlyReportPdf(r, name: name);
      await ref
          .read(reportSharerProvider)
          .share(pdf, 'fitos-report-${r.month}.pdf');
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not make the PDF. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = ref.watch(isPremiumProvider) == false;
    final report = locked ? null : ref.watch(monthlyReportProvider(_month));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('MONTHLY REPORT', style: textTheme.labelSmall),
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
                  key: ValueKey('monthly.premium'),
                  feature: 'The monthly report',
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
                      key: const ValueKey('monthly.error'),
                    ),
                    if (e is Forbidden && e.issue == 'premium-required')
                      TextButton(
                        onPressed: () => showPremiumSheet(
                          context,
                          feature: 'The monthly report',
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

  List<Widget> _body(BuildContext context, MonthlyReport r) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: FitColors.ink60);
    final i = r.months.indexOf(r.month);
    return <Widget>[
      Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey('monthly.prev'),
            onPressed:
                i > 0 ? () => setState(() => _month = r.months[i - 1]) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Earlier month',
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  MonthlyReport.monthName(r.month),
                  key: const ValueKey('monthly.title'),
                  style: textTheme.titleLarge,
                ),
                Text(r.complete ? 'The whole month' : 'So far', style: muted),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('monthly.next'),
            onPressed: i >= 0 && i < r.months.length - 1
                ? () => setState(() => _month = r.months[i + 1])
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Later month',
          ),
        ],
      ),
      const SizedBox(height: FitSpacing.md),
      FitBlock(
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final h in r.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(h, style: textTheme.bodyMedium),
              ),
          ],
        ),
      ),
      for (final (section, rows) in monthlySections(r)) ...<Widget>[
        const SizedBox(height: FitSpacing.md),
        Text(section.toUpperCase(), style: textTheme.labelSmall),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(label.trim(), style: muted)),
                const SizedBox(width: FitSpacing.sm),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: FitSpacing.lg),
      FilledButton.icon(
        key: const ValueKey('monthly.pdf'),
        onPressed: _making ? null : () => _share(r),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_making ? 'Making the PDF…' : 'Share as PDF'),
      ),
      const SizedBox(height: FitSpacing.xs),
      Text(
        'Made on your phone and never uploaded.',
        textAlign: TextAlign.center,
        style: muted?.copyWith(color: kGoldDeep),
      ),
    ];
  }
}
