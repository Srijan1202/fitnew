import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/notifications/local_notifications.dart';
import '../domain/gps_filter.dart';

/// Beta 4.0 (ADR-038): where a run's GPS comes from, behind an interface so
/// tests can drive a run with recorded fixes.

enum LocationAccess { granted, serviceOff, denied, deniedForever }

abstract class LocationSource {
  /// Asks for "while using the app" location if needed. Never "all the
  /// time": the run's foreground service keeps it working with the screen off.
  Future<LocationAccess> ensureAccess();

  /// Fixes about once a second. On Android this runs a foreground service
  /// (type location) with the run's notification, so the run keeps recording
  /// with the screen off or another app open.
  Stream<GpsFix> fixes();

  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

class GeolocatorSource implements LocationSource {
  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.whileInUse ||
      LocationPermission.always =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<GpsFix> fixes() => Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'FITOS is recording your run',
            notificationText: 'Tap to go back to it.',
            notificationChannelName: 'Run in progress',
            notificationIcon:
                AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).map(
        (p) => GpsFix(
          at: p.timestamp,
          lat: p.latitude,
          lon: p.longitude,
          accuracyM: p.hasAccuracy ? p.accuracy : 50,
          altitudeM: p.hasAltitude ? p.altitude : null,
          speedMs: p.hasSpeed && p.speed >= 0 ? p.speed : null,
        ),
      );

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}

/// The run's notification while it records. Android shows it for the
/// foreground service that keeps GPS on; FITOS writes its own words into
/// the same notification (same id and channel), so it reads the live time
/// and distance instead of a fixed line.
abstract class RunNotification {
  Future<void> show({
    required String title,
    required String body,
    DateTime? runningSince,
  });
}

class AndroidRunNotification implements RunNotification {
  /// The id and channel of geolocator's foreground-service notification.
  static const int id = 75415;
  static const String channelId = 'geolocator_channel_01';

  @override
  Future<void> show({
    required String title,
    required String body,
    DateTime? runningSince,
  }) async {
    try {
      await FitNotifications.ensureInitialized();
      await FitNotifications.plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Run in progress',
            channelDescription: 'The run FITOS is recording.',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showWhen: runningSince != null,
            usesChronometer: runningSince != null,
            when: runningSince?.millisecondsSinceEpoch,
          ),
        ),
        payload: '{"screen":"run"}',
      );
    } on Object {
      // The notification is a convenience; the run records without it.
    }
  }
}

/// Samsung and other phones may stop apps in the background to save battery,
/// which would stop a run. FITOS asks once to be left alone (Unrestricted).
abstract class BatteryAccess {
  Future<bool> isUnrestricted();
  Future<void> openSettings();
}

class AndroidBatteryAccess implements BatteryAccess {
  static const _channel = MethodChannel('fitos/device');

  @override
  Future<bool> isUnrestricted() async {
    try {
      return await _channel.invokeMethod<bool>('batteryUnrestricted') ?? true;
    } on Object {
      return true;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } on Object {
      // Nothing to open on this phone.
    }
  }
}
