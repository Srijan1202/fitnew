import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home_widgets/presentation/home_widgets_coordinator.dart';
import 'package:fitos/features/water/presentation/water_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_water_api.dart';

/// Beta 6.4 (N1, owner Q4): glasses tapped on the home-screen widget with
/// FITOS closed reach their days when FITOS next starts.
void main() {
  late FakeWaterApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    api = FakeWaterApi(date: '2026-11-17')..days['2026-11-17'] = 500;
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue('u-1'),
        localTodayProvider.overrideWithValue('2026-11-17'),
        waterApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> apply(ProviderContainer c, Map<String, int> taps) =>
      c.read(FutureProvider((ref) => addWidgetWater(ref, taps)).future);

  test('today’s glasses add to today’s total and are sent as the total',
      () async {
    final c = container();
    await apply(c, {'2026-11-17': 2});
    expect(c.read(waterProvider).value!.ml, 1000);
    await Future<void>.delayed(
      WaterController.sendAfter + const Duration(milliseconds: 200),
    );
    expect(api.calls.last, 'set:2026-11-17:1000');
  });

  test('a glass from before midnight goes to that day', () async {
    final c = container();
    await apply(c, {'2026-11-16': 1});
    expect(api.calls, contains('set:2026-11-16:250'));
    // Today is untouched.
    expect(api.days['2026-11-17'], 500);
  });

  test('offline: that day is kept to be sent the next time', () async {
    final c = container();
    await c.read(waterProvider.future);
    api.failure = const Offline();
    await c.read(waterProvider.notifier).addToDay('2026-11-16', 500);
    final raw =
        (await SharedPreferences.getInstance()).getString('water.v1.u-1');
    expect(raw, contains('"date":"2026-11-16"'));
    expect(raw, contains('"unsynced":true'));
  });
}
