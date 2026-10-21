import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/notifications.dart';

/// `/v1/notifications/*` (Phase 15, ADR-021).
abstract class NotificationsApi {
  Future<Result<NotifySettings>> settings();

  /// Any subset: `{'tone': 'gentle'}`, `{'kinds': {'weigh-in': true}}`…
  Future<Result<NotifySettings>> update(Map<String, dynamic> patch);

  /// The next days' plan; [events] are the phone's reports on earlier items.
  Future<Result<NotifyPlan>> plan(List<NotifyEvent> events);

  Future<Result<({String title, String body})>> preview(NotifyKind kind);

  Future<Result<void>> registerToken(String token);
}

class DioNotificationsApi implements NotificationsApi {
  DioNotificationsApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> r) =>
      r.data ?? (throw const FormatException('empty body'));

  @override
  Future<Result<NotifySettings>> settings() => _guard(
        () async => NotifySettings.fromJson(
          _data(
            await _dio.get<Map<String, dynamic>>('/v1/notifications/settings'),
          ),
        ),
      );

  @override
  Future<Result<NotifySettings>> update(Map<String, dynamic> patch) => _guard(
        () async => NotifySettings.fromJson(
          _data(
            await _dio.patch<Map<String, dynamic>>(
              '/v1/notifications/settings',
              data: patch,
            ),
          ),
        ),
      );

  /// Wire encoder, public for the conformance test.
  static Map<String, dynamic> planJson(List<NotifyEvent> events) => {
        'events': [for (final e in events) e.toJson()],
      };

  @override
  Future<Result<NotifyPlan>> plan(List<NotifyEvent> events) => _guard(
        () async => NotifyPlan.fromJson(
          _data(
            await _dio.post<Map<String, dynamic>>(
              '/v1/notifications/plan',
              data: planJson(events),
            ),
          ),
        ),
      );

  @override
  Future<Result<({String title, String body})>> preview(NotifyKind kind) =>
      _guard(() async {
        final d = _data(
          await _dio.post<Map<String, dynamic>>(
            '/v1/notifications/preview',
            data: {'kind': kind.wire},
          ),
        );
        return (title: d['title'] as String, body: d['body'] as String);
      });

  @override
  Future<Result<void>> registerToken(String token) => _guard(() async {
        await _dio.post<void>(
          '/v1/notifications/token',
          data: {'token': token, 'platform': 'android'},
        );
      });
}
