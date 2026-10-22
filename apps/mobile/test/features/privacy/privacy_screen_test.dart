import 'dart:io';

import 'package:fitos/core/diagnostics/crash_reporting.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/privacy/presentation/policy_text.dart';
import 'package:fitos/features/privacy/presentation/privacy_providers.dart';
import 'package:fitos/features/privacy/presentation/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_privacy_api.dart';

class _RecordingSharer implements ExportSharer {
  final shared = <(String, String)>[];
  @override
  Future<void> share(String json, String fileName) async =>
      shared.add((json, fileName));
}

int erased = 0;

class _RecordingEraser extends AccountEraser {
  _RecordingEraser(super.ref);
  @override
  Future<void> eraseLocal() async => erased++;
}

/// Phase 17 (§23, ADR-023): the Privacy & data screen — FITOS AI consent,
/// re-consent after a policy change, download my data, delete my account
/// (typed DELETE, then everything local wiped), and the policy itself.
void main() {
  late FakePrivacyApi api;
  late _RecordingSharer sharer;
  late NoCrashReporter reporter;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    reporter = NoCrashReporter();
    api = FakePrivacyApi(aiGranted: false);
    sharer = _RecordingSharer();
    erased = 0;
  });

  Widget app() {
    final router = GoRouter(
      initialLocation: Routes.privacy,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold()),
        GoRoute(
          path: Routes.privacy,
          builder: (_, __) => const PrivacyScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        privacyApiProvider.overrideWithValue(api),
        exportSharerProvider.overrideWithValue(sharer),
        accountEraserProvider.overrideWith(_RecordingEraser.new),
        crashReporterProvider.overrideWithValue(reporter),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 16000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets(
      'Phase 19: crash reports are on by default; off tells the reporter and is remembered on this phone',
      (tester) async {
    await open(tester);
    final tile = key('privacy.crash');
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(reporter.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kCrashReportsPreference), isFalse);
    expect(await crashReportsEnabled(), isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(reporter.enabled, isTrue);
    expect(prefs.getBool(kCrashReportsPreference), isTrue);
  });

  testWidgets(
      'FITOS AI consent: shown as it is, switched on and off through the server',
      (tester) async {
    await open(tester);
    expect(tester.widget<SwitchListTile>(key('privacy.ai')).value, isFalse);
    await tester.tap(key('privacy.ai'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('set ai-processing true'));
    expect(tester.widget<SwitchListTile>(key('privacy.ai')).value, isTrue);
    await tester.tap(key('privacy.ai'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('set ai-processing false'));
    expect(key('privacy.reconsent'), findsNothing);
  });

  testWidgets(
      'a changed policy asks to accept it again; accepting re-grants the required purposes',
      (tester) async {
    api.needsReconsent = true;
    await open(tester);
    expect(key('privacy.reconsent'), findsOneWidget);
    await tester.tap(key('privacy.reconsent.accept'));
    await tester.pumpAndSettle();
    expect(
      api.calls,
      containsAll(
        ['set privacy-policy true', 'set health-data-processing true'],
      ),
    );
    expect(key('privacy.reconsent'), findsNothing);
  });

  testWidgets(
      'download my data: the server export handed to the share sheet as a dated JSON file',
      (tester) async {
    await open(tester);
    await tester.tap(key('privacy.download'));
    await tester.pumpAndSettle();
    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single.$1, api.exportBody);
    expect(
      sharer.shared.single.$2,
      matches(RegExp(r'^fitos-export-\d{4}-\d{2}-\d{2}\.json$')),
    );
    expect(key('privacy.message'), findsOneWidget);
  });

  testWidgets(
      'delete: only after typing DELETE; then the server deletes and the phone is wiped',
      (tester) async {
    await open(tester);
    await tester.tap(key('privacy.delete'));
    await tester.pumpAndSettle();
    expect(key('privacy.delete.dialog'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(key('privacy.delete.go')).onPressed,
      isNull,
    );
    await tester.enterText(key('privacy.delete.confirm'), 'delete');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(key('privacy.delete.go')).onPressed,
      isNull,
    );
    await tester.enterText(key('privacy.delete.confirm'), 'DELETE');
    await tester.pump();
    await tester.tap(key('privacy.delete.go'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('delete'));
    expect(erased, 1);
  });

  testWidgets('a failed delete says so and wipes nothing', (tester) async {
    api.deleteFailure = const Offline();
    await open(tester);
    await tester.tap(key('privacy.delete'));
    await tester.pumpAndSettle();
    await tester.enterText(key('privacy.delete.confirm'), 'DELETE');
    await tester.pump();
    await tester.tap(key('privacy.delete.go'));
    await tester.pumpAndSettle();
    expect(key('privacy.message'), findsOneWidget);
    expect(erased, 0);
  });

  testWidgets('the policy is on the screen with its version', (tester) async {
    await open(tester);
    expect(
      find.text('PRIVACY POLICY · VERSION $kPolicyVersion'),
      findsOneWidget,
    );
    for (final (title, _) in kPolicySections) {
      expect(find.text(title), findsWidgets);
    }
  });

  test(
      'the app shows the same policy as docs/legal/privacy-policy.md, at the server\'s version',
      () {
    final doc = File('../../docs/legal/privacy-policy.md').readAsStringSync();
    expect(doc, contains('**Version** $kPolicyVersion'));
    final headings = RegExp(r'^## (.+)$', multiLine: true)
        .allMatches(doc)
        .map((m) => m.group(1))
        .toList();
    expect(headings, [for (final (t, _) in kPolicySections) t]);
    for (final (_, body) in kPolicySections) {
      expect(doc, contains(body));
    }
    final contracts =
        File('../../packages/contracts/src/onboarding.ts').readAsStringSync();
    expect(contracts, contains("CURRENT_POLICY_VERSION = '$kPolicyVersion'"));
  });
}
