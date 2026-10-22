<#
.SYNOPSIS
  FITOS beta on AWS (ADR-025): the one-time database setup, after the stack
  exists and while its BootstrapMode is true.

.DESCRIPTION
  On the server, through Systems Manager (deploy/aws/server/bootstrap.sh):
  creates fitos_migrator and fitos_app on RDS with passwords generated there,
  and stores their connection strings and a fresh consent salt in Parameter
  Store. No password is shown here, typed, or written on this PC.
  Refuses to run a second time.

  Afterwards: set BootstrapMode=false (docs/hosting/AWS.md, step 6) so the
  server can no longer read the RDS master secret or write parameters.
#>
[CmdletBinding()]
param(
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [string]$Stack = 'fitos-beta'
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region
$out = Get-StackOutputs $Stack
Invoke-ServerScript $out.InstanceId "/opt/fitos/bin/bootstrap.sh '$($out.DatabaseMasterSecretArn)' '$($out.DatabaseEndpoint)'" | Out-Null
Write-Host 'Done. Next: set-parameter.ps1 for FIREBASE_PROJECT_ID, the Firebase credential and (optionally) GEMINI_API_KEY.'
