#!/usr/bin/env node
/**
 * Phase 17 (§24, ADR-023 D6) — "no secret in the repo or the app binary".
 *
 *   node scripts/check-secrets.mjs            every git-tracked file
 *   node scripts/check-secrets.mjs --apk X    the APK's every entry, unpacked
 *
 * Fails (exit 1) on: private keys, service-account JSON, Google API keys,
 * GitHub/Slack/OpenAI-style tokens, and — when docker/.env is present — the
 * actual GEMINI_API_KEY value. In an APK, the Firebase client key from
 * apps/mobile/alpha.env is allowed: it is public by design (§24 "Mobile
 * secrets"); any OTHER Google key is not.
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { inflateRawSync } from 'node:zlib';

/** The repository root, whatever the working directory (hosted.ps1 runs from apps/mobile). */
const ROOT = fileURLToPath(new URL('..', import.meta.url));

const PATTERNS = [
  ['private key', /-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----/],
  ['service account', /"type"\s*:\s*"service_account"/],
  ['service account key', /"private_key"\s*:\s*"-----BEGIN/],
  ['Google API key', /AIza[0-9A-Za-z_-]{35}/g],
  ['GitHub token', /gh[pousr]_[0-9A-Za-z]{36}/],
  ['Slack token', /xox[baprs]-[0-9A-Za-z-]{10,}/],
  ['OpenAI-style key', /\bsk-[0-9A-Za-z]{32,}/],
];

function envValue(path, key) {
  if (!existsSync(path)) return null;
  const m = new RegExp(`^${key}=(.+)$`, 'm').exec(readFileSync(path, 'utf8'));
  const v = m?.[1]?.trim();
  return v === undefined || v === '' ? null : v;
}

const gemini = envValue(`${ROOT}docker/.env`, 'GEMINI_API_KEY');
const firebaseClientKey = envValue(`${ROOT}apps/mobile/alpha.env`, 'FIREBASE_API_KEY');

/** Findings in one blob of text. `allowFirebaseKey`: an APK may carry the public client key. */
function scan(name, text, allowFirebaseKey) {
  const found = [];
  for (const [label, re] of PATTERNS) {
    const matches = re.global ? [...text.matchAll(re)].map((m) => m[0]) : re.test(text) ? [re.exec(text)[0]] : [];
    for (const m of matches) {
      if (label === 'Google API key' && allowFirebaseKey && m === firebaseClientKey) continue;
      found.push(`${name}: ${label}`);
    }
  }
  if (gemini !== null && text.includes(gemini)) found.push(`${name}: the GEMINI_API_KEY value`);
  return found;
}

/** Every entry of a zip (an APK), inflated. Central directory only; enough for APKs. */
function* zipEntries(buf) {
  let eocd = buf.length - 22;
  while (eocd >= 0 && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  if (eocd < 0) throw new Error('not a zip file');
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  for (let i = 0; i < count; i++) {
    const method = buf.readUInt16LE(p + 10);
    const size = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const local = buf.readUInt32LE(p + 42);
    const name = buf.toString('utf8', p + 46, p + 46 + nameLen);
    const dataStart = local + 30 + buf.readUInt16LE(local + 26) + buf.readUInt16LE(local + 28);
    const raw = buf.subarray(dataStart, dataStart + size);
    let data = null;
    if (method === 0) data = raw;
    else if (method === 8) {
      try {
        data = inflateRawSync(raw);
      } catch {
        data = null;
      }
    }
    if (data !== null) yield [name, data];
    p += 46 + nameLen + extraLen + commentLen;
  }
}

const findings = [];
const apkIndex = process.argv.indexOf('--apk');
if (apkIndex > 0) {
  const apk = process.argv[apkIndex + 1];
  let entries = 0;
  for (const [name, data] of zipEntries(readFileSync(apk))) {
    entries++;
    findings.push(...scan(`${apk}!${name}`, data.toString('latin1'), true));
  }
  console.log(`scanned ${entries} entries in ${apk}`);
} else {
  const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8', cwd: ROOT }).split('\0').filter((f) => f !== '');
  let scanned = 0;
  for (const f of files) {
    if (!existsSync(`${ROOT}${f}`)) continue;
    const buf = readFileSync(`${ROOT}${f}`);
    if (buf.length > 5_000_000 || buf.includes(0)) continue; // large or binary
    scanned++;
    findings.push(...scan(f, buf.toString('utf8'), false));
  }
  console.log(`scanned ${scanned} tracked text files`);
}

if (findings.length > 0) {
  console.error(`\nSecrets found (${findings.length}):`);
  for (const f of findings) console.error(`  ${f}`);
  process.exit(1);
}
console.log('no secrets found');
