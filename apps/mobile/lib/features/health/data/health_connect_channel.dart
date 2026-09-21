import 'package:flutter/services.dart';

/// The platform boundary: exactly what `HealthConnectChannel.kt` answers,
/// as plain values. Nothing above this layer sees Health Connect types.
/// Tests hand in a fake; the app uses [MethodChannelHealthConnect].
abstract class HealthConnectChannel {
  /// "available" | "updateRequired" | "unavailable".
  Future<String> sdkStatus();

  /// Metric keys (see `HealthMetricKind.wire`) whose READ permission is
  /// granted right now. Re-read on every refresh: permissions are revocable.
  Future<List<String>> grantedPermissions();

  /// Opens Health Connect's permission sheet for the given metric keys and
  /// answers with what is granted afterwards.
  Future<List<String>> requestPermissions(List<String> metrics);

  /// Totals over [start, end) for the given metric keys. Absent keys mean
  /// no data in the range. Throws [HealthChannelException].
  Future<Map<String, Object?>> aggregate({
    required DateTime start,
    required DateTime end,
    required List<String> metrics,
  });

  /// The latest point record of `type` in the range, or null.
  Future<Map<String, Object?>?> latest({
    required String type,
    required DateTime start,
    required DateTime end,
  });

  Future<List<Map<String, Object?>>> exerciseSessions({
    required DateTime start,
    required DateTime end,
  });

  /// Opens Health Connect's settings (manage permissions). False when the
  /// device has no such screen.
  Future<bool> openSettings();
}

/// The channel's error codes, as the Kotlin side raises them.
class HealthChannelException implements Exception {
  const HealthChannelException(this.code, [this.message]);

  /// "permissionDenied" | "unavailable" | "temporarilyUnavailable" | "busy".
  final String code;
  final String? message;

  @override
  String toString() => 'HealthChannelException($code)';
}

class MethodChannelHealthConnect implements HealthConnectChannel {
  const MethodChannelHealthConnect([this._channel = const MethodChannel(name)]);

  static const name = 'fitos/health_connect';
  final MethodChannel _channel;

  Future<T> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      final r = await _channel.invokeMethod<T>(method, args);
      if (r == null) {
        throw const HealthChannelException('temporarilyUnavailable');
      }
      return r;
    } on PlatformException catch (e) {
      throw HealthChannelException(e.code, e.message);
    } on MissingPluginException {
      // Not Android, or an engine without the channel: unsupported here.
      throw const HealthChannelException('unavailable');
    }
  }

  static Map<String, Object?> _range(DateTime start, DateTime end) => {
        'startMillis': start.toUtc().millisecondsSinceEpoch,
        'endMillis': end.toUtc().millisecondsSinceEpoch,
      };

  @override
  Future<String> sdkStatus() async {
    try {
      return await _call<String>('sdkStatus');
    } on HealthChannelException {
      return 'unavailable';
    }
  }

  @override
  Future<List<String>> grantedPermissions() async =>
      (await _call<List<Object?>>('grantedPermissions')).cast<String>();

  @override
  Future<List<String>> requestPermissions(List<String> metrics) async =>
      (await _call<List<Object?>>('requestPermissions', {'metrics': metrics}))
          .cast<String>();

  @override
  Future<Map<String, Object?>> aggregate({
    required DateTime start,
    required DateTime end,
    required List<String> metrics,
  }) async =>
      (await _call<Map<Object?, Object?>>('aggregate', {
        ..._range(start, end),
        'metrics': metrics,
      }))
          .cast<String, Object?>();

  @override
  Future<Map<String, Object?>?> latest({
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await _channel.invokeMethod<Map<Object?, Object?>>(
      'latest',
      {'type': type, ..._range(start, end)},
    ).catchError((Object e) {
      if (e is PlatformException) {
        throw HealthChannelException(e.code, e.message);
      }
      if (e is MissingPluginException) {
        throw const HealthChannelException('unavailable');
      }
      throw e;
    });
    return r?.cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> exerciseSessions({
    required DateTime start,
    required DateTime end,
  }) async =>
      (await _call<List<Object?>>('exerciseSessions', _range(start, end)))
          .map((e) => (e! as Map<Object?, Object?>).cast<String, Object?>())
          .toList();

  @override
  Future<bool> openSettings() async {
    try {
      return await _call<bool>('openSettings');
    } on HealthChannelException {
      return false;
    }
  }
}
