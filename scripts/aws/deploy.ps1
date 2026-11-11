<#
.SYNOPSIS
  FITOS beta on AWS (ADR-025): release one CI-built image to the API server.

.DESCRIPTION
  Run by the owner with their own AWS CLI profile. GitHub can push images but
  cannot deploy. In order, stopping at the first failure:

    1. the image <sha> exists in ECR (CI pushed it for this commit);
    2. on the server, through Systems Manager, deploy/aws/server/release.sh:
       pull → migrations (and the seed with -Seed) → the new container beside
       the old → /health → Caddy switched → HTTPS smoke → the old one removed;
    3. from this PC: /livez 200, /health 200, /docs 404, /docs/json 404,
       POST /v1/auth/session 401 on the public address.

  rollback.ps1 returns to the release that served before this one.
  The Google Cloud target is scripts/cloudrun/deploy.ps1; scripts/deploy.ps1
  chooses between the two.

.EXAMPLE
  .\scripts\aws\deploy.ps1 -Sha 0123456789abcdef0123456789abcdef01234567
  .\scripts\aws\deploy.ps1 -Sha <sha> -Seed
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$Sha,
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [string]$Stack = 'fitos-beta',
  [switch]$Seed,
  [switch]$SkipMigrate
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region
$out = Get-StackOutputs $Stack

Write-Host "1. image $Sha in ECR"
Invoke-Aws ecr describe-images --repository-name fitos-api --image-ids "imageTag=$Sha" --query 'imageDetails[0].imagePushedAt' --output text | Out-Null

# Beta 6.2 (audit 2026-11-11 S2): the free tier keeps automatic backups for
# one day only, so every release first takes a manual snapshot (a bad
# migration noticed later can still be undone) and keeps the newest three.
# A snapshot is consistent as of the moment it starts, so the release need not wait.
if (-not $SkipMigrate) {
  $db = Invoke-Aws rds describe-db-instances --query 'DBInstances[0].DBInstanceIdentifier' --output text
  $snapshot = "$db-pre-$($Sha.Substring(0, 7))-$(Get-Date -Format 'yyyyMMdd-HHmm')"
  Write-Host "   snapshot $snapshot"
  Invoke-Aws rds create-db-snapshot --db-instance-identifier $db --db-snapshot-identifier $snapshot --query 'DBSnapshot.Status' --output text | Out-Null
  $old = Invoke-Aws rds describe-db-snapshots --db-instance-identifier $db --snapshot-type manual --query 'reverse(sort_by(DBSnapshots, &SnapshotCreateTime))[3:].DBSnapshotIdentifier' --output text
  foreach ($id in ("$old" -split '\s+' | Where-Object { $_ -match "^$db-pre-" })) {
    Invoke-Aws rds delete-db-snapshot --db-snapshot-identifier $id --query 'DBSnapshot.DBSnapshotIdentifier' --output text | Out-Null
    Write-Host "   old snapshot $id deleted"
  }
}

$flags = @()
if ($SkipMigrate) { $flags += '--skip-migrate' }
if ($Seed) { $flags += '--seed' }
Write-Host "2. release on $($out.InstanceId)"
Invoke-ServerScript $out.InstanceId "/opt/fitos/bin/release.sh $Sha $($flags -join ' ')" | Out-Null

$base = "https://$($out.ApiDomain)"
Write-Host "3. public checks on $base"
if (-not (Test-PublicApi $base)) {
  Write-Host "The release is serving but a public check failed. To go back: .\scripts\aws\rollback.ps1" -ForegroundColor Red
  exit 1
}
Write-Host "Released $Sha at $base"
