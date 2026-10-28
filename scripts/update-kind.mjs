#!/usr/bin/env node
/**
 * Beta 4.1 (updates plan, U1): does a fix go out as a Shorebird patch or a
 * full APK?
 *
 *   node scripts/update-kind.mjs <release-ref> [<head>]   (head: HEAD)
 *
 * <release-ref> is what the installed Shorebird release was built from (its
 * tag, e.g. phase-19-beta-4.1). Prints `patch`, `apk` or `none`, then why.
 *
 * A patch carries Dart code only (Shorebird's FAQ). Anything native — the
 * android/ project (Kotlin, the manifest, permissions, Gradle), a dependency
 * (pubspec.yaml or .lock: a new plugin may bring native code), assets, the
 * Shorebird config, or a new Flutter version (CI's pin) — needs an APK.
 * Changes outside the app (the API, docs, tests) need neither.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const APP = 'apps/mobile/';

/** Paths whose change needs a full APK, and why. */
const NATIVE = [
  [/^apps\/mobile\/android\//, 'the Android project (native code, manifest, Gradle)'],
  [/^apps\/mobile\/pubspec\.(yaml|lock)$/, 'a dependency (a plugin may bring native code)'],
  [/^apps\/mobile\/assets\//, 'an asset'],
  [/^apps\/mobile\/shorebird\.yaml$/, 'the Shorebird config'],
];

/** Dart the app runs: a patch carries it. */
const DART = /^apps\/mobile\/lib\/.+\.dart$/;

/**
 * @param {string[]} paths changed since the release, repo-relative
 * @param {{ flutterChanged?: boolean }} [opts]
 * @returns {{ kind: 'patch' | 'apk' | 'none', reasons: string[] }}
 */
export function classify(paths, { flutterChanged = false } = {}) {
  const native = [];
  if (flutterChanged) native.push('a new Flutter version');
  for (const p of paths) {
    const hit = NATIVE.find(([re]) => re.test(p));
    if (hit) native.push(`${p}: ${hit[1]}`);
  }
  if (native.length > 0) return { kind: 'apk', reasons: native };
  const dart = paths.filter((p) => DART.test(p));
  if (dart.length > 0) return { kind: 'patch', reasons: dart.map((p) => `${p}: Dart`) };
  const app = paths.filter((p) => p.startsWith(APP));
  return {
    kind: 'none',
    reasons: app.length > 0 ? app.map((p) => `${p}: not in the app binary`) : ['no app change'],
  };
}

/** CI's Flutter pin at a ref, e.g. "3.47.2". */
function flutterAt(ref) {
  const yml = execFileSync('git', ['show', `${ref}:.github/workflows/ci-mobile.yml`], { encoding: 'utf8' });
  return /flutter-version:\s*([\w.-]+)/.exec(yml)?.[1] ?? null;
}

function main([release, head = 'HEAD']) {
  if (!release) {
    console.error('usage: node scripts/update-kind.mjs <release-ref> [<head>]');
    process.exit(2);
  }
  const paths = execFileSync('git', ['diff', '--name-only', `${release}..${head}`], { encoding: 'utf8' })
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  const { kind, reasons } = classify(paths, { flutterChanged: flutterAt(release) !== flutterAt(head) });
  console.log(kind);
  for (const r of reasons) console.log(`  ${r}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main(process.argv.slice(2));
