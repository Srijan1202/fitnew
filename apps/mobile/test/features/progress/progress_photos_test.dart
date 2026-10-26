import 'dart:async';
import 'dart:io';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/progress/data/progress_photos.dart';
import 'package:fitos/features/progress/domain/progress.dart';
import 'package:fitos/features/progress/presentation/photos/progress_photos_providers.dart';
import 'package:fitos/features/progress/presentation/photos/progress_photos_screen.dart';
import 'package:fitos/features/progress/presentation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Beta 3.4 (ADR-035): progress photos live on the phone only, in a folder
/// per account, out of Android's backup; added, filtered, compared, deleted;
/// gone with the account; hidden when switched off.
class FakePhotoSource implements PhotoSource {
  FakePhotoSource(this.dir);

  final Directory dir;
  int n = 0;
  bool? lastCamera;
  bool cancel = false;

  /// When set, the pick waits for it (the camera app is open).
  Completer<void>? hold;

  @override
  Future<String?> pick({
    required bool camera,
    NavigatorState? navigator,
  }) async {
    lastCamera = camera;
    if (hold != null) await hold!.future;
    if (cancel) return null;
    n++;
    final f = File('${dir.path}/picked-$n.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, n]);
    return f.path;
  }

  /// A photo Android kept after closing FITOS (beta 3.6), handed back once.
  String? lost;

  @override
  Future<String?> recoverLost() async {
    final l = lost;
    lost = null;
    return l;
  }
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('fitos-photos-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('PhotoStore', () {
    File source(String name) =>
        File('${tmp.path}/$name')..writeAsBytesSync([1, 2, 3]);

    test('adds a copy, lists newest day first, deletes one or all', () async {
      final store = PhotoStore(Directory('${tmp.path}/acc-1'));
      expect(await store.list(), isEmpty);
      final a = await store.add(
        source: source('a.jpg').path,
        date: '2026-09-01',
        pose: PhotoPose.front,
        weightKg: 70.4,
      );
      final b = await store.add(
        source: source('b.jpg').path,
        date: '2026-10-20',
        pose: PhotoPose.side,
      );
      final list = await store.list();
      expect(list.map((x) => x.id), [b.id, a.id]);
      expect(list.last.weightKg, 70.4);
      expect(list.first.weightKg, isNull);
      expect(File(a.path).existsSync(), isTrue);
      expect(a.path, startsWith(store.dir.path));

      await store.delete(a.id);
      expect(File(a.path).existsSync(), isFalse);
      expect((await store.list()).map((x) => x.id), [b.id]);

      await store.deleteAll();
      expect(store.dir.existsSync(), isFalse);
      expect(await store.list(), isEmpty);
    });

    test('each account has its own folder; a damaged index reads as empty',
        () async {
      final one = PhotoStore(Directory('${tmp.path}/one'));
      final two = PhotoStore(Directory('${tmp.path}/two'));
      await one.add(
        source: source('x.jpg').path,
        date: '2026-10-01',
        pose: PhotoPose.back,
      );
      expect(await two.list(), isEmpty);
      File('${one.dir.path}/index.json').writeAsStringSync('{not json');
      expect(await one.list(), isEmpty);
      expect(PhotoPose.byName('nope'), PhotoPose.other);
    });
  });

  test('the trend for a photo: that day, else the latest within a week before',
      () {
    const pts = [
      WeightPoint(date: '2026-10-01', rawKg: 71, trendKg: 70.9),
      WeightPoint(date: '2026-10-10', rawKg: 70, trendKg: 70.5),
      WeightPoint(date: '2026-10-20', rawKg: 69, trendKg: 70.1),
    ];
    expect(trendNear(pts, '2026-10-10'), 70.5);
    expect(trendNear(pts, '2026-10-15'), 70.5);
    expect(trendNear(pts, '2026-10-19'), isNull);
    expect(trendNear(pts, '2026-09-20'), isNull);
  });

  test('the photos folder is left out of Android backup and device transfer',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    final full = File('android/app/src/main/res/xml/backup_rules.xml')
        .readAsStringSync();
    expect(full, contains('<exclude domain="file" path="progress_photos/" />'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    expect(
      '<exclude domain="file" path="progress_photos/" />'
          .allMatches(rules)
          .length,
      2,
    );
  });

  test(
      'deleting the account deletes its photos on this phone, and only its own',
      () async {
    Directory dirFor(String a) => Directory('${tmp.path}/store/$a');
    final c = ProviderContainer(
      overrides: [photoDirProvider.overrideWithValue((a) async => dirFor(a))],
    );
    addTearDown(c.dispose);
    final mine = PhotoStore(dirFor('me'));
    final theirs = PhotoStore(dirFor('them'));
    final src = File('${tmp.path}/x.jpg')..writeAsBytesSync([1]);
    await mine.add(source: src.path, date: '2026-10-01', pose: PhotoPose.front);
    await theirs.add(
      source: src.path,
      date: '2026-10-01',
      pose: PhotoPose.front,
    );
    await c.read(accountPhotoEraserProvider)('me');
    expect(dirFor('me').existsSync(), isFalse);
    expect(await theirs.list(), hasLength(1));
  });

  group('screens', () {
    late AppDatabase db;
    late FakePhotoSource source;
    late FakeMetaApi meta;
    late GoRouter router;

    setUp(() {
      db = AppDatabase.inMemory();
      source = FakePhotoSource(tmp);
      meta = FakeMetaApi();
    });
    tearDown(() => db.close());

    Widget app({bool lostPhotoHost = false}) {
      router = GoRouter(
        initialLocation: Routes.progress,
        routes: [
          GoRoute(
            path: '/elsewhere',
            builder: (_, __) => const Scaffold(body: Text('elsewhere')),
          ),
          GoRoute(
            path: Routes.progress,
            builder: (_, __) => const ProgressScreen(),
            routes: [
              GoRoute(
                path: 'photos',
                builder: (_, __) => const ProgressPhotosScreen(),
              ),
            ],
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()
              ..restoreResult = AuthState.signedIn(testProfile),
          ),
          sessionUserIdProvider.overrideWithValue('acc-1'),
          photoSourceProvider.overrideWithValue(source),
          photoDirProvider.overrideWithValue(
            (account) async => Directory('${tmp.path}/store/$account'),
          ),
          ...workoutOverrides(db, FakeWorkoutApi(), meta: meta),
        ],
        child: MaterialApp.router(
          theme: FitTheme.build(),
          routerConfig: router,
          builder: lostPhotoHost
              ? (context, child) => Stack(
                    children: <Widget>[
                      Positioned.fill(child: child ?? const SizedBox.shrink()),
                      LostPhotoHost(
                        navigatorContext: () =>
                            router.routerDelegate.navigatorKey.currentContext,
                      ),
                    ],
                  )
              : null,
        ),
      );
    }

    Future<List<ProgressPhoto>> stored() =>
        PhotoStore(Directory('${tmp.path}/store/acc-1')).list();

    Future<void> tall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
    }

    Future<void> add(
      WidgetTester tester, {
      required bool camera,
      PhotoPose pose = PhotoPose.front,
    }) async {
      // Beta 3.9: before the first photo, the way in is a "Get started" line.
      final card = find.byKey(const ValueKey('photos.add'));
      final button = card.evaluate().isEmpty
          ? find.byKey(const ValueKey('progress.start.photo'))
          : card;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey(camera ? 'photos.source.camera' : 'photos.source.gallery'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('photos.pose.${pose.name}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.save')));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'Progress → Photos: add from the camera and the gallery; the note says they stay on the phone',
        (tester) async {
      await tall(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      // No photo yet: a line in "Get started", saying where they are kept.
      expect(find.byKey(const ValueKey('photos.card')), findsNothing);
      expect(
        find.byKey(const ValueKey('progress.start.photo')),
        findsOneWidget,
      );
      expect(find.textContaining('Kept on this phone only'), findsOneWidget);

      await add(tester, camera: true);
      expect(source.lastCamera, isTrue);
      // The first photo brings the Body section and its card.
      expect(find.byKey(const ValueKey('photos.card')), findsOneWidget);
      expect(find.textContaining('Photos stay on this phone'), findsOneWidget);
      expect(find.byKey(const ValueKey('progress.start.photo')), findsNothing);
      await add(tester, camera: false, pose: PhotoPose.side);
      expect(source.lastCamera, isFalse);
      final stored =
          await PhotoStore(Directory('${tmp.path}/store/acc-1')).list();
      expect(
        stored.map((x) => x.pose).toSet(),
        {PhotoPose.front, PhotoPose.side},
      );
      expect(find.text('See all · Compare'), findsOneWidget);
    });

    testWidgets('a cancelled pick saves nothing', (tester) async {
      await tall(tester);
      source.cancel = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('progress.start.photo'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.source.camera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.details')), findsNothing);
      expect(
        await PhotoStore(Directory('${tmp.path}/store/acc-1')).list(),
        isEmpty,
      );
    });

    testWidgets(
        'all photos: filter by pose, compare the oldest and newest with the days between',
        (tester) async {
      await tall(tester);
      final store = PhotoStore(Directory('${tmp.path}/store/acc-1'));
      File src(int i) => File('${tmp.path}/s$i.jpg')..writeAsBytesSync([i]);
      await store.add(
        source: src(1).path,
        date: '2026-09-01',
        pose: PhotoPose.front,
        weightKg: 72.0,
      );
      await store.add(
        source: src(2).path,
        date: '2026-10-01',
        pose: PhotoPose.front,
        weightKg: 70.5,
      );
      await store.add(
        source: src(3).path,
        date: '2026-10-05',
        pose: PhotoPose.side,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final all = find.byKey(const ValueKey('photos.all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.byType(ProgressPhotosScreen), findsOneWidget);
      expect(find.byType(Image), findsNothing, reason: 'hidden until shown');
      expect(find.byKey(const ValueKey('photos.compare')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('photos.show')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.filter.side')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('photos.filter.side')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('photos.filter.all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.compare')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('compare.summary'))).data,
        '30 days apart · −1.5 kg',
      );
      await tester.tap(find.byKey(const ValueKey('compare.mode')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compare.slider')), findsOneWidget);
    });

    testWidgets(
        'beta 3.6: hidden until "Show photos", and hidden again when FITOS goes to the background',
        (tester) async {
      await tall(tester);
      final store = PhotoStore(Directory('${tmp.path}/store/acc-1'));
      for (var i = 1; i <= 2; i++) {
        await store.add(
          source: (File('${tmp.path}/h$i.jpg')..writeAsBytesSync([i])).path,
          date: '2026-10-0$i',
          pose: PhotoPose.front,
        );
      }
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('2 photos · hidden'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final show = find.byKey(const ValueKey('photos.show'));
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byKey(const ValueKey('photos.hidden')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('2 photos · hidden'), findsOneWidget);
    });

    testWidgets(
        'beta 3.6: a camera photo is kept even when the screen that asked for it was rebuilt meanwhile',
        (tester) async {
      await tall(tester);
      source.hold = Completer<void>();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('progress.start.photo'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.source.camera')));
      await tester.pump();
      // The camera app is open; FITOS returns to a rebuilt screen.
      router.go('/elsewhere');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress.start.photo')), findsNothing);
      source.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.details')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('photos.save')));
      await tester.pumpAndSettle();
      expect(await stored(), hasLength(1));
    });

    testWidgets(
        'beta 3.6: a photo Android kept after closing FITOS is offered on the next start; Add saves it, once',
        (tester) async {
      await tall(tester);
      source.lost = (File('${tmp.path}/lost.jpg')..writeAsBytesSync([9])).path;
      await tester.pumpWidget(app(lostPhotoHost: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.lost')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('photos.lost.add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.pose.side')));
      await tester.tap(find.byKey(const ValueKey('photos.save')));
      await tester.pumpAndSettle();
      expect((await stored()).single.pose, PhotoPose.side);
      await tester.pumpWidget(app(lostPhotoHost: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.lost')), findsNothing);
    });

    testWidgets('beta 3.6: Discard leaves the lost photo out', (tester) async {
      await tall(tester);
      source.lost = (File('${tmp.path}/lost.jpg')..writeAsBytesSync([9])).path;
      await tester.pumpWidget(app(lostPhotoHost: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photos.lost.discard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.details')), findsNothing);
      expect(await stored(), isEmpty);
    });

    testWidgets('switched off by the admin: no Photos section', (tester) async {
      await tall(tester);
      meta.flags = {'progress-photos': false};
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos.card')), findsNothing);
      expect(find.byKey(const ValueKey('progress.start.photo')), findsNothing);
    });
  });
}
