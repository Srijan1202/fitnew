<#
.SYNOPSIS
  FITOS: release one CI-built image to the chosen cloud (ADR-025). The image,
  the app and the database schema are the same on both; only the target's
  own script differs.

    -Target aws   scripts/aws/deploy.ps1       (EC2 + RDS, Mumbai — the beta)
    -Target gcp   scripts/cloudrun/deploy.ps1  (Cloud Run — ready, not in use)

  Moving the beta between clouds is: release there, copy the database
  (docs/hosting/AWS.md "Switching to Google Cloud"), point the API domain's
  DNS at it. The app keeps calling the same domain, so no new APK.

.EXAMPLE
  .\scripts\deploy.ps1 -Target aws -Sha <40-hex sha>
  .\scripts\deploy.ps1 -Target gcp -Sha <40-hex sha> -Seed
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('aws', 'gcp')][string]$Target,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$Sha,
  [switch]$Seed,
  [switch]$SkipMigrate
)

$ErrorActionPreference = 'Stop'
$script = if ($Target -eq 'aws') { 'aws\deploy.ps1' } else { 'cloudrun\deploy.ps1' }
$forward = @{ Sha = $Sha }
if ($Seed) { $forward.Seed = $true }
if ($SkipMigrate) { $forward.SkipMigrate = $true }
& (Join-Path $PSScriptRoot $script) @forward
exit $LASTEXITCODE
