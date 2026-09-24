import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/mess.dart';
import 'mess_api.dart';

/// What the app has for a mess menu.
sealed class MenuState {
  const MenuState();
}

/// A menu — fresh from the server, or the copy last cached on this phone
/// when the server could not be reached ([failure] says why; [storedAt]
/// when it was cached).
class MenuLoaded extends MenuState {
  const MenuLoaded(this.menu, {this.storedAt, this.failure});

  final MessMenu menu;
  final String? storedAt;
  final Failure? failure;

  bool get fromCache => failure != null;
}

/// The user has no mess configured (and asked for "my mess").
class MenuNotConfigured extends MenuState {
  const MenuNotConfigured();
}

/// Nothing to show: no connection and nothing cached.
class MenuFailed extends MenuState {
  const MenuFailed(this.failure);
  final Failure failure;
}

/// Phase 9 — mess menus, with an offline copy (§33, owner D18).
///
/// Every menu fetched is cached on the phone (`cached_json`, the Phase 8
/// table), keyed by mess and date; "my mess" is remembered too, so today's
/// and tomorrow's menu of the configured mess can be shown offline. A cached
/// menu is always shown as such, with when it was fetched.
class MessRepository {
  MessRepository(this._db, this._api, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final MessApi _api;
  final DateTime Function() _now;

  static const myMessKey = 'mess.mine';
  static const messesKey = 'mess.list';
  static String menuKey(String code, String date) => 'mess.menu.$code.$date';

  Future<void> _put(String key, Object json) =>
      _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: key,
              json: jsonEncode(json),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );

  Future<CachedJsonData?> _get(String key) =>
      (_db.select(_db.cachedJson)..where((t) => t.key.equals(key)))
          .getSingleOrNull();

  /// The configured mess's code as last seen, or null.
  Future<String?> myMessCode() async {
    final row = await _get(myMessKey);
    if (row == null) return null;
    return (jsonDecode(row.json) as Map<String, dynamic>)['code'] as String?;
  }

  /// The menu of [date] — of [code], or of the user's own mess when null.
  Future<MenuState> menu(String date, {String? code}) async {
    final result = await _api.menu(date: date, mess: code);
    switch (result) {
      case Ok(:final value):
        await _put(menuKey(value.mess.code, date), value.toJson());
        if (code == null) await _put(myMessKey, value.mess.toJson());
        return MenuLoaded(value);
      case Err(:final failure):
        if (code == null && failure is NotFound) {
          await forgetMine();
          return const MenuNotConfigured();
        }
        final c = code ?? await myMessCode();
        final cached = c == null ? null : await _get(menuKey(c, date));
        if (cached == null) return MenuFailed(failure);
        return MenuLoaded(
          MessMenu.fromJson(jsonDecode(cached.json) as Map<String, dynamic>),
          storedAt: cached.storedAt,
          failure: failure,
        );
    }
  }

  /// The six messes (cached for the picker when offline).
  Future<Result<List<Mess>>> messes() async {
    final result = await _api.messes();
    switch (result) {
      case Ok(:final value):
        await _put(messesKey, value.toJson());
        return Ok(value.items);
      case Err(:final failure):
        final cached = await _get(messesKey);
        if (cached == null) return Err(failure);
        return Ok(
          MessesResponse.fromJson(
            jsonDecode(cached.json) as Map<String, dynamic>,
          ).items,
        );
    }
  }

  /// Online only; stored as pending on the server.
  Future<Result<MessCorrection>> correct(
    String dishSlug,
    MessCorrectionRequest request,
  ) =>
      _api.correct(dishSlug, request);

  /// After the user changes (or clears) their mess: "my mess" is re-learnt.
  Future<void> forgetMine() =>
      (_db.delete(_db.cachedJson)..where((t) => t.key.equals(myMessKey))).go();
}
