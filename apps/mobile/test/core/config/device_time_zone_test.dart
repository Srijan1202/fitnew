import 'package:fitos/core/config/device_time_zone.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-10-20 (the item open since Phase 2): the phone's IANA zone is
/// read from Android and sent only when it has the shape the server accepts,
/// so a bad value can never fail a sign-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fitos/device');

  void answer(Object? value) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'timeZone');
        if (value is Exception) throw value;
        return value;
      });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('the server\'s shape: Area/Location or UTC; never an abbreviation', () {
    for (final ok in [
      'Asia/Kolkata',
      'America/Argentina/Buenos_Aires',
      'Etc/GMT+5',
      'UTC',
    ]) {
      expect(DeviceTimeZone.accepted(ok), isTrue, reason: ok);
    }
    for (final bad in [null, '', 'IST', 'GMT+05:30', 'asia/kolkata', 'Asia']) {
      expect(DeviceTimeZone.accepted(bad), isFalse, reason: '$bad');
    }
  });

  test('load: the Android zone when it is valid', () async {
    answer('Europe/London');
    await DeviceTimeZone.load();
    expect(DeviceTimeZone.value, 'Europe/London');
  });

  test('load: a value of the wrong shape is dropped (the server default stays)',
      () async {
    answer('IST');
    await DeviceTimeZone.load();
    expect(DeviceTimeZone.value, isNull);
  });

  test('load: a channel failure (or no Android) leaves null, never throws',
      () async {
    answer(PlatformException(code: 'x'));
    await DeviceTimeZone.load();
    expect(DeviceTimeZone.value, isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await DeviceTimeZone.load(); // MissingPluginException
    expect(DeviceTimeZone.value, isNull);
  });
}
