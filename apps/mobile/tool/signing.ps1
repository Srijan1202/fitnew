<#
.SYNOPSIS
  Beta 4.3 (ADR-043): FITOS's release signing key, and the proof that lets
  Android install a build signed with it over the debug-signed builds before.

.DESCRIPTION
  Every hosted APK up to 4.2 is signed with this PC's debug key, which Google
  Play Protect trusts least. Android (9 and newer) accepts an update signed
  with a new key when the APK carries a signed "proof of rotation" (a
  lineage) from the old key: the update installs as usual and keeps the
  phone's data. Older Android keeps checking the old key, so every APK stays
  signed with both (v1/v2 old, v3 new with the lineage).

    .\tool\signing.ps1 -Create     # once: the key and the lineage
    .\tool\signing.ps1 -Check      # the files are there and match

  Everything lives OUTSIDE the repository, in %USERPROFILE%\.fitos\signing:
    fitos-release.jks    the release key (PKCS12, RSA 4096, alias fitos)
    release.properties   its password (random, never printed, never in git)
    lineage.bin          debug key -> release key (public certificates only)

  BACK THE FOLDER UP, with ~\.android\debug.keystore, somewhere safe (a
  password manager or an encrypted drive). Without them no update can ever be
  installed over FITOS again: every tester would have to uninstall.

  tool/hosted.ps1 signs every APK it builds with them (Sign-Release).
#>
[CmdletBinding()]
param(
  [switch]$Create,
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:USERPROFILE '.fitos\signing'
$jks = Join-Path $dir 'fitos-release.jks'
$props = Join-Path $dir 'release.properties'
$lineage = Join-Path $dir 'lineage.bin'
$debugKs = Join-Path $env:USERPROFILE '.android\debug.keystore'

function Find-Tool([string]$name) {
  $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
  $found = Get-ChildItem (Join-Path $sdk "*\$name") -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
  if (-not $found) { throw "No $name in $sdk" }
  return $found.FullName
}

function Read-Password {
  foreach ($line in Get-Content $props) {
    if ($line -match '^storePassword=(.+)$') { return $Matches[1] }
  }
  throw "No storePassword in $props"
}

if ($Create) {
  if (Test-Path $jks) { Write-Host "Refusing: $jks already exists. Never replace a release key."; exit 1 }
  if (-not (Test-Path $debugKs)) { Write-Host "Refusing: no debug key at $debugKs (the key every FITOS so far is signed with)."; exit 1 }
  New-Item -ItemType Directory -Force $dir | Out-Null
  # 32 random bytes, base64url: never printed.
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $password = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  [System.IO.File]::WriteAllText($props, "storePassword=$password`nkeyAlias=fitos`n")
  $env:FITOS_SIGN_PASS = $password
  # keytool and apksigner report progress on stderr; exit codes decide.
  $ErrorActionPreference = 'Continue'
  try {
    & keytool -genkeypair -keystore $jks -storetype PKCS12 -alias fitos -keyalg RSA -keysize 4096 `
      -validity 10950 -dname 'CN=FITOS, O=FITOS, C=IN' -storepass:env FITOS_SIGN_PASS -keypass:env FITOS_SIGN_PASS
    if ($LASTEXITCODE -ne 0) { Write-Host 'keytool failed'; exit 1 }
    & (Find-Tool 'apksigner.bat') rotate --out $lineage `
      --old-signer --ks $debugKs --ks-key-alias androiddebugkey --ks-pass pass:android `
      --new-signer --ks $jks --ks-key-alias fitos --ks-pass env:FITOS_SIGN_PASS
    if ($LASTEXITCODE -ne 0) { Write-Host 'apksigner rotate failed'; exit 1 }
  }
  finally {
    Remove-Item Env:FITOS_SIGN_PASS -ErrorAction SilentlyContinue
  }
  Write-Host "Created the release key and the lineage in $dir."
  Write-Host "Back up that folder and $debugKs now: losing them means no more updates."
  exit 0
}

if ($Check) {
  foreach ($f in $jks, $props, $lineage, $debugKs) {
    if (-not (Test-Path $f)) { Write-Host "Missing: $f"; exit 1 }
  }
  $ErrorActionPreference = 'Continue'
  & (Find-Tool 'apksigner.bat') lineage --in $lineage --print-certs
  exit $LASTEXITCODE
}

Write-Host 'Pass -Create (once) or -Check.'
exit 1
