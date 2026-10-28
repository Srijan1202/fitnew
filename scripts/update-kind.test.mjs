// Beta 4.1 (U1): patch or APK, on sample diffs. Run: node --test scripts/update-kind.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { classify } from './update-kind.mjs';

test('Dart only in the app: a patch (4.0.1’s Start-button fix would have been one)', () => {
  const r = classify([
    'apps/mobile/lib/features/running/presentation/screens/run_start.dart',
    'apps/mobile/test/features/running/running_screens_test.dart',
    'docs/phase-plans/beta-4.1-updates-plan.md',
  ]);
  assert.equal(r.kind, 'patch');
  assert.deepEqual(r.reasons, ['apps/mobile/lib/features/running/presentation/screens/run_start.dart: Dart']);
});

test('anything native needs the APK, even with Dart beside it', () => {
  for (const path of [
    'apps/mobile/android/app/src/main/kotlin/me/tryfitos/app/MainActivity.kt',
    'apps/mobile/android/app/src/main/AndroidManifest.xml',
    'apps/mobile/android/app/build.gradle.kts',
    'apps/mobile/pubspec.yaml',
    'apps/mobile/pubspec.lock',
    'apps/mobile/assets/sounds/rest_done.wav',
    'apps/mobile/shorebird.yaml',
  ]) {
    const r = classify(['apps/mobile/lib/app.dart', path]);
    assert.equal(r.kind, 'apk', path);
    assert.equal(r.reasons.length, 1, path);
    assert.ok(r.reasons[0].startsWith(`${path}: `), path);
  }
});

test('a new Flutter version needs the APK', () => {
  const r = classify(['apps/mobile/lib/app.dart'], { flutterChanged: true });
  assert.equal(r.kind, 'apk');
  assert.deepEqual(r.reasons, ['a new Flutter version']);
});

test('nothing the app runs: neither', () => {
  assert.equal(classify(['apps/api/src/modules/running/service.ts', 'docs/x.md']).kind, 'none');
  assert.deepEqual(classify([]).reasons, ['no app change']);
  const tests = classify(['apps/mobile/test/widget_test.dart', 'apps/mobile/tool/hosted.ps1']);
  assert.equal(tests.kind, 'none');
  assert.equal(tests.reasons.length, 2);
});

test('only Dart under lib/ counts as code', () => {
  assert.equal(classify(['apps/mobile/lib/README.md']).kind, 'none');
  assert.equal(classify(['apps/mobile/lib/core/db/app_database.g.dart']).kind, 'patch');
});
