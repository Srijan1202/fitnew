import 'dart:io';

import 'package:fitos/features/health/data/health_connect_provider.dart';
import 'package:fitos/features/health/domain/entities/health.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_health_channel.dart';

/// Phase 6.6 Gate 6 — the in-app "Connect" path, which crashed a Samsung S24
/// on Android 14+: the native side built the permission contract's intent by
/// hand and called `startActivityForResult`, but on API 34+ that contract
/// delegates to `RequestMultiplePermissions`, whose intent carries a sentinel
/// action only `ActivityResultRegistry` resolves — so Android threw
/// `ActivityNotFoundException` and the process died.
///
/// Every outcome of that flow is asserted here (granted, partial, denied,
/// already granted, unavailable, native error), and a source guard keeps the
/// native request on a registered launcher, which no widget test can reach.
void main() {
  late FakeHealthChannel channel;
  late HealthConnectProvider provider;

  setUp(() {
    channel = FakeHealthChannel();
    provider = HealthConnectProvider(
      channel,
      now: () => DateTime.utc(2026, 9, 22, 6, 30),
    );
  });

  final all = HealthMetricKind.values.toSet();

  group('requestPermissions (the Connect button)', () {
    test('everything granted: every category reads as full', () async {
      channel.sdk = 'available';
      channel.grantOnRequest = all.map((k) => k.wire).toList();

      final state = await provider.requestPermissions(all);

      expect(state.granted, all);
      expect(state.isConnected, isTrue);
      for (final c in HealthCategory.values) {
        expect(state.categoryGrant(c), CategoryGrant.all, reason: c.name);
      }
    });

    test('partly granted: the granted ones only, and it is still connected',
        () async {
      channel.sdk = 'available';
      channel.grantOnRequest = ['steps', 'distance'];

      final state = await provider.requestPermissions(all);

      expect(
        state.granted,
        {HealthMetricKind.steps, HealthMetricKind.distance},
      );
      expect(state.isConnected, isTrue);
      expect(
        state.categoryGrant(HealthCategory.activity),
        CategoryGrant.partial,
      );
      expect(state.categoryGrant(HealthCategory.body), CategoryGrant.none);
    });

    test('denied, or the user backs out: no grants, no throw, not connected',
        () async {
      channel.sdk = 'available';
      channel.grantOnRequest = const [];

      final state = await provider.requestPermissions(all);

      expect(state.granted, isEmpty);
      expect(state.isConnected, isFalse);
      expect(state.sdk, HealthSdkStatus.available);
    });

    test('already granted: asking again keeps them and changes nothing',
        () async {
      channel.sdk = 'available';
      channel.granted = ['steps', 'sleep'];
      channel.grantOnRequest = ['steps', 'sleep'];

      final state = await provider.requestPermissions(all);

      expect(state.granted, {HealthMetricKind.steps, HealthMetricKind.sleep});
      expect(state.isConnected, isTrue);
    });

    test('Health Connect unavailable: no request is made at all', () async {
      channel.sdk = 'unavailable';

      final state = await provider.requestPermissions(all);

      expect(state.sdk, HealthSdkStatus.unavailable);
      expect(state.granted, isEmpty);
      expect(
        channel.calls.where((c) => c.startsWith('requestPermissions')),
        isEmpty,
      );
    });

    test('an update-required provider says so instead of requesting', () async {
      channel.sdk = 'updateRequired';

      final state = await provider.requestPermissions(all);

      expect(state.sdk, HealthSdkStatus.updateRequired);
      expect(
        channel.calls.where((c) => c.startsWith('requestPermissions')),
        isEmpty,
      );
    });

    for (final code in const [
      'permissions',
      'unavailable',
      'busy',
      'permissionDenied',
      'temporarilyUnavailable',
    ]) {
      test('a native "$code" error surfaces as state, never as a crash',
          () async {
        channel.sdk = 'available';
        channel.granted = ['steps'];
        channel.failRequestWith = code;

        final state = await provider.requestPermissions(all);

        // Falls back to re-reading the connection: what is actually granted.
        expect(state.sdk, HealthSdkStatus.available);
        expect(state.granted, {HealthMetricKind.steps});
      });
    }

    test('a grant that arrives for a metric FITOS does not know is ignored',
        () async {
      channel.sdk = 'available';
      channel.granted = ['steps', 'android.permission.health.READ_HEART_RATE'];

      final state = await provider.connection();

      expect(state.granted, {HealthMetricKind.steps});
    });
  });

  group('native permission request path (source guard)', () {
    // The crash was in Kotlin, where no Dart test can reach. These assertions
    // keep the fixed shape: a launcher registered by a ComponentActivity, and
    // no hand-built permission intent.
    final channelSource = File(
      'android/app/src/main/kotlin/com/example/fitos/HealthConnectChannel.kt',
    ).readAsStringSync();
    final activitySource = File(
      'android/app/src/main/kotlin/com/example/fitos/MainActivity.kt',
    ).readAsStringSync();

    test('the permission request is launched, not started as an intent', () {
      expect(channelSource, contains('permissionLauncher'));
      expect(channelSource, contains('launcher.launch(permissions)'));
      expect(
        channelSource,
        isNot(contains('startActivityForResult')),
        reason: 'the Android 14+ contract intent is a sentinel, not an intent '
            'any activity resolves',
      );
      expect(channelSource, isNot(contains('createIntent')));
    });

    test('the launcher is registered by a ComponentActivity before CREATED',
        () {
      expect(activitySource, contains('FlutterFragmentActivity'));
      expect(activitySource, contains('registerForActivityResult'));
      expect(
        activitySource,
        contains('createRequestPermissionResultContract'),
        reason: 'the current Health Connect contract, not a legacy API',
      );
      // A field initializer: registration happens before onStart, which
      // registerForActivityResult requires.
      expect(
        activitySource,
        contains('private val healthPermissionLauncher'),
      );
    });

    test('a launch failure answers Flutter instead of propagating', () {
      expect(channelSource, contains('catch (e: Throwable)'));
      expect(channelSource, contains('pendingPermissionResult = null'));
      // And the reply survives an activity that went away meanwhile.
      expect(channelSource, contains('catch (e: IllegalStateException)'));
    });

    test('only manifest-declared read permissions can be requested', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final requested = RegExp(r'"(android\.permission\.health\.READ_[A-Z_]+)"')
          .allMatches(channelSource)
          .map((m) => m.group(1)!)
          .toSet();
      expect(requested, isNotEmpty);
      for (final p in requested) {
        expect(
          manifest,
          contains('android:name="$p"'),
          reason: '$p must be declared in the manifest',
        );
      }
    });
  });
}
