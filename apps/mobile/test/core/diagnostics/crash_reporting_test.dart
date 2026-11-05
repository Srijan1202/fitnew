import 'package:fitos/core/diagnostics/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta 5.6.3: on a slow phone Crashlytics threw while starting (its plugin
/// constants missing) and main() never reached runApp — FITOS stayed on the
/// splash. A reporter that fails to start must not stop the app.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a reporter that throws on start: start-up carries on', () async {
    final onError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = platformOnError;
    });
    final reporter = _Failing();
    await installCrashReporting(reporter);
    expect(reporter.asked, isTrue);
    expect(FlutterError.onError, isNot(same(onError)));
  });
}

class _Failing implements CrashReporter {
  bool asked = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    asked = true;
    throw TypeError();
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {}

  @override
  void recordError(Object error, StackTrace stack) {}
}
