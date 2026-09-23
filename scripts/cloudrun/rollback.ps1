<#
.SYNOPSIS
  FITOS hosted alpha (Phase 6.7): send all traffic back to an earlier revision.

.DESCRIPTION
  Cloud Run keeps earlier revisions; rolling back moves traffic, it does not
  rebuild anything. Without -Revision it picks the newest READY revision older
  than the one serving now, and asks before moving. The database is NOT rolled
  back: migrations are forward-only and backward-compatible (spec §25), so the
  earlier revision runs on the current schema. A bad migration is a restore
  (Neon's 6-hour window or the nightly dump), decided separately.

.EXAMPLE
  .\scripts\cloudrun\rollback.ps1
  .\scripts\cloudrun\rollback.ps1 -Revision fitos-api-alpha-00007-abc
#>
[CmdletBinding()]
param(
  [string]$Revision,
  [string]$Project = 'fitos-dev-3208b',
  [string]$Region = 'asia-south1',
  [string]$Service = 'fitos-api-alpha',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$common = @('--project', $Project, '--region', $Region)

function Invoke-Gcloud {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GcloudArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & gcloud @GcloudArgs
    $code = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previous
  }
  if ($code -ne 0) { throw "gcloud $($GcloudArgs -join ' ') failed (exit $code)" }
  return $out
}

$svc = (Invoke-Gcloud run services describe $Service @common --format=json) | Out-String | ConvertFrom-Json
$current = $svc.status.traffic | Where-Object { $_.percent -gt 0 } | Sort-Object -Property percent -Descending | Select-Object -First 1
if (-not $current) { throw "no revision is serving $Service" }
Write-Host "serving now: $($current.revisionName) ($($current.percent)%)"

$revisions = (Invoke-Gcloud run revisions list --service $Service @common --format=json) | Out-String | ConvertFrom-Json
$ready = $revisions |
  Where-Object { ($_.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }) } |
  Sort-Object -Property { [datetime]$_.metadata.creationTimestamp } -Descending

if (-not $Revision) {
  $currentCreated = [datetime](($ready | Where-Object { $_.metadata.name -eq $current.revisionName } | Select-Object -First 1).metadata.creationTimestamp)
  $candidate = $ready | Where-Object { [datetime]$_.metadata.creationTimestamp -lt $currentCreated } | Select-Object -First 1
  if (-not $candidate) { throw 'no earlier ready revision to roll back to' }
  $Revision = $candidate.metadata.name
}
elseif (-not ($ready | Where-Object { $_.metadata.name -eq $Revision })) {
  throw "$Revision is not a ready revision of $Service"
}

Write-Host "roll back to: $Revision"
if (-not $Yes) {
  $answer = Read-Host 'Move 100% of traffic? (yes/no)'
  if ($answer -ne 'yes') { Write-Host 'nothing changed'; exit 0 }
}

Invoke-Gcloud run services update-traffic $Service @common --to-revisions "$Revision=100" --quiet | Out-Null

$url = $svc.status.url
foreach ($path in '/livez', '/health') {
  try { $code = [int](Invoke-WebRequest -Uri "$url$path" -UseBasicParsing -TimeoutSec 60).StatusCode }
  catch { $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 } }
  Write-Host ("  {0,-8} {1}" -f $path, $code)
}
Write-Host "100% -> $Revision (was $($current.revisionName))"
