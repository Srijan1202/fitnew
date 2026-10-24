import 'dart:typed_data';

import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/feedback/data/feedback_api.dart';
import 'package:fitos/features/feedback/data/feedback_sources.dart';
import 'package:fitos/features/feedback/presentation/feedback_screen.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Beta 3.6: pictures from a scripted picker.
class FakePictureSource implements FeedbackPictureSource {
  List<Uint8List> next = const [];
  int? lastMax;

  @override
  Future<List<Uint8List>> pick({required bool camera, required int max}) async {
    lastMax = max;
    return next.take(max).toList();
  }
}

class FakeDeviceSource implements FeedbackDeviceSource {
  String? lastScreen;

  @override
  Future<FeedbackDevice?> device({String? screen}) async {
    lastScreen = screen;
    return FeedbackDevice(
      model: 'Samsung SM-S921B',
      os: 'Android 15',
      screen: screen,
    );
  }
}

Uint8List jpeg(int n) => Uint8List.fromList([0xff, 0xd8, 0xff, n, 1, 2, 3, 4]);

/// Phase 19 (§31 "feedback channel", ADR-026): Profile → Send feedback, and
/// the update gate (E1) — both through the whole app.
void main() {
  late FakeAuthRepository auth;
  late AppDatabase db;
  late FakeFeedbackApi feedback;
  late FakeMetaApi meta;
  late FakePictureSource pictures;
  late FakeDeviceSource devices;

  setUp(() {
    pictures = FakePictureSource();
    devices = FakeDeviceSource();
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
    db = AppDatabase.inMemory();
    feedback = FakeFeedbackApi();
    meta = FakeMetaApi();
  });
  tearDown(() async {
    auth.dispose();
    await db.close();
  });

  Widget app({int build = 4}) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider
              .overrideWithValue(FakeOnboardingRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          feedbackPictureSourceProvider.overrideWithValue(pictures),
          feedbackDeviceSourceProvider.overrideWithValue(devices),
          ...workoutOverrides(
            db,
            FakeWorkoutApi(),
            feedback: feedback,
            meta: meta,
            appBuild: build,
          ),
        ],
        child: const FitOSApp(),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  Future<void> openFeedback(WidgetTester tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.profile')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profile.feedback'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  FilledButton send(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('feedback.send')));

  testWidgets(
      'Send is off until a category and a message are given; sent with the app version, then cleared',
      (tester) async {
    await openFeedback(tester);
    expect(send(tester).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      '  The rest timer froze after set three.  ',
    );
    await tester.pump();
    expect(send(tester).onPressed, isNull, reason: 'no category yet');
    await tester.tap(find.byKey(const ValueKey('feedback.category.bug')));
    await tester.pump();
    expect(send(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();

    expect(feedback.sent.single.category, FeedbackCategory.bug);
    expect(
      feedback.sent.single.message,
      'The rest timer froze after set three.',
    );
    expect(feedback.sent.single.appVersion, '1.0.0-alpha.1+4');
    expect(find.textContaining('Sent. Thank you'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('feedback.message')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('a failure keeps what was typed and says why', (tester) async {
    await openFeedback(tester);
    feedback.nextFailure = const Offline();
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      'Paneer tikka is missing from the mess',
    );
    await tester.tap(find.byKey(const ValueKey('feedback.category.food')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    expect(feedback.sent, isEmpty);
    expect(find.textContaining('needs a connection'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('feedback.message')))
          .controller!
          .text,
      'Paneer tikka is missing from the mess',
    );
    // A second try goes through.
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    expect(feedback.sent.single.category, FeedbackCategory.food);
  });

  group('E1: the update gate', () {
    testWidgets('a build below the server minimum shows only "Update FITOS"',
        (tester) async {
      meta.minimumBuild = 9;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('at or above the minimum, or with no minimum, the app runs',
        (tester) async {
      meta.minimumBuild = 4;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('an unreachable server never blocks the app', (tester) async {
      meta
        ..minimumBuild = 99
        ..offline = true;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  /* ------------------------------------------------------------ beta 3.6 -- */

  Future<void> addPictures(WidgetTester tester, List<Uint8List> next) async {
    pictures.next = next;
    final add = find.byKey(const ValueKey('feedback.pictures.add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback.pictures.gallery')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'beta 3.6: up to three pictures (one removed before sending), sent with the phone and the screen came from',
      (tester) async {
    await openFeedback(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('feedback.device.label')))
          .data,
      startsWith('Samsung SM-S921B · Android 15 · FITOS'),
    );
    expect(
      devices.lastScreen,
      '/',
      reason: 'Home, the last screen outside Profile',
    );
    await addPictures(tester, [jpeg(1), jpeg(2)]);
    expect(find.byKey(const ValueKey('feedback.picture.1')), findsOneWidget);
    await addPictures(tester, [jpeg(3), jpeg(4)]);
    expect(pictures.lastMax, 1, reason: 'room for one more');
    expect(find.byKey(const ValueKey('feedback.picture.2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feedback.pictures.add')),
      findsNothing,
      reason: 'three is the most',
    );

    await tester
        .tap(find.byKey(const ValueKey('feedback.picture.remove')).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      'See the screenshots',
    );
    await tester.tap(find.byKey(const ValueKey('feedback.category.bug')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    final s = feedback.sent.single;
    expect(s.pictures.map((p) => p[3]), [2, 3]);
    expect(s.device?.model, 'Samsung SM-S921B');
    expect(
      find.byKey(const ValueKey('feedback.picture.0')),
      findsNothing,
      reason: 'cleared after sending',
    );
  });

  testWidgets(
      'beta 3.6: the phone details can be left out; a picture FITOS cannot send is refused, kindly',
      (tester) async {
    await openFeedback(tester);
    await addPictures(tester, [
      Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]),
    ]);
    expect(find.byKey(const ValueKey('feedback.picture.0')), findsNothing);
    expect(find.textContaining('could not be added'), findsOneWidget);
    final device = find.byKey(const ValueKey('feedback.device'));
    await tester.ensureVisible(device);
    await tester.tap(device);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      'No details please',
    );
    await tester.tap(find.byKey(const ValueKey('feedback.category.idea')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    expect(feedback.sent.single.device, isNull);
    expect(feedback.sent.single.pictures, isEmpty);
  });

  testWidgets(
      'beta 3.6: a reply from the FITOS team: Profile says so, the message shows it, and it is marked read once',
      (tester) async {
    feedback.mineList = MyFeedbackList(
      items: [
        MyFeedback(
          id: 'f1',
          category: FeedbackCategory.bug,
          message: 'The timer froze',
          status: 'read',
          createdAt: DateTime.utc(2026, 10, 20, 9),
          pictures: 1,
          replies: [
            FeedbackReply(
              id: 'r1',
              message: 'Fixed in 3.7, thank you!',
              createdAt: DateTime.utc(2026, 10, 21, 9),
              readAt: null,
            ),
          ],
        ),
      ],
      unread: 1,
    );
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.profile')));
    await tester.pumpAndSettle();
    expect(find.text('1 new reply'), findsOneWidget);
    final button = find.byKey(const ValueKey('profile.feedback'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final reply = find.byKey(const ValueKey('feedback.reply.r1'));
    await tester.ensureVisible(reply);
    expect(find.text('Fixed in 3.7, thank you!'), findsOneWidget);
    expect(find.textContaining('Seen · 1 picture'), findsOneWidget);
    expect(feedback.markReadCalls, 1);
    await tester.pumpAndSettle();
    expect(feedback.markReadCalls, 1, reason: 'once per visit');
  });
}
