import 'package:dio/dio.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/water/data/water_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 6.0 (ADR-059): the emulator check found the water calls went to
/// `/water/...` without the `/v1` prefix, so every one got 404 and the taps
/// stayed "not synced yet". The fake API cannot catch that; this does.
void main() {
  test('water calls go to /v1/water', () async {
    final seen = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            seen.add('${o.method} ${o.path} ${o.data ?? ''}'.trim());
            h.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'date': '2026-11-09',
                  'ml': 500,
                  'targetMl': 2500,
                  'fromWeight': false,
                },
              ),
            );
          },
        ),
      );
    final api = DioWaterApi(dio);

    expect(await api.today(), isA<Ok<Object>>());
    expect(await api.set('2026-11-09', 500), isA<Ok<Object>>());
    expect(seen, [
      'GET /v1/water/today',
      'PUT /v1/water/days/2026-11-09 {ml: 500}',
    ]);
  });
}
