<#
.SYNOPSIS
  FITOS beta on AWS (ADR-025): serve the release that served before the
  current one again, without running migrations (they are forward-only and
  backward-compatible, so the older code works on the newer schema).

.EXAMPLE
  .\scripts\aws\rollback.ps1
  .\scripts\aws\rollback.ps1 -Sha <40-hex sha>    # a specific earlier release
#>
[CmdletBinding()]
param(
  [ValidatePattern('^([0-9a-f]{40})?$')][string]$Sha = '',
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [string]$Stack = 'fitos-beta'
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region
$out = Get-StackOutputs $Stack

if (-not $Sha) {
  $Sha = (Invoke-ServerScript $out.InstanceId 'cat /opt/fitos/previous').Trim()
  if ($Sha -notmatch '^[0-9a-f]{40}$') { throw 'No previous release is recorded on the server.' }
}
Write-Host "Rolling back to $Sha"
Invoke-ServerScript $out.InstanceId "/opt/fitos/bin/release.sh $Sha --skip-migrate" | Out-Null
if (-not (Test-PublicApi "https://$($out.ApiDomain)")) { exit 1 }
Write-Host "Serving $Sha"
