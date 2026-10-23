import 'dart:io';

import 'package:fitos/features/premium/domain/app_icons.dart';
import 'package:fitos/features/premium/presentation/app_icon_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_icon_switcher.dart';

/// Beta 3.2 (ADR-027 amendment): the app icon. The choice lives on Android
/// (one enabled activity-alias); these keep Dart, the manifest, AppIcons.kt
/// and the generated resources in step, and the controller honest.
void main() {
  group('the Android side matches AppIcon (source guard)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/me/tryfitos/app/AppIcons.kt',
    ).readAsStringSync();
    String cap(String s) => s[0].toUpperCase() + s.substring(1);

    test('one launcher alias per icon; only Standard on; MainActivity is not',
        () {
      final launchers = RegExp('android.intent.category.LAUNCHER')
          .allMatches(manifest)
          .length;
      expect(launchers, AppIcon.values.length);
      final main = RegExp(
        r'<activity\s+android:name="\.MainActivity"[\s\S]*?</activity>',
      ).firstMatch(manifest)!.group(0)!;
      expect(main, isNot(contains('LAUNCHER')));
      for (final icon in AppIcon.values) {
        final alias = RegExp(
          '<activity-alias\\s+android:name="\\.Icon${cap(icon.name)}"[\\s\\S]*?</activity-alias>',
        ).firstMatch(manifest)?.group(0);
        expect(alias, isNotNull, reason: icon.name);
        expect(
          alias,
          contains(
            'android:enabled="${icon == AppIcon.standard ? 'true' : 'false'}"',
          ),
        );
        expect(alias, contains('android:targetActivity=".MainActivity"'));
        expect(
          alias,
          contains(
            icon == AppIcon.standard
                ? 'android:icon="@mipmap/ic_launcher"'
                : 'android:icon="@mipmap/ic_launcher_${icon.name}"',
          ),
        );
      }
    });

    test('AppIcons.kt knows the same names, in the same order', () {
      final names = RegExp(r'val NAMES = listOf\(([^)]*)\)')
          .firstMatch(kotlin)!
          .group(1)!
          .split(',')
          .map((s) => s.trim().replaceAll('"', ''))
          .toList();
      expect(names, AppIcon.values.map((i) => i.name).toList());
      // The new alias is enabled before the others are disabled.
      expect(
        kotlin.indexOf('COMPONENT_ENABLED_STATE_ENABLED,'),
        lessThan(kotlin.indexOf('COMPONENT_ENABLED_STATE_DISABLED,')),
      );
      expect(kotlin, contains('DONT_KILL_APP'));
    });

    test('every icon has its resources and its preview', () {
      const res = 'android/app/src/main/res';
      for (final icon in AppIcon.values) {
        expect(File(icon.preview).existsSync(), isTrue, reason: icon.preview);
        if (icon == AppIcon.standard) continue;
        for (final path in [
          '$res/mipmap-anydpi-v26/ic_launcher_${icon.name}.xml',
          '$res/drawable-nodpi/ic_launcher_${icon.name}_background.png',
          '$res/drawable-nodpi/ic_launcher_${icon.name}_foreground.png',
        ]) {
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });
  });

  test('Standard and White are free; Gold, Glow and Lime are premium', () {
    expect(
      AppIcon.values.where((i) => !i.premium),
      [AppIcon.standard, AppIcon.white],
    );
    expect(AppIcon.byName('gold'), AppIcon.gold);
    expect(AppIcon.byName('neon'), isNull);
    expect(AppIcon.byName(null), isNull);
  });

  group('AppIconController', () {
    late FakeAppIconSwitcher phone;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [appIconSwitcherProvider.overrideWithValue(phone)],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => phone = FakeAppIconSwitcher(icon: AppIcon.white));

    test('reads the icon from the phone and changes it', () async {
      final c = container();
      expect(await c.read(appIconControllerProvider.future), AppIcon.white);
      expect(
        await c.read(appIconControllerProvider.notifier).choose(AppIcon.gold),
        isTrue,
      );
      expect(c.read(appIconControllerProvider).value, AppIcon.gold);
      expect(phone.chosen, [AppIcon.gold]);
    });

    test('the same icon again does not touch the phone', () async {
      final c = container();
      await c.read(appIconControllerProvider.future);
      expect(
        await c.read(appIconControllerProvider.notifier).choose(AppIcon.white),
        isTrue,
      );
      expect(phone.chosen, isEmpty);
    });

    test('a refusal keeps the icon as it was', () async {
      final c = container();
      await c.read(appIconControllerProvider.future);
      phone.refuse = true;
      expect(
        await c.read(appIconControllerProvider.notifier).choose(AppIcon.lime),
        isFalse,
      );
      expect(c.read(appIconControllerProvider).value, AppIcon.white);
    });

    test('not premium: a premium icon goes back to Standard, a free one stays',
        () async {
      phone.icon = AppIcon.glow;
      var c = container();
      await c
          .read(appIconControllerProvider.notifier)
          .keepWithin(premium: true);
      expect(phone.chosen, isEmpty);
      await c
          .read(appIconControllerProvider.notifier)
          .keepWithin(premium: false);
      expect(phone.chosen, [AppIcon.standard]);

      phone = FakeAppIconSwitcher(icon: AppIcon.white);
      c = container();
      await c
          .read(appIconControllerProvider.notifier)
          .keepWithin(premium: false);
      expect(phone.chosen, isEmpty);
    });

    test('a phone where the icon cannot change: nothing to keep', () async {
      phone.icon = null;
      final c = container();
      expect(await c.read(appIconControllerProvider.future), isNull);
      await c
          .read(appIconControllerProvider.notifier)
          .keepWithin(premium: false);
      expect(phone.chosen, isEmpty);
    });

    test('off Android (or without the channel) the device switcher says null',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(await const DeviceAppIconSwitcher().current(), isNull);
    });
  });
}
