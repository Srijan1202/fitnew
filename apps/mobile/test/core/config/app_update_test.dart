import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/config/app_update.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;

/// Beta 3.2 (ADR-026 amendment): "a new version is available". The website's
/// version.json is the source; the app asks once per new build, then keeps a
/// Home banner until updated or hidden; at most one read every six hours;
/// offline or a bad file shows nothing; only tryfitos.me is ever opened.
class FakeFeed implements ReleaseFeed {
  FakeFeed(this.release);
  LatestRelease? release;
  int reads = 0;

  @override
  Future<LatestRelease?> latest() async {
    reads += 1;
    return release;
  }
}

class MemoryPrefs implements UpdatePrefs {
  DateTime? checked;
  LatestRelease? release;

  @override
  Future<DateTime?> lastChecked() async => checked;
  @override
  Future<LatestRelease?> cached() async => release;
  @override
  Future<void> saveCheck(DateTime at, LatestRelease? r) async {
    checked = at;
    if (r != null) release = r;
  }
}

class FakeOpener implements LinkOpener {
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

const beta32 = LatestRelease(
  version: '1.0.0-beta.3.2',
  build: 8,
  url: 'https://tryfitos.me/download/',
  notesUrl: 'https://tryfitos.me/blog/beta-3-2/',
);

void main() {
  late FakeFeed feed;
  late MemoryPrefs prefs;
  late FakeOpener opener;
  var now = DateTime.utc(2026, 10, 24, 9);

  setUp(() {
    feed = FakeFeed(beta32);
    prefs = MemoryPrefs();
    opener = FakeOpener();
    now = DateTime.utc(2026, 10, 24, 9);
  });

  List<Override> overrides({int build = 7}) => [
        appBuildProvider.overrideWith((_) async => build),
        releaseFeedProvider.overrideWithValue(feed),
        updatePrefsProvider.overrideWithValue(prefs),
        linkOpenerProvider.overrideWithValue(opener),
        updateClockProvider.overrideWithValue(() => now),
      ];

  Future<AvailableUpdate?> check({int build = 7}) async {
    final c = ProviderContainer(overrides: overrides(build: build));
    addTearDown(c.dispose);
    return c.read(updateControllerProvider.future);
  }

  group('the check', () {
    test(
        'a newer build: due for the dialog and the banner; the same or an older build: nothing',
        () async {
      final u = await check();
      expect(u, isNotNull);
      expect(u!.release.label, 'beta 3.2');
      expect(u.promptDue, isTrue);
      expect(u.bannerVisible, isTrue);
      expect(await check(build: 8), isNull);
      expect(await check(build: 9), isNull);
    });

    test('at most one read an hour: the cached answer is used in between',
        () async {
      await check();
      expect(feed.reads, 1);
      now = now.add(const Duration(minutes: 59));
      feed.release = null; // would hide it if read
      expect(await check(), isNotNull);
      expect(feed.reads, 1);
      now = now.add(const Duration(minutes: 1));
      await check();
      expect(feed.reads, 2);
    });

    test(
        'offline or a bad file: nothing new is learnt, nothing is shown, and it is not retried at once',
        () async {
      feed.release = null;
      expect(await check(), isNull);
      expect(feed.reads, 1);
      expect(await check(), isNull);
      expect(feed.reads, 1);
      expect(
        LatestRelease.fromJson(
          <String, dynamic>{'version': 'x', 'build': '8', 'url': 'u'},
        ),
        isNull,
      );
      expect(LatestRelease.fromJson('nope'), isNull);
    });

    test('every open asks again: the dialog and the banner are due each time',
        () async {
      expect((await check())!.promptDue, isTrue);
      now = now.add(const Duration(minutes: 1));
      final again = await check();
      expect(again!.promptDue, isTrue);
      expect(again.bannerVisible, isTrue);
    });

    test('only tryfitos.me is ever opened', () {
      expect(
        LatestRelease.safe('https://tryfitos.me/download/'),
        'https://tryfitos.me/download/',
      );
      expect(LatestRelease.safe('https://evil.example/apk'), kDownloadUrl);
      expect(LatestRelease.safe('http://tryfitos.me/download/'), kDownloadUrl);
      expect(LatestRelease.safe(null), kDownloadUrl);
    });
  });

  group('on screen', () {
    Widget host() => ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: FitTheme.build(),
            home: const Scaffold(
              body: Column(
                children: <Widget>[UpdatePromptHost(), UpdateBanner()],
              ),
            ),
          ),
        );

    testWidgets(
        'the dialog at every open; Later leaves the banner; the banner opens the download page or hides until the next open',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('update.dialog')),
          matching: find.text('FITOS beta 3.2 is out'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('update.later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.dialog')), findsNothing);
      expect(find.byKey(const ValueKey('update.banner')), findsOneWidget);
      expect(opener.opened, isEmpty);

      await tester.tap(find.byKey(const ValueKey('update.banner.open')));
      await tester.pump();
      expect(opener.opened, ['https://tryfitos.me/download/']);

      await tester.tap(find.byKey(const ValueKey('update.banner.hide')));
      await tester.pump();
      expect(find.byKey(const ValueKey('update.banner')), findsNothing);

      // The next open: asked again, banner back.
      await tester.pumpWidget(Container());
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update.later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.banner')), findsOneWidget);
    });

    testWidgets('waits while a workout is in progress', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: FitTheme.build(),
            home: Scaffold(
              body: UpdatePromptHost(suppressed: () => true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.dialog')), findsNothing);
    });

    test('a return after 5 minutes away is a new open; a quick switch is not',
        () {
      var clock = DateTime(2026, 10, 24, 9);
      var reopened = 0;
      final c = UpdateCheckCoordinator(() => reopened++, now: () => clock);
      addTearDown(c.dispose);
      c.hidden();
      clock = clock.add(const Duration(minutes: 2));
      c.resumed();
      expect(reopened, 0);
      c.hidden();
      clock = clock.add(kUpdatePromptAfterAway);
      c.resumed();
      expect(reopened, 1);
      c.resumed(); // a resume without a hide changes nothing
      expect(reopened, 1);
    });

    testWidgets('Update in the dialog opens the download page', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update.now')));
      await tester.pumpAndSettle();
      expect(opener.opened, ['https://tryfitos.me/download/']);
    });

    testWidgets('the too-old screen has a Download button to the website',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: FitTheme.build(),
            home: const UpdateRequiredScreen(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('update.required.download')));
      await tester.pump();
      expect(opener.opened, [kDownloadUrl]);
    });
  });
}
