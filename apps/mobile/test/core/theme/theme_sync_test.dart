import 'package:dio/dio.dart';
import 'package:fitos/core/theme/theme_sync.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta 6.1 (E23): the theme follows the account.
void main() {
  late List<String> seen;
  late String? accountTheme;
  late bool offline;

  Dio dio() => Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          seen.add('${o.method} ${o.path} ${o.data ?? ''}'.trim());
          if (offline) {
            return h.reject(
              DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          if (o.method == 'PATCH') {
            accountTheme = (o.data as Map)['themeId'] as String;
          }
          h.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: o,
              statusCode: 200,
              data: {'units': 'metric', 'themeId': accountTheme},
            ),
          );
        },
      ),
    );

  setUp(() {
    seen = [];
    accountTheme = null;
    offline = false;
    SharedPreferences.setMockInitialValues({});
    FitPalette.followsDevice = false;
    FitPalette.current = FitPalette.byId('cobalt')!;
  });

  test("an account that never sent a theme takes this phone's", () async {
    final applied = <String>[];
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(seen, [
      'GET /v1/user/preferences',
      'PATCH /v1/user/preferences {themeId: cobalt}',
    ]);
    expect(applied, isEmpty);
  });

  test("the account's choice is applied when it differs", () async {
    accountTheme = 'violet-light';
    final applied = <String>[];
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(applied, ['violet-light']);
    expect(seen, ['GET /v1/user/preferences']);

    // The same choice: nothing to do.
    accountTheme = 'cobalt';
    applied.clear();
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(applied, isEmpty);
  });

  test('Automatic goes up as auto', () async {
    FitPalette.followsDevice = true;
    await ThemeSync(dio(), 'u1', (_) {}).send();
    expect(seen, ['PATCH /v1/user/preferences {themeId: auto}']);
  });

  test('a choice made offline is sent at the next start, not overwritten by the account', () async {
    offline = true;
    await ThemeSync(dio(), 'u1', (_) {}).send();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kThemeUnsent), 'u1');

    offline = false;
    accountTheme = 'night';
    seen.clear();
    final applied = <String>[];
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(seen, ['PATCH /v1/user/preferences {themeId: cobalt}']);
    expect(applied, isEmpty);
    expect(prefs.getString(kThemeUnsent), isNull);
  });

  test("another account's unsent choice is not sent for this one", () async {
    SharedPreferences.setMockInitialValues({kThemeUnsent: 'u0'});
    accountTheme = 'night';
    final applied = <String>[];
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(seen, ['GET /v1/user/preferences']);
    expect(applied, ['night']);
  });

  test('offline at start changes nothing', () async {
    offline = true;
    final applied = <String>[];
    await ThemeSync(dio(), 'u1', applied.add).start();
    expect(applied, isEmpty);
  });
}
