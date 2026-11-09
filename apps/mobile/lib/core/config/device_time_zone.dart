import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's IANA time zone ("Asia/Kolkata"), read once at start from
/// Android (`fitos/device`, `TimeZone.getDefault().id`). Dart alone only
/// knows an abbreviation ("IST"), which the server rejects (§9.1).
///
/// Null when it cannot be read or does not have the shape the server
/// accepts — then the server keeps its default and sign-in never fails on it
/// (audit 2026-10-20; closes the item left open since Phase 2).
abstract final class DeviceTimeZone {
  static const _channel = MethodChannel('fitos/device');

  /// The server's `timeZoneSchema` shape (`@fitos/contracts` auth.ts).
  static final _shape = RegExp(r'^(UTC|[A-Z][A-Za-z_]*(/[A-Za-z0-9_+-]+)+)$');

  static String? _value;
  static String? get value => _value;

  /// Old IANA names Android still reports for some zones (Java keeps
  /// `Asia/Calcutta`), as the current name. The beta 6.0 emulator check found
  /// Profile saying "This phone is set to Asia/Calcutta. Your days run on
  /// Asia/Kolkata." for one and the same zone.
  static const _renamed = <String, String>{
    'Asia/Calcutta': 'Asia/Kolkata',
    'Asia/Katmandu': 'Asia/Kathmandu',
    'Asia/Rangoon': 'Asia/Yangon',
    'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    'Asia/Dacca': 'Asia/Dhaka',
    'Asia/Thimbu': 'Asia/Thimphu',
    'Europe/Kiev': 'Europe/Kyiv',
    'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
    'Atlantic/Faeroe': 'Atlantic/Faroe',
    'Pacific/Truk': 'Pacific/Chuuk',
  };

  /// [zone] under its current IANA name.
  static String? current(String? zone) => _renamed[zone] ?? zone;

  static bool accepted(String? zone) =>
      zone != null && zone.length <= 64 && _shape.hasMatch(zone);

  /// Reads the zone; any failure (no channel off Android, tests) leaves null.
  static Future<void> load() async {
    try {
      final zone = current(await _channel.invokeMethod<String>('timeZone'));
      _value = accepted(zone) ? zone : null;
    } on Object {
      _value = null;
    }
  }
}

/// The phone's zone for the rest of the app (overridable in tests).
final deviceTimeZoneProvider = Provider<String?>((_) => DeviceTimeZone.value);
