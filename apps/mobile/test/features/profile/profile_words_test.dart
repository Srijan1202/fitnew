import 'package:fitos/core/config/device_time_zone.dart';
import 'package:fitos/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 6.0 emulator check: Profile showed the targets' reason code as is
/// ("goal-change") and called Asia/Calcutta and Asia/Kolkata two zones.
void main() {
  test('the targets line says why in words', () {
    expect(
      targetsLine('2026-09-22', 'goal-change'),
      'Since 2026-09-22 · after your goal changed',
    );
    expect(
      targetsLine('2026-09-22', 'onboarding'),
      'Since 2026-09-22 · set when you joined',
    );
    expect(targetsLine('2026-09-22', 'something-new'), 'Since 2026-09-22');
  });

  test("the phone's old zone name is read as the current one", () {
    expect(DeviceTimeZone.current('Asia/Calcutta'), 'Asia/Kolkata');
    expect(DeviceTimeZone.current('Europe/Kiev'), 'Europe/Kyiv');
    expect(DeviceTimeZone.current('Asia/Kolkata'), 'Asia/Kolkata');
    expect(DeviceTimeZone.current(null), isNull);
  });
}
