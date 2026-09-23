<#
.SYNOPSIS
  FITOS hosted alpha (Phase 6.7): release one CI-built image to Cloud Run.

.DESCRIPTION
  Run by the owner, authenticated with `gcloud auth login` (GitHub holds no
  deploy rights — O5). In order, stopping at the first failure:

    1. the image exists in Artifact Registry (CI pushed it for this commit);
    2. fitos-migrate-alpha runs THIS image's migrations (idempotent; forward-only,
       backward-compatible, so the revision still serving keeps working);
    3. fitos-seed-alpha, only with -Seed (reference data changed);
    4. a new revision of fitos-api-alpha with NO traffic, tagged sha-<7>;
    5. smoke on the tag's own URL: /livez 200, /health 200, /docs 404,
       POST /v1/auth/session 401;
    6. only then 100% of traffic to that revision.

  The revision that was serving is printed first: rollback.ps1 returns to it.
  The service's configuration (identity, secrets, env, scaling, probe) is set
  once by docs/hosting/CLOUD-RUN.md and carried over by every deploy.

.EXAMPLE
  .\scripts\cloudrun\deploy.ps1 -Sha 0123456789abcdef0123456789abcdef01234567
  .\scripts\cloudrun\deploy.ps1 -Sha <sha> -Seed
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$Sha,
  [string]$Project = 'fitos-dev-3208b',
  [string]$Region = 'asia-south1',
  [string]$Service = 'fitos-api-alpha',
  [string]$MigrateJob = 'fitos-migrate-alpha',
  [string]$SeedJob = 'fitos-seed-alpha',
  [switch]$Seed,
  [switch]$SkipMigrate
)

$ErrorActionPreference = 'Stop'
$image = "$Region-docker.pkg.dev/$Project/fitos/fitos-api:$Sha"
$tag = "sha-$($Sha.Substring(0, 7))"
$common = @('--project', $Project, '--region', $Region)

function Invoke-Gcloud {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GcloudArgs)
  # gcloud reports progress on stderr; the exit code decides.
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

function Get-Status([string]$Url, [string]$Method = 'GET') {
  try {
    $params = @{ Uri = $Url; Method = $Method; UseBasicParsing = $true; TimeoutSec = 60 }
    if ($Method -eq 'POST') {
      $params.Body = '{}'
      $params.ContentType = 'application/json'
    }
    return [int](Invoke-WebRequest @params).StatusCode
  }
  catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    return 0
  }
}

Write-Host "FITOS deploy  $Service  ($Project, $Region)"
Write-Host "  image       $image"

# --- 0. what serves now -------------------------------------------------------
$before = (Invoke-Gcloud run services describe $Service @common --format=json) | Out-String | ConvertFrom-Json
$serving = @($before.status.traffic | Where-Object { $_.percent -gt 0 } | ForEach-Object { "$($_.revisionName)=$($_.percent)%" })
Write-Host "  serving now $($serving -join ', ')   (rollback: .\scripts\cloudrun\rollback.ps1)"

# --- 1. the image exists ---------------------------------------------------------
Invoke-Gcloud artifacts docker images describe $image --project $Project --format='value(image_summary.digest)' | Out-Null
Write-Host "  [1] image found"

# --- 2/3. jobs with THIS image ------------------------------------------------------
if (-not $SkipMigrate) {
  Invoke-Gcloud run jobs update $MigrateJob --image $image @common --quiet | Out-Null
  Invoke-Gcloud run jobs execute $MigrateJob @common --wait | Out-Null
  Write-Host "  [2] migrations applied ($MigrateJob)"
}
else {
  Write-Host "  [2] migrations skipped (-SkipMigrate)"
}
if ($Seed) {
  Invoke-Gcloud run jobs update $SeedJob --image $image @common --quiet | Out-Null
  Invoke-Gcloud run jobs execute $SeedJob @common --wait | Out-Null
  Write-Host "  [3] seed applied ($SeedJob)"
}

# --- 4. a revision with no traffic ------------------------------------------------------
Invoke-Gcloud run deploy $Service --image $image @common --no-traffic --tag $tag --quiet | Out-Null
$after = (Invoke-Gcloud run services describe $Service @common --format=json) | Out-String | ConvertFrom-Json
$tagged = $after.status.traffic | Where-Object { $_.tag -eq $tag } | Select-Object -First 1
if (-not $tagged -or -not $tagged.url) { throw "no URL for tag $tag" }
$revision = $tagged.revisionName
Write-Host "  [4] revision $revision (no traffic) at $($tagged.url)"

# --- 5. smoke on the tagged URL --------------------------------------------------------------
$checks = @(
  @{ Path = '/livez'; Method = 'GET'; Want = 200 },
  @{ Path = '/health'; Method = 'GET'; Want = 200 },
  @{ Path = '/docs'; Method = 'GET'; Want = 404 },
  @{ Path = '/v1/auth/session'; Method = 'POST'; Want = 401 }
)
$failed = $false
foreach ($c in $checks) {
  $got = Get-Status "$($tagged.url)$($c.Path)" $c.Method
  $mark = if ($got -eq $c.Want) { 'ok' } else { 'FAIL' }
  if ($got -ne $c.Want) { $failed = $true }
  Write-Host ("  [5] {0,-5} {1,-18} {2} (want {3}) {4}" -f $c.Method, $c.Path, $got, $c.Want, $mark)
}
if ($failed) {
  Write-Host ""
  Write-Host "  Smoke failed: traffic NOT moved. $revision stays at 0%; still serving: $($serving -join ', ')."
  exit 1
}

# --- 6. traffic ------------------------------------------------------------------------------
Invoke-Gcloud run services update-traffic $Service @common --to-revisions "$revision=100" --quiet | Out-Null
Write-Host "  [6] 100% -> $revision"
Write-Host "  previous: $($serving -join ', ')"
