import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fitos/shared/widgets/in_app_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 3.8: the in-app camera says plainly when it cannot work — no camera,
/// or the camera permission refused — and Close always leaves with nothing.
/// The live preview and the shutter need a phone (checked on the S24).
void main() {
  Future<String?> open(WidgetTester tester, CameraList cameras) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => InAppCameraScreen(cameras: cameras),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera.screen')), findsOneWidget);
    final problem =
        tester.widget<Text>(find.byKey(const ValueKey('camera.problem'))).data;
    await tester.tap(find.byKey(const ValueKey('camera.close')));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'Close returns no photo');
    return problem;
  }

  testWidgets('no camera on the phone: said so', (tester) async {
    expect(
      await open(tester, () async => const <CameraDescription>[]),
      'This phone has no camera FITOS can use.',
    );
  });

  testWidgets(
      'the camera permission refused: where to allow it, and the gallery',
      (tester) async {
    final problem = await open(
      tester,
      () async => throw CameraException('CameraAccessDenied', 'denied'),
    );
    expect(problem, contains("Allow it in your phone's settings"));
    expect(problem, contains('gallery'));
  });

  testWidgets('any other camera failure: try again', (tester) async {
    expect(
      await open(
        tester,
        () async => throw CameraException('cameraNotReadable', 'busy'),
      ),
      'The camera could not start. Close this and try again.',
    );
  });

  testWidgets(
      'beta 5.6: with a gallery, a Gallery button returns its photo; '
      'none chosen keeps the camera open', (tester) async {
    String? result = 'unset';
    final answers = <String?>[null, '/cache/plate.jpg'];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => InAppCameraScreen(
                    cameras: () async => const <CameraDescription>[],
                    gallery: () async => answers.removeAt(0),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('camera.gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera.screen')), findsOneWidget);
    expect(result, 'unset');
    await tester.tap(find.byKey(const ValueKey('camera.gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera.screen')), findsNothing);
    expect(result, '/cache/plate.jpg');
  });

  group('beta 5.6.3: with a camera', () {
    late _FakeCamera camera;
    setUp(() => CameraPlatform.instance = camera = _FakeCamera());

    Future<Future<String?> Function()> openWith(
      WidgetTester tester, {
      Future<String?> Function()? gallery,
    }) async {
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => InAppCameraScreen(
                      cameras: () async => const [_back],
                      gallery: gallery,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      return () async => result;
    }

    testWidgets(
        'the camera is let go before the gallery opens and not started '
        'again while it is up (the S24 brought it back over the gallery)',
        (tester) async {
      var answer = Completer<String?>();
      int? releasedAtOpen;
      final result = await openWith(
        tester,
        gallery: () {
          releasedAtOpen = camera.disposed;
          return answer.future;
        },
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview')), findsOneWidget);
      expect(camera.created, 1);

      await tester.tap(find.byKey(const ValueKey('camera.gallery')));
      await tester.pump();
      expect(releasedAtOpen, 1, reason: 'released before the gallery');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(camera.created, 1, reason: 'not started over the gallery');

      answer.complete(null);
      await tester.pumpAndSettle();
      expect(camera.created, 2, reason: 'none chosen: the camera is back');
      expect(find.byKey(const ValueKey('preview')), findsOneWidget);

      answer = Completer<String?>()..complete('/cache/plate.jpg');
      await tester.tap(find.byKey(const ValueKey('camera.gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('camera.screen')), findsNothing);
      expect(await result(), '/cache/plate.jpg');
      expect(camera.disposed, 2);
    });

    testWidgets(
        'leaving while the camera starts (its permission dialog) does not '
        'start it a second time', (tester) async {
      final allowed = Completer<void>();
      camera.hold = allowed.future;
      await openWith(tester);
      await tester.tap(find.text('open'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      allowed.complete();
      await tester.pumpAndSettle();
      expect(camera.created, 1);
      expect(camera.disposed, 0);
      expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    });
  });

  testWidgets('without a gallery there is no Gallery button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InAppCameraScreen(
          cameras: () async => const <CameraDescription>[],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera.gallery')), findsNothing);
  });
}

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

/// The phone's camera: counts what was opened and let go; [hold] keeps a
/// start waiting, as the permission dialog does.
class _FakeCamera extends CameraPlatform {
  int created = 0;
  int disposed = 0;
  Future<void>? hold;
  final _started = StreamController<CameraInitializedEvent>.broadcast();
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async =>
      ++created;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    await hold;
    _started.add(
      CameraInitializedEvent(
        cameraId,
        1280,
        720,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _started.stream.where((CameraInitializedEvent e) => e.cameraId == cameraId);

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox(key: ValueKey('preview'));

  @override
  Future<void> dispose(int cameraId) async => disposed++;
}
