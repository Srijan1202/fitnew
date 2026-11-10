import 'dart:convert';
import 'dart:typed_data';

import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/progress/data/monthly_report_api.dart';
import 'package:fitos/features/progress/presentation/monthly_report_pdf.dart';
import 'package:fitos/features/progress/presentation/monthly_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MonthlyReport _report({String month = '2026-10', bool complete = true}) =>
    MonthlyReport.fromJson({
      'month': month,
      'from': '$month-01',
      'to': '$month-31',
      'complete': complete,
      'months': ['2026-09', '2026-10', '2026-11'],
      'training': {
        'completed': 15,
        'planned': 18,
        'percent': 83,
        'hardSets': 182,
        'tonnageKg': 39900,
        'topMuscles': [
          {'muscle': 'back', 'hardSets': 52},
          {'muscle': 'chest', 'hardSets': 48},
        ],
      },
      'prs': {
        'count': 3,
        'lifts': ['Bench', 'Squat'],
      },
      'running': {'runs': 2, 'km': 15.1},
      'nutrition': {
        'loggedDays': 20,
        'judgedDays': 20,
        'proteinMet': 12,
        'caloriesOn': 14,
        'averageKcal': 2310,
      },
      'water': {'loggedDays': 9, 'daysAtTarget': 6, 'targetMl': 2500},
      'recovery': {'checkIns': 11, 'averageSleepHours': 7.2},
      'weight': {'startKg': 71.9, 'endKg': 71.2, 'changeKg': -0.7},
      'highlights': ['15 of 18 planned sessions.', '2 runs, 15.1 km.'],
    });

class _Api implements MonthlyReportApi {
  final asked = <String?>[];
  @override
  Future<Result<MonthlyReport>> report({String? month}) async {
    asked.add(month);
    return Ok(_report(month: month ?? '2026-11', complete: month != null));
  }
}

class _Sharer implements ReportSharer {
  Uint8List? pdf;
  String? name;
  @override
  Future<void> share(Uint8List pdf, String fileName) async {
    this.pdf = pdf;
    name = fileName;
  }
}

/// Beta 6.1 (premium): the monthly report and its PDF, made on the phone.
void main() {
  test('the PDF is a real PDF, and its rows say what the month holds',
      () async {
    final r = _report();
    final bytes =
        await monthlyReportPdf(r, name: 'Srijan', made: DateTime(2026, 11, 10));
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(1500));
    final rows = {
      for (final (_, rs) in monthlySections(r))
        for (final (l, v) in rs) l.trim(): v,
    };
    expect(rows['Sessions'], '15 of 18 planned (83%)');
    expect(rows['Back'], '52 sets');
    expect(rows['Personal records'], '3 (Bench, Squat)');
    // Emulator check: thousands, a capital, and one set is a set.
    expect(rows['Weight moved'], '39,900 kg');
    expect(rows['Average a logged day'], '2,310 kcal');
    expect(rows['Distance'], '15.1 km');
    expect(rows['Protein target reached'], '12 of 20 days');
    expect(rows['Water target reached'], '6 of 9 days (2.5 L)');
    expect(rows['Average sleep'], '7.2 h');
    expect(rows['Trend weight'], '71.9 to 71.2 kg (-0.7)');
  });

  test('PDF text keeps to what the built-in font can draw', () {
    expect(pdfSafe('Srijan – “best” month…'), 'Srijan - "best" month...');
    expect(pdfSafe('श्रीजन Srijan'), 'Srijan');
    expect(pdfSafe('Café'), 'Café');
  });

  Widget app({required bool? premium, _Api? api, _Sharer? sharer}) =>
      ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('u1'),
          isPremiumProvider.overrideWithValue(premium),
          monthlyReportApiProvider.overrideWithValue(api ?? _Api()),
          reportSharerProvider.overrideWithValue(sharer ?? _Sharer()),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const MonthlyReportScreen(),
        ),
      );

  testWidgets('a free account sees what Premium is', (tester) async {
    final api = _Api();
    await tester.pumpWidget(app(premium: false, api: api));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('monthly.premium')), findsOneWidget);
    expect(api.asked, isEmpty);
  });

  testWidgets(
      'premium: this month, an earlier one, and Share as PDF hands a PDF to the share sheet',
      (tester) async {
    final api = _Api();
    final sharer = _Sharer();
    await tester.pumpWidget(app(premium: true, api: api, sharer: sharer));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('So far'), findsOneWidget);
    expect(find.text('15 of 18 planned sessions.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monthly.prev')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(api.asked, [null, '2026-10']);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monthly.pdf')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('monthly.pdf')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(sharer.name, 'fitos-report-2026-10.pdf');
    expect(latin1.decode(sharer.pdf!.sublist(0, 5)), '%PDF-');
  });
}
