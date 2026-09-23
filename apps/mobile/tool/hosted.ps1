<#
.SYNOPSIS
  FITOS hosted build (Phase 6.7 Gate 6.7-2): a release APK that talks to the
  internet API on Cloud Run over HTTPS. The LAN alpha build (tool/alpha.ps1)
  is separate and unchanged.

.USAGE
  .\tool\hosted.ps1                      # build (the API must answer /health)
  .\tool\hosted.ps1 -Install             # build, then adb install -r on the phone
  .\tool\hosted.ps1 -SkipHealthCheck     # build before the service exists (Gate 6.7-2)
  .\tool\hosted.ps1 -ApiBaseUrl https://api.tryfitos.me   # later, once the domain is set up

  Configuration: apps/mobile/hosted.env (gitignored; see hosted.env.example).
  The five Firebase values fall back to alpha.env — same Firebase project.
  API_BASE_URL falls back to the Cloud Run service's deterministic address,
  https://<Service>-<project number>.<Region>.run.app, where the project
  number is FIREBASE_MESSAGING_SENDER_ID.

  The address must be https://, a DNS name, no port, no path — checked here
  (tool/check_hosted_api_url.dart, the app's own rules) and again by Gradle.
  Version: 1.0.0-alpha.2 (3) set at build time; pubspec.yaml is not changed,
  so the LAN alpha build keeps 1.0.0-alpha.1 (2).
  Output: build\app\outputs\flutter-apk\fitos-hosted-<version>.apk
#>
[CmdletBinding()]
param(
  [string]$ApiBaseUrl,
  [string]$Service = 'fitos-api-alpha',
  [string]$Region = 'asia-south1',
  [string]$Version = '1.0.0-alpha.2',
  [int]$BuildNumber = 3,
  [string]$EnvFile,
  # Default: every ABI, like the Phase 6.6 release build. `android-arm64` alone
  # (the S24) when Windows Smart App Control blocks the 32-bit ARM compiler.
  [ValidateSet('', 'android-arm64', 'android-arm', 'android-x64')][string]$TargetPlatform = '',
  [switch]$Install,
  [switch]$SkipHealthCheck
)

$ErrorActionPreference = 'Stop'
$mobile = Split-Path -Parent $PSScriptRoot
if (-not $EnvFile) { $EnvFile = Join-Path $mobile 'hosted.env' }

function Read-EnvFile([string]$Path) {
  $values = @{}
  if (-not (Test-Path $Path)) { return $values }
  foreach ($line in Get-Content $Path) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $i = $t.IndexOf('=')
    if ($i -lt 1) { continue }
    $values[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim().Trim('"')
  }
  return $values
}

# --- configuration: hosted.env, Firebase falling back to alpha.env ---------------
$cfg = Read-EnvFile $EnvFile
$alpha = Read-EnvFile (Join-Path $mobile 'alpha.env')
$firebaseKeys = 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_PROJECT_ID', 'GOOGLE_WEB_CLIENT_ID'
$firebaseFrom = @{}
foreach ($k in $firebaseKeys) {
  if (-not $cfg[$k] -and $alpha[$k]) { $cfg[$k] = $alpha[$k]; $firebaseFrom[$k] = 'alpha.env' }
  elseif ($cfg[$k]) { $firebaseFrom[$k] = 'hosted.env' }
}
$missing = $firebaseKeys | Where-Object { -not $cfg[$_] }
if ($missing) { Write-Error "Missing (in hosted.env or alpha.env): $($missing -join ', ')" }

# --- the API address ---------------------------------------------------------------
$source = 'parameter'
if (-not $ApiBaseUrl) { $ApiBaseUrl = $cfg['API_BASE_URL']; $source = 'hosted.env' }
if (-not $ApiBaseUrl) {
  $ApiBaseUrl = "https://$Service-$($cfg['FIREBASE_MESSAGING_SENDER_ID']).$Region.run.app"
  $source = "derived: Cloud Run deterministic URL of $Service in $Region (confirm after the first deploy)"
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

Push-Location $mobile
$ErrorActionPreference = 'Continue'
try {
  # dart prints "Running build hooks..." on stderr; keep only the verdict.
  $verdict = & dart run tool/check_hosted_api_url.dart $ApiBaseUrl 2>&1 |
    ForEach-Object { ("$_" -replace 'Running build hooks\.\.\.', '').Trim() } | Where-Object { $_ }
  if ($LASTEXITCODE -ne 0) {
    Write-Host ($verdict -join ' ')
    Write-Host "Refusing to build: this is not a hosted API address (https, DNS name, no port, no path)."
    exit 1
  }
}
finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}

function Mask([string]$v) { if ($v.Length -le 8) { '***' } else { $v.Substring(0, 4) + '...' + $v.Substring($v.Length - 4) } }
Write-Host "FITOS hosted build"
Write-Host "  API_BASE_URL          $ApiBaseUrl"
Write-Host "                        ($source)"
Write-Host "  version               $Version ($BuildNumber)   flavour hosted   no cleartext"
Write-Host "  FIREBASE_PROJECT_ID   $($cfg['FIREBASE_PROJECT_ID'])   (Firebase from $(@($firebaseFrom.Values | Sort-Object -Unique) -join ' + '))"
Write-Host "  FIREBASE_APP_ID       $(Mask $cfg['FIREBASE_APP_ID'])"
Write-Host "  FIREBASE_API_KEY      $(Mask $cfg['FIREBASE_API_KEY'])"
Write-Host "  GOOGLE_WEB_CLIENT_ID  $(Mask $cfg['GOOGLE_WEB_CLIENT_ID'])"

# --- the address is compiled in: prove it answers BEFORE building ---------------------
if (-not $SkipHealthCheck) {
  try {
    $health = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/health" -TimeoutSec 30
    if ($health.StatusCode -ne 200) { throw "HTTP $($health.StatusCode)" }
    Write-Host "  /health               200 OK"
  }
  catch {
    Write-Host ""
    Write-Host "  /health did NOT answer at $ApiBaseUrl"
    Write-Host "  Deploy the service first (docs/hosting/CLOUD-RUN.md), pass -ApiBaseUrl with the"
    Write-Host "  URL gcloud reports, or -SkipHealthCheck to build anyway."
    exit 1
  }
}
else {
  Write-Host "  /health               not checked (-SkipHealthCheck)"
}

$defines = @(
  "--dart-define=FLAVOR=hosted",
  "--dart-define=APP_VERSION=$Version",
  "--dart-define=API_BASE_URL=$ApiBaseUrl",
  "--dart-define=FIREBASE_API_KEY=$($cfg['FIREBASE_API_KEY'])",
  "--dart-define=FIREBASE_APP_ID=$($cfg['FIREBASE_APP_ID'])",
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$($cfg['FIREBASE_MESSAGING_SENDER_ID'])",
  "--dart-define=FIREBASE_PROJECT_ID=$($cfg['FIREBASE_PROJECT_ID'])",
  "--dart-define=GOOGLE_WEB_CLIENT_ID=$($cfg['GOOGLE_WEB_CLIENT_ID'])"
)

Push-Location $mobile
# flutter/gradle print warnings on stderr; exit codes decide from here.
$ErrorActionPreference = 'Continue'
try {
  $platform = if ($TargetPlatform) { @('--target-platform', $TargetPlatform) } else { @() }
  & flutter build apk --release --build-name=$Version --build-number=$BuildNumber @platform @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $built = 'build\app\outputs\flutter-apk\app-release.apk'
  $apk = "build\app\outputs\flutter-apk\fitos-hosted-$Version.apk"
  Copy-Item -Force $built $apk
  Write-Host "APK: $(Join-Path $mobile $apk)"
  if ($Install) {
    & adb install -r $apk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
finally {
  Pop-Location
}
