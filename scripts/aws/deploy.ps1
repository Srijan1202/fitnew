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
