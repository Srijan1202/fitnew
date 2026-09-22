<#
.SYNOPSIS
  FITOS closed-alpha build (Phase 6.6 Gate 6): reads apps/mobile/alpha.env,
  turns it into --dart-define flags, and builds / installs / runs the app
  against the LAN backend. Nothing from alpha.env is written to Git or disk.

.USAGE
  .\tool\alpha.ps1                 # debug APK (Gate 6 integration build)
  .\tool\alpha.ps1 -Release        # release-like APK (Gate 7)
  .\tool\alpha.ps1 -Install        # build, then adb install -r on the connected phone
  .\tool\alpha.ps1 -Run            # flutter run on the connected phone (hot reload)
  .\tool\alpha.ps1 -ApiHostOverride 192.168.1.20   # override API_HOST for this build
  .\tool\alpha.ps1 -SkipHealthCheck                # build even if /health does not answer

  The resolved address is COMPILED INTO the APK (Dart and the Android network
  security config). If the PC's LAN address changes -- a new Wi-Fi, a new DHCP
  lease -- the installed APK keeps calling the old one and the phone gets no
  answer at all. Rebuild after any address change; the sign-in screen and
  Profile show the address a build targets.

  alpha.env keys: FIREBASE_API_KEY FIREBASE_APP_ID FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID GOOGLE_WEB_CLIENT_ID API_HOST (or `auto`) API_PORT.
#>
[CmdletBinding()]
param(
  [switch]$Release,
  [switch]$Install,
  [switch]$Run,
  [string]$ApiHostOverride,
  [string]$EnvFile,
  [switch]$SkipHealthCheck
)

$ErrorActionPreference = 'Stop'
$mobile = Split-Path -Parent $PSScriptRoot
if (-not $EnvFile) { $EnvFile = Join-Path $mobile 'alpha.env' }
if (-not (Test-Path $EnvFile)) {
  Write-Error "No $EnvFile. Copy alpha.env.example to alpha.env and fill it in."
}

# --- read KEY=VALUE lines -------------------------------------------------
$cfg = @{}
foreach ($line in Get-Content $EnvFile) {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $i = $t.IndexOf('=')
  if ($i -lt 1) { continue }
  $k = $t.Substring(0, $i).Trim()
  $v = $t.Substring($i + 1).Trim().Trim('"')
  $cfg[$k] = $v
}

$required = 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_PROJECT_ID', 'GOOGLE_WEB_CLIENT_ID'
$missing = $required | Where-Object { -not $cfg[$_] }
if ($missing) { Write-Error "alpha.env is missing: $($missing -join ', ')" }

# --- the API host: explicit, or this PC's LAN IPv4 ------------------------
$apiHost = if ($ApiHostOverride) { $ApiHostOverride } else { $cfg['API_HOST'] }
if (-not $apiHost -or $apiHost -eq 'auto') {
  $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
      $_.InterfaceAlias -notmatch 'vEthernet|WSL|Docker|Loopback|VirtualBox|VMware|Hyper-V' -and
      $_.PrefixOrigin -in 'Dhcp', 'Manual'
    } | Sort-Object -Property @{ Expression = { if ($_.InterfaceAlias -match 'Wi-?Fi|WLAN') { 0 } else { 1 } } }
  $apiHost = ($candidates | Select-Object -First 1).IPAddress
  if (-not $apiHost) { Write-Error 'Could not detect a LAN IPv4; set API_HOST in alpha.env.' }
}
if ($apiHost -eq '10.0.2.2' -or $apiHost -eq 'localhost' -or $apiHost -eq '127.0.0.1') {
  Write-Error "API_HOST=$apiHost is not reachable from a phone. Use the PC's LAN IP."
}
$apiPort = if ($cfg['API_PORT']) { $cfg['API_PORT'] } else { '8080' }
$apiBaseUrl = "http://${apiHost}:${apiPort}"

# --- defines ----------------------------------------------------------------
$version = ((Get-Content (Join-Path $mobile 'pubspec.yaml') | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '').Split('+')[0].Trim()
$defines = @(
  "--dart-define=FLAVOR=alpha",
  "--dart-define=APP_VERSION=$version",
  "--dart-define=API_BASE_URL=$apiBaseUrl",
  "--dart-define=FIREBASE_API_KEY=$($cfg['FIREBASE_API_KEY'])",
  "--dart-define=FIREBASE_APP_ID=$($cfg['FIREBASE_APP_ID'])",
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$($cfg['FIREBASE_MESSAGING_SENDER_ID'])",
  "--dart-define=FIREBASE_PROJECT_ID=$($cfg['FIREBASE_PROJECT_ID'])",
  "--dart-define=GOOGLE_WEB_CLIENT_ID=$($cfg['GOOGLE_WEB_CLIENT_ID'])"
)

function Mask([string]$v) { if ($v.Length -le 8) { '***' } else { $v.Substring(0, 4) + '...' + $v.Substring($v.Length - 4) } }
Write-Host "FITOS alpha build"
Write-Host "  API_BASE_URL          $apiBaseUrl   (cleartext allowed for $apiHost only)"
Write-Host "  FIREBASE_PROJECT_ID   $($cfg['FIREBASE_PROJECT_ID'])"
Write-Host "  FIREBASE_APP_ID       $(Mask $cfg['FIREBASE_APP_ID'])"
Write-Host "  FIREBASE_API_KEY      $(Mask $cfg['FIREBASE_API_KEY'])"
Write-Host "  GOOGLE_WEB_CLIENT_ID  $(Mask $cfg['GOOGLE_WEB_CLIENT_ID'])"

# --- the address is baked in: prove it answers BEFORE building -------------
if (-not $SkipHealthCheck) {
  try {
    $health = Invoke-WebRequest -UseBasicParsing -Uri "$apiBaseUrl/health" -TimeoutSec 5
    if ($health.StatusCode -ne 200) { throw "HTTP $($health.StatusCode)" }
    Write-Host "  /health               200 OK"
  }
  catch {
    Write-Host ""
    Write-Host "  /health did NOT answer at $apiBaseUrl"
    Write-Host "  This address is compiled into the APK, so the app would fail the same way."
    Write-Host "  Check that the API is running (docker compose ps) and that this is still"
    Write-Host "  this PC's LAN address (ipconfig -> Wi-Fi IPv4). Set API_HOST in alpha.env,"
    Write-Host "  pass -ApiHostOverride <ip>, or -SkipHealthCheck to build anyway."
    exit 1
  }
}

Push-Location $mobile
# flutter/gradle print warnings on stderr; under 'Stop' PowerShell 5.1 would
# abort on the first one. Exit codes decide from here.
$ErrorActionPreference = 'Continue'
try {
  if ($Run) {
    & flutter run @defines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    return
  }
  $mode = if ($Release) { '--release' } else { '--debug' }
  & flutter build apk $mode @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $apk = if ($Release) { 'build\app\outputs\flutter-apk\app-release.apk' } else { 'build\app\outputs\flutter-apk\app-debug.apk' }
  Write-Host "APK: $(Join-Path $mobile $apk)"
  if ($Install) {
    & adb install -r $apk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
finally {
  Pop-Location
}
