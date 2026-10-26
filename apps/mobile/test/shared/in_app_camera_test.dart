import 'package:camera/camera.dart';
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
}
