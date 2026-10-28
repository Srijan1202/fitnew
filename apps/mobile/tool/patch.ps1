<#
.SYNOPSIS
  Beta 4.1 (updates plan, U1): a Shorebird patch to a FITOS release, for a fix
  that is Dart code only. Phones download it on their next start and run it
  the start after; the version and build number do not change.

.USAGE
  .\tool\patch.ps1 -Version 1.0.0-beta.4.1 -BuildNumber 18
  .\tool\patch.ps1 -Version 1.0.0-beta.4.1 -BuildNumber 18 -ReleaseRef phase-19-beta-4.1

  First it asks scripts/update-kind.mjs what changed since the release
  (-ReleaseRef, by default the tag phase-19-beta-<version after "beta.">):
  anything native (android/, a dependency, an asset, the Flutter version)
  needs a full APK through tool/hosted.ps1 and the in-app "Update now", and
  this refuses. Then tool/hosted.ps1 -Patch builds the committed HEAD in WSL
  with the same configuration as the release.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Version,
  [Parameter(Mandatory)][int]$BuildNumber,
  [string]$ReleaseRef,
  [string]$ApiBaseUrl,
  # The platform the release was built for; a patch must match it (beta 4.1
  # is android-arm64, like every hosted APK since Smart App Control).
  # '' is a release of every ABI (hosted.ps1's default).
  [ValidateSet('', 'android-arm64', 'android-arm', 'android-x64')]
  [string]$TargetPlatform = 'android-arm64',
  [switch]$SkipHealthCheck
)

$ErrorActionPreference = 'Stop'
$mobile = Split-Path -Parent $PSScriptRoot
$root = Resolve-Path (Join-Path $mobile '..\..')
if (-not $ReleaseRef) {
  $m = [regex]::Match($Version, 'beta\.([0-9.]+)$')
  if (-not $m.Success) { Write-Host "Give -ReleaseRef: no beta number in $Version."; exit 1 }
  $ReleaseRef = "phase-19-beta-$($m.Groups[1].Value)"
}

Push-Location $root
try {
  $out = & node scripts/update-kind.mjs $ReleaseRef HEAD
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally { Pop-Location }
$kind = $out[0]
Write-Host "Since $ReleaseRef`: $kind"
$out | Select-Object -Skip 1 | ForEach-Object { Write-Host $_ }
switch ($kind) {
  'apk' {
    Write-Host 'Refusing: this needs a full APK (tool/hosted.ps1 -Shorebird), not a patch.'
    exit 1
  }
  'none' {
    Write-Host 'Nothing in the app changed: no patch to make.'
    exit 0
  }
}

$hostedArgs = @{ Version = $Version; BuildNumber = $BuildNumber; Patch = $true; TargetPlatform = $TargetPlatform }
if ($ApiBaseUrl) { $hostedArgs.ApiBaseUrl = $ApiBaseUrl }
if ($SkipHealthCheck) { $hostedArgs.SkipHealthCheck = $true }
& (Join-Path $PSScriptRoot 'hosted.ps1') @hostedArgs
exit $LASTEXITCODE
