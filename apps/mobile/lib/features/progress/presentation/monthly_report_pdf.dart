import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/monthly_report_api.dart';

/// Beta 6.1 (premium): the monthly report as a PDF, drawn on the phone and
/// handed to the share sheet; never uploaded. Plain sentences and numbers
/// FITOS already holds, ink on white with the Cobalt accent, so it prints
/// and reads the same whatever the app's theme.
const _accent = PdfColor.fromInt(0xFF2F5BEA);
const _ink = PdfColor.fromInt(0xFF15171C);
const _muted = PdfColor.fromInt(0xFF5E6470);
const _rule = PdfColor.fromInt(0xFFDADDE3);

String _kg(double v) => v.toStringAsFixed(1);

/// The built-in PDF font covers Latin-1 only: typographic marks become their
/// plain forms and anything else is left out (a name in another script is
/// dropped rather than drawn as empty boxes).
String pdfSafe(String s) {
  const plain = {
    0x2013: '-', 0x2014: '-', 0x2018: "'", 0x2019: "'", 0x201C: '"', //
    0x201D: '"', 0x2026: '...', 0x00A0: ' ', 0x2212: '-', 0x2009: ' ',
  };
  final out = StringBuffer();
  for (final r in s.runes) {
    if (plain.containsKey(r)) {
      out.write(plain[r]);
    } else if (r <= 0xFF) {
      out.writeCharCode(r);
    }
  }
  return out.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// The rows of each section, in the order the PDF draws them (also what the
/// tests read, since a PDF's text is compressed).
List<(String, List<(String, String)>)> monthlySections(MonthlyReport r) => [
      (
        'Training',
        [
          (
            'Sessions',
            r.sessionsPlanned != null && r.sessionsPlanned! > 0
                ? '${r.sessionsCompleted} of ${r.sessionsPlanned} planned'
                    '${r.percent == null ? '' : ' (${r.percent}%)'}'
                : '${r.sessionsCompleted}',
          ),
          ('Hard sets', r.hardSets.toStringAsFixed(0)),
          ('Weight moved', '${r.tonnageKg.toStringAsFixed(0)} kg'),
          for (final (muscle, sets) in r.topMuscles)
            ('  $muscle', '${sets.toStringAsFixed(0)} sets'),
          (
            'Personal records',
            r.prCount == 0 ? 'none' : '${r.prCount} (${r.prLifts.join(', ')})',
          ),
        ],
      ),
      (
        'Running',
        [
          ('Runs', '${r.runs}'),
          ('Distance', '${r.km.toStringAsFixed(1)} km'),
        ],
      ),
      (
        'Food',
        [
          ('Days logged', '${r.loggedDays}'),
          (
            'Protein target reached',
            r.judgedDays == 0
                ? '-'
                : '${r.proteinMet} of ${_plural(r.judgedDays, 'day')}',
          ),
          (
            'Calories within 10%',
            r.judgedDays == 0
                ? '-'
                : '${r.caloriesOn} of ${_plural(r.judgedDays, 'day')}',
          ),
          (
            'Average a logged day',
            r.averageKcal == null ? '-' : '${r.averageKcal} kcal',
          ),
        ],
      ),
      (
        'Water and recovery',
        [
          (
            'Water target reached',
            r.waterDays == 0
                ? '-'
                : '${r.waterDaysAtTarget} of ${_plural(r.waterDays, 'day')} '
                    '(${(r.waterTargetMl / 1000).toStringAsFixed(1)} L)',
          ),
          ('Check-ins', '${r.checkIns}'),
          (
            'Average sleep',
            r.averageSleepHours == null
                ? '-'
                : '${r.averageSleepHours!.toStringAsFixed(1)} h',
          ),
        ],
      ),
      (
        'Body weight',
        [
          (
            'Trend weight',
            r.weightStartKg == null
                ? 'not enough readings'
                : '${_kg(r.weightStartKg!)} to ${_kg(r.weightEndKg!)} kg '
                    '(${r.weightChangeKg! > 0 ? '+' : ''}${_kg(r.weightChangeKg!)})',
          ),
        ],
      ),
    ];

Future<Uint8List> monthlyReportPdf(
  MonthlyReport r, {
  String? name,
  DateTime? made,
}) async {
  final title = MonthlyReport.monthName(r.month);
  final doc = pw.Document(title: 'FITOS - $title', author: 'FITOS');
  final when = made ?? DateTime.now();
  final stamp =
      '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 40),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfSafe(
              'Made by FITOS on $stamp. Food and 1RM figures are estimates.',
            ),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            pdfSafe('${ctx.pageNumber} / ${ctx.pagesCount}'),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
      build: (ctx) => [
        pw.Text(
          pdfSafe('FITOS'),
          style: const pw.TextStyle(
            fontSize: 11,
            color: _accent,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          pdfSafe('Monthly report: $title'),
          style: const pw.TextStyle(
            fontSize: 22,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          pdfSafe(
              '${name == null || name.trim().isEmpty ? '' : '${name.trim()} - '}'
              '${r.from} to ${r.to}${r.complete ? '' : ' (so far)'}'),
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: _accent, width: 3)),
            color: PdfColor.fromInt(0xFFF3F5FA),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final h in r.highlights)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    pdfSafe(h),
                    style: const pw.TextStyle(fontSize: 11, color: _ink),
                  ),
                ),
            ],
          ),
        ),
        for (final (section, rows) in monthlySections(r)) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            pdfSafe(section.toUpperCase()),
            style: const pw.TextStyle(
              fontSize: 9,
              color: _accent,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          for (final (label, value) in rows)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _rule)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      pdfSafe(label),
                      style: const pw.TextStyle(fontSize: 10, color: _ink),
                    ),
                  ),
                  pw.Text(
                    pdfSafe(value),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}
