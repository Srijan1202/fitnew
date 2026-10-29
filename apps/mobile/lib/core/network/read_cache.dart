import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Beta 4.1.1 (owner: "unable to open even profile" where the internet is
/// slow). A screen's read used to wait for the server however long it took:
/// 10 s to connect, 20 s to answer, three tries — over a minute and a half
/// before a slow network gave up. Wrapped around the HTTP adapter, this
/// keeps the last good answer to each screen's read on the phone and, when
/// the network is slow or gone, does not keep the screen waiting:
///
/// * [ReadKind.serve] — screens with no copy of their own (Profile, the
///   programme, targets, …): after [softDeadline], or at once when there is
///   no connection, the last good answer is served. The request carries on,
///   and its answer, when it comes, is kept for next time.
/// * [ReadKind.own] — screens that keep their own copy and say how old it is
///   (Today, Recovery, Progress, Eat, Mess, Running; owner D9): after
///   [softDeadline] a kept answer under [ownFreshFor] old is served (on a
///   network that is always slow, the late answer to the last read, so the
///   screen still moves on); an older one is not, and the read fails as a
///   timeout, not retried, so the screen shows its labelled copy.
///
/// Either way, only once this phone has had a good answer to the same read
/// (else nothing is different: a first load still waits for the network).
/// A write to a resource forgets the kept answers under it, so a stale copy
/// never hides a change the user just made. Kept per user, in `cached_json`,
/// which sign-out and account deletion wipe.
enum ReadKind { serve, own }

/// Which reads this applies to, by path; null: none (sign-in, onboarding,
/// the food search, the AI, shared links, config).
ReadKind? readKindOf(String path) {
  const own = [
    '/v1/today',
    '/v1/recovery/today',
    '/v1/progress/summary',
    '/v1/nutrition/today',
    '/v1/nutrition/day/',
    '/v1/nutrition/foods/recent',
    '/v1/nutrition/saved-meals',
    '/v1/mess/',
    '/v1/running/',
  ];
  const serve = [
    '/v1/user/profile',
    '/v1/user/goal',
    '/v1/user/targets',
    '/v1/user/diet-preferences',
    '/v1/user/rewards',
    '/v1/user/consents',
    '/v1/premium',
    '/v1/training/program',
    '/v1/training/templates',
    '/v1/training/volume',
    '/v1/training/sessions/',
    '/v1/exercises',
    '/v1/notifications/settings',
    '/v1/progress/streak',
    '/v1/progress/weekly',
    '/v1/feedback/mine',
  ];
  bool under(String p) => p.endsWith('/')
      ? path.startsWith(p)
      : path == p || path.startsWith('$p/');
  if (own.any(under)) return ReadKind.own;
  if (serve.any(under)) return ReadKind.serve;
  return null;
}

/// What a write to [path] makes stale: the reads under its first three
/// segments ("/v1/training/program"), or under "/v1/user" for any user
/// write, since a new weight or goal changes the targets too.
String staleUnder(String path) {
  final parts = path.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.length >= 2 && parts[1] == 'user') return '/v1/user';
  return '/${parts.take(3).join('/')}';
}

/// One kept answer.
class KeptRead {
  const KeptRead(this.body, this.storedAt);
  final Uint8List body;
  final DateTime storedAt;
}

/// Where the answers are kept; [DriftReadStore] on the phone.
abstract interface class ReadStore {
  Future<KeptRead?> read(String key);
  Future<void> write(String key, Uint8List body);

  /// Every kept answer whose key starts with [prefix].
  Future<void> forget(String prefix);
}

class DriftReadStore implements ReadStore {
  DriftReadStore(this._db);

  final AppDatabase Function() _db;

  @override
  Future<KeptRead?> read(String key) async {
    final db = _db();
    final row = await (db.select(db.cachedJson)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return KeptRead(
      Uint8List.fromList(utf8.encode(row.json)),
      DateTime.tryParse(row.storedAt) ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> write(String key, Uint8List body) async {
    final db = _db();
    await db.into(db.cachedJson).insertOnConflictUpdate(
          CachedJsonCompanion.insert(
            key: key,
            json: utf8.decode(body),
            storedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  }

  @override
  Future<void> forget(String prefix) async {
    final db = _db();
    await (db.delete(db.cachedJson)..where((t) => t.key.like('$prefix%'))).go();
  }
}

class ReadCacheAdapter implements HttpClientAdapter {
  ReadCacheAdapter(
    this._inner, {
    required ReadStore store,
    required String? Function() userId,
    this.softDeadline = const Duration(seconds: 4),
    this.ownFreshFor = const Duration(minutes: 15),
    DateTime Function()? now,
  })  : _store = store,
        _userId = userId,
        _now = now ?? DateTime.now;

  final HttpClientAdapter _inner;
  final ReadStore _store;
  final String? Function() _userId;
  final Duration softDeadline;

  /// How old a kept answer to a [ReadKind.own] read may be and still be
  /// served as if live.
  final Duration ownFreshFor;
  final DateTime Function() _now;

  /// Set on an answer served from the phone: when it was kept.
  static const keptHeader = 'x-fitos-kept-at';

  String _key(String user, RequestOptions o) =>
      'http.$user.${o.uri.path}${o.uri.hasQuery ? '?${o.uri.query}' : ''}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final user = _userId();
    final path = options.uri.path;
    if (user == null) return _inner.fetch(options, requestStream, cancelFuture);
    if (options.method.toUpperCase() != 'GET') {
      final response = await _inner.fetch(options, requestStream, cancelFuture);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _quietly(() => _store.forget('http.$user.${staleUnder(path)}'));
      }
      return response;
    }
    final kind = readKindOf(path);
    if (kind == null) return _inner.fetch(options, requestStream, cancelFuture);

    final key = _key(user, options);
    final kept = await _quietly(() => _store.read(key));
    final live = _inner
        .fetch(options, requestStream, cancelFuture)
        .then((r) => _keep(key, r));
    if (kept == null) return live;

    // A screen with its own labelled copy is served the kept answer only
    // while it is as good as live (the late answer to a recent slow read);
    // an older one would show without its age, so the screen's copy, which
    // says how old it is, is shown instead.
    final serve = kind == ReadKind.serve ||
        _now().toUtc().difference(kept.storedAt) <= ownFreshFor;
    final outcome = Completer<ResponseBody>();
    void fallBack() {
      if (outcome.isCompleted) return;
      if (serve) {
        outcome.complete(
          ResponseBody.fromBytes(
            kept.body,
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              keptHeader: [kept.storedAt.toIso8601String()],
            },
          ),
        );
      } else {
        // Not retried: the screen's own copy is the answer now.
        options.extra['fitos.attempt'] = 1 << 20;
        outcome.completeError(
          DioException.connectionTimeout(
            timeout: softDeadline,
            requestOptions: options,
          ),
        );
      }
    }

    final timer = Timer(softDeadline, fallBack);
    unawaited(
      live.then(
        (r) {
          timer.cancel();
          if (!outcome.isCompleted) outcome.complete(r);
        },
        onError: (Object e, StackTrace s) {
          timer.cancel();
          // A cancelled request stays cancelled; any other failure (no
          // connection, a timeout) falls back at once.
          if (e is DioException && e.type == DioExceptionType.cancel) {
            if (!outcome.isCompleted) outcome.completeError(e, s);
          } else if (serve) {
            fallBack();
          } else if (!outcome.isCompleted) {
            outcome.completeError(e, s);
          }
        },
      ),
    );
    return outcome.future;
  }

  /// Keeps a good answer (read whole, then handed on as it came).
  Future<ResponseBody> _keep(String key, ResponseBody r) async {
    if (r.statusCode < 200 || r.statusCode >= 300) return r;
    final bytes = await _collect(r.stream);
    await _quietly(() => _store.write(key, bytes));
    return ResponseBody.fromBytes(
      bytes,
      r.statusCode,
      statusMessage: r.statusMessage,
      headers: r.headers,
      isRedirect: r.isRedirect,
    );
  }

  static Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      b.add(chunk);
    }
    return b.takeBytes();
  }

  /// The phone's store failing never fails a request.
  static Future<T?> _quietly<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on Object {
      return null;
    }
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
