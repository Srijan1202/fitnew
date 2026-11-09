import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_providers.dart';
import 'theme_controller.dart';
import 'tokens.dart';

/// Beta 6.1 (E23): the theme follows the account, not only the phone.
///
/// The phone still applies a choice at once and keeps it (`theme.v3`), so
/// the app opens in its theme before anything loads. Then:
///
/// * a choice made here is sent to the account (`PATCH /user/preferences`);
///   one that could not be sent is marked [kThemeUnsent] (with the user it
///   belongs to) and sent at the next sign-in or start;
/// * at sign-in and each start, the account's choice is read and applied
///   when it differs — unless this phone has a choice still unsent, which
///   is newer and goes up instead;
/// * an account that never sent one (everyone before 6.1) takes this
///   phone's choice.
///
/// `auto` is Automatic. A premium or reward theme the account cannot use
/// is put back by the app's own checks (app.dart), as before, and that
/// correction stays on the phone: it never overwrites the account's choice.
const kThemeUnsent = 'theme.v3.unsent';

/// The wire value for this phone's choice now.
String localThemeId() =>
    FitPalette.followsDevice ? 'auto' : FitPalette.current.id;

class ThemeSync {
  ThemeSync(this._dio, this._uid, this._apply);

  final Dio _dio;
  final String _uid;
  final void Function(String themeId) _apply;

  /// Signed in, or the app started signed in.
  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(kThemeUnsent) == _uid) return await send();
      final r = await _dio.get<Map<String, dynamic>>('/v1/user/preferences');
      final account = r.data?['themeId'] as String?;
      if (account == null) return await send();
      if (account != localThemeId()) _apply(account);
    } on Object catch (e) {
      debugPrint('theme sync: $e');
    }
  }

  /// This phone's choice, to the account.
  Future<void> send() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemeUnsent, _uid);
      await _dio.patch<Map<String, dynamic>>(
        '/v1/user/preferences',
        data: {'themeId': localThemeId()},
      );
      if (prefs.getString(kThemeUnsent) == _uid) {
        await prefs.remove(kThemeUnsent);
      }
    } on Object catch (e) {
      debugPrint('theme sync: not sent yet ($e)');
    }
  }
}

/// Null while signed out. Built anew for each account, which reads that
/// account's choice.
final themeSyncProvider = Provider<ThemeSync?>((ref) {
  final uid = ref.watch(sessionUserIdProvider);
  if (uid == null) return null;
  final sync = ThemeSync(ref.watch(dioProvider), uid, (id) {
    final theme = ref.read(themeControllerProvider.notifier);
    if (id == 'auto') {
      unawaited(theme.followDevice(share: false));
      return;
    }
    final palette = FitPalette.byId(id);
    // A theme this build does not know (a newer app chose it) is left alone.
    if (palette != null) unawaited(theme.choose(palette, share: false));
  });
  unawaited(sync.start());
  return sync;
});
