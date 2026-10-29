<#
.SYNOPSIS
  FITOS hosted build: a release APK, or (-AppBundle) the signed bundle for
  Google Play, that talks to the internet API over HTTPS. Phase 6.7 made it for
  Cloud Run; Phase 19 (ADR-025/026) points it at the beta, api.tryfitos.me on
  AWS. The LAN alpha build (tool/alpha.ps1) is separate and unchanged.

.USAGE
  .\tool\hosted.ps1                      # build (the API must answer /health)
  .\tool\hosted.ps1 -Install             # build, then adb install -r on the phone
  .\tool\hosted.ps1 -SkipHealthCheck     # build before the service answers
  .\tool\hosted.ps1 -AppBundle -Version 1.0.0-beta.1 -BuildNumber 4
                                         # the Play bundle, signed with the upload key
  .\tool\hosted.ps1 -ApiBaseUrl https://<other host>   # e.g. the Cloud Run service
  .\tool\hosted.ps1 -Shorebird -Version 1.0.0-beta.4.1 -BuildNumber 18 -TargetPlatform android-arm64
                                         # beta 4.1+: a Shorebird release (code push), built in WSL
  .\tool\patch.ps1 -Version 1.0.0-beta.4.1 -BuildNumber 18
                                         # a Shorebird patch to that release (Dart-only fixes)

  Beta 4.1 (updates plan, U1): -Shorebird builds the release through
  `shorebird release android` in WSL (tool/shorebird.sh), from the committed
  HEAD only, so its patches can be built from the same code later. It signs
  with the same debug key as every hosted APK, so it installs over them.

  Configuration: apps/mobile/hosted.env (gitignored; see hosted.env.example).
  The five Firebase values fall back to alpha.env — same Firebase project.
  API_BASE_URL falls back to https://api.tryfitos.me, the beta's domain: the
  app only ever knows the domain, so moving the server between clouds needs
  no new build (ADR-025).

  The address must be https://, a DNS name, no port, no path — checked here
  (tool/check_hosted_api_url.dart, the app's own rules) and again by Gradle.
  Version: 1.0.0-beta.1 (4) unless given, set at build time; pubspec.yaml is
  not changed, so the LAN alpha build keeps 1.0.0-alpha.1 (2). Every build
  number must be higher than the last one uploaded to Play.
  -AppBundle needs android/key.properties (the upload key, never committed;
  docs/hosting/PLAY.md) and refuses to build without it.
  Every APK and bundle is scanned for secrets before it is handed over.
  Output: build\app\outputs\flutter-apk\fitos-hosted-<version>.apk, or
          build\app\outputs\bundle\release\fitos-<version>-<build>.aab
#>
[CmdletBinding()]
param(
  [string]$ApiBaseUrl,
  [string]$Version = '1.0.0-beta.1',
  [int]$BuildNumber = 4,
  [string]$EnvFile,
  # Default: every ABI, like the Phase 6.6 release build. `android-arm64` alone
  # (the S24) when Windows Smart App Control blocks the 32-bit ARM compiler.
  [ValidateSet('', 'android-arm64', 'android-arm', 'android-x64')][string]$TargetPlatform = '',
  [switch]$Install,
  [switch]$SkipHealthCheck,
  [switch]$AppBundle,
  # Beta 4.1 (U1): a Shorebird release, or (tool/patch.ps1) a patch to one.
  [switch]$Shorebird,
  [switch]$Patch
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
  $ApiBaseUrl = 'https://api.tryfitos.me'
  $source = 'default: the beta domain (ADR-025)'
}
if ($AppBundle -and -not (Test-Path (Join-Path $mobile 'android\key.properties'))) {
  Write-Host 'Refusing to build the Play bundle: android/key.properties (the upload key) is missing.'
  Write-Host 'See docs/hosting/PLAY.md, step 1.'
  exit 1
}
if ($AppBundle -and $Install) { Write-Host '-Install applies to APKs only: a bundle goes to the Play Console.'; exit 1 }
$viaShorebird = $Shorebird -or $Patch
if ($viaShorebird) {
  if ($AppBundle) { Write-Host 'Shorebird builds the APK here, not the Play bundle.'; exit 1 }
  if ($Patch -and $Install) { Write-Host 'A patch is not installed: the app downloads it.'; exit 1 }
  # WSL signs with Windows' debug key; an upload key there is not handled yet.
  if (Test-Path (Join-Path $mobile 'android\key.properties')) {
    Write-Host 'Refusing: android/key.properties exists, and the WSL build would not sign with it.'
    exit 1
  }
  # Only committed code: the release and every patch must be rebuildable.
  $dirty = & git -C $mobile status --porcelain -- . 2>$null
  if ($dirty) {
    Write-Host 'Refusing: apps/mobile has uncommitted changes. Commit first; Shorebird builds the commit.'
    exit 1
  }
  $sha = (& git -C $mobile rev-parse HEAD).Trim()
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
    Write-Host "  Release the server first (docs/hosting/AWS.md), pass -ApiBaseUrl with another"
    Write-Host "  address, or -SkipHealthCheck to build anyway."
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
  if ($viaShorebird) {
    # Beta 4.1 (U1): tool/shorebird.sh in WSL. The defines go in the
    # environment (WSLENV), never in a file; /p turns paths into WSL ones.
    $outDir = Join-Path $mobile 'build\app\outputs\flutter-apk'
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $env:FITOS_DEFINES = $defines -join "`n"
    $env:FITOS_REPO = (Resolve-Path (Join-Path $mobile '..\..')).Path
    $env:FITOS_DEBUG_KEYSTORE = Join-Path $env:USERPROFILE '.android\debug.keystore'
    $env:FITOS_OUT = Join-Path $outDir 'app-release.apk'
    $env:WSLENV = 'FITOS_DEFINES/u:FITOS_REPO/p:FITOS_DEBUG_KEYSTORE/p:FITOS_OUT/p'
    $script = (& wsl --exec wslpath -a ((Join-Path $mobile 'tool\shorebird.sh') -replace '\\', '/')).Trim()
    $sbPlatform = if ($TargetPlatform) { $TargetPlatform } else { 'android-arm,android-arm64,android-x64' }
    try {
      if ($Patch) {
        & wsl --exec bash $script patch $sha $Version $BuildNumber $sbPlatform
      } else {
        & wsl --exec bash $script release $sha $Version $BuildNumber $sbPlatform
      }
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
      Remove-Item Env:FITOS_DEFINES, Env:FITOS_REPO, Env:FITOS_DEBUG_KEYSTORE, Env:FITOS_OUT, Env:WSLENV -ErrorAction SilentlyContinue
    }
    if ($Patch) {
      Write-Host "Patch published for $Version ($BuildNumber) from $($sha.Substring(0, 7)). Phones get it on their next start, and run it the start after."
      exit 0
    }
    $built = 'build\app\outputs\flutter-apk\app-release.apk'
    $apk = "build\app\outputs\flutter-apk\fitos-hosted-$Version.apk"
  } elseif ($AppBundle) {
    & flutter build appbundle --release --build-name=$Version --build-number=$BuildNumber @platform @defines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $built = 'build\app\outputs\bundle\release\app-release.aab'
    $apk = "build\app\outputs\bundle\release\fitos-$Version-$BuildNumber.aab"
  } else {
    & flutter build apk --release --build-name=$Version --build-number=$BuildNumber @platform @defines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $built = 'build\app\outputs\flutter-apk\app-release.apk'
    $apk = "build\app\outputs\flutter-apk\fitos-hosted-$Version.apk"
  }
  Copy-Item -Force $built $apk
  # Beta 4.3 (ADR-043): signed with FITOS's release key and the proof of
  # rotation from the debug key (tool/signing.ps1), so it installs over every
  # earlier FITOS and keeps the phone's data. v1/v2 stay with the debug key
  # for Android 8; Android 9+ checks v3, the release key.
  if (-not $AppBundle) {
    $signing = Join-Path $env:USERPROFILE '.fitos\signing'
    if (Test-Path (Join-Path $signing 'fitos-release.jks')) {
      $password = (Get-Content (Join-Path $signing 'release.properties') | Where-Object { $_ -match '^storePassword=' }) -replace '^storePassword=', ''
      $apksigner = (Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\*\apksigner.bat') | Sort-Object FullName | Select-Object -Last 1).FullName
      $env:FITOS_SIGN_PASS = $password
      try {
        & $apksigner sign `
          --ks (Join-Path $env:USERPROFILE '.android\debug.keystore') --ks-key-alias androiddebugkey --ks-pass pass:android `
          --next-signer --ks (Join-Path $signing 'fitos-release.jks') --ks-key-alias fitos --ks-pass env:FITOS_SIGN_PASS `
          --lineage (Join-Path $signing 'lineage.bin') --out "$apk.signed" $apk
        if ($LASTEXITCODE -ne 0) { Write-Host 'Signing with the release key failed.'; exit 1 }
      }
      finally {
        Remove-Item Env:FITOS_SIGN_PASS -ErrorAction SilentlyContinue
      }
      Move-Item -Force "$apk.signed" $apk
      Remove-Item -Force "$apk.signed.idsig" -ErrorAction SilentlyContinue
      $certs = & $apksigner verify --verbose --print-certs $apk
      if ($LASTEXITCODE -ne 0 -or -not ($certs -match 'Verified using v3 scheme \(APK Signature Scheme v3\): true') -or -not ($certs -match 'CN=FITOS')) {
        Write-Host 'The signed APK does not verify with the release key (v3).'
        exit 1
      }
      Write-Host '  signed                v1/v2 debug key, v3 FITOS release key (rotation)'
    }
    else {
      Write-Host '  signed                debug key only (no release key: tool/signing.ps1 -Create)'
    }
  }
  # §24 / Phase 17: nothing secret leaves in the binary (the public Firebase
  # client key is allowed in it; a private key or a server key is not).
  & node (Join-Path $mobile '..\..\scripts\check-secrets.mjs') --apk $apk
  if ($LASTEXITCODE -ne 0) { Remove-Item -Force $apk; Write-Host 'Secret scan failed: the build was removed.'; exit 1 }
  Write-Host "$(if ($AppBundle) { 'Bundle' } else { 'APK' }): $(Join-Path $mobile $apk)"
  if ($Install) {
    & adb install -r $apk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
finally {
  Pop-Location
}
