<#
  FITOS beta on AWS (ADR-025): helpers shared by deploy.ps1, rollback.ps1,
  bootstrap.ps1 and set-parameter.ps1. Dot-source it; it does nothing alone.

  Every call runs as the owner's own AWS CLI profile (`aws configure sso`,
  default name `fitos`). No access key is stored by these scripts or passed
  on a command line, and the server is reached only through Systems Manager:
  it has no SSH.
#>

$ErrorActionPreference = 'Stop'
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-Aws {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$AwsArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & aws @AwsArgs --profile $script:AwsProfile --region $script:AwsRegion 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  if ($code -ne 0) { throw "aws $($AwsArgs[0..1] -join ' ') failed ($code): $($out -join "`n")" }
  return ($out | Where-Object { $_ -is [string] }) -join "`n"
}

function Initialize-Aws([string]$AwsProfileName, [string]$Region) {
  if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { throw 'The AWS CLI is not installed (https://aws.amazon.com/cli/).' }
  $script:AwsProfile = $AwsProfileName
  $script:AwsRegion = $Region
  $id = Invoke-Aws sts get-caller-identity --output json | ConvertFrom-Json
  Write-Host "AWS account $($id.Account) as $($id.Arn) ($Region)"
}

function Get-StackOutputs([string]$Stack) {
  $json = Invoke-Aws cloudformation describe-stacks --stack-name $Stack --query 'Stacks[0].Outputs' --output json
  $map = @{}
  foreach ($o in ($json | ConvertFrom-Json)) { $map[$o.OutputKey] = $o.OutputValue }
  return $map
}

<#
  Runs a shell script on the server as root through Systems Manager and waits.
  The deploy/aws/server/ files go with every command, so the repository is the
  only source of the server's scripts. Returns the output; throws on failure.
#>
function Invoke-ServerScript([string]$InstanceId, [string]$Command, [int]$TimeoutSeconds = 900) {
  $lines = @('set -euo pipefail', 'install -d -m 0750 /opt/fitos/bin')
  foreach ($f in Get-ChildItem (Join-Path $script:RepoRoot 'deploy\aws\server') -File) {
    $text = [IO.File]::ReadAllText($f.FullName) -replace "`r`n", "`n"
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
    $lines += "printf '%s' '$b64' | base64 -d > /opt/fitos/bin/$($f.Name)"
  }
  $lines += 'chmod 0750 /opt/fitos/bin/*.sh', $Command
  $params = @{ commands = $lines; executionTimeout = @("$TimeoutSeconds") } | ConvertTo-Json -Compress -Depth 4
  $file = Join-Path $env:TEMP "fitos-ssm-$([guid]::NewGuid()).json"
  [IO.File]::WriteAllText($file, $params)
  try {
    $commandId = Invoke-Aws ssm send-command --instance-ids $InstanceId --document-name AWS-RunShellScript `
      --comment 'fitos' --parameters "file://$file" --query Command.CommandId --output text
  } finally { Remove-Item $file -ErrorAction SilentlyContinue }

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds + 60)
  do {
    Start-Sleep -Seconds 5
    try {
      $inv = Invoke-Aws ssm get-command-invocation --command-id $commandId --instance-id $InstanceId --output json | ConvertFrom-Json
    } catch { $inv = $null } # not registered yet
  } while (($null -eq $inv -or $inv.Status -in 'Pending', 'InProgress', 'Delayed') -and (Get-Date) -lt $deadline)

  if ($null -ne $inv) {
    if ($inv.StandardOutputContent) { Write-Host $inv.StandardOutputContent }
    if ($inv.StandardErrorContent) { Write-Host $inv.StandardErrorContent -ForegroundColor Yellow }
  }
  if ($null -eq $inv -or $inv.Status -ne 'Success') { throw "the server command did not succeed ($($inv.Status))" }
  return $inv.StandardOutputContent
}

<# The same public checks as CI and the Cloud Run deploy: the release answers, and only what it should. #>
function Test-PublicApi([string]$BaseUrl) {
  $checks = @(
    @{ Method = 'GET'; Path = '/livez'; Want = 200 },
    @{ Method = 'GET'; Path = '/health'; Want = 200 },
    @{ Method = 'GET'; Path = '/docs'; Want = 404 },
    @{ Method = 'GET'; Path = '/docs/json'; Want = 404 },
    @{ Method = 'POST'; Path = '/v1/auth/session'; Want = 401 }
  )
  $ok = $true
  foreach ($c in $checks) {
    try {
      $r = Invoke-WebRequest -Uri "$BaseUrl$($c.Path)" -Method $c.Method -UseBasicParsing -ContentType 'application/json' -Body $(if ($c.Method -eq 'POST') { '{}' } else { $null }) -TimeoutSec 15
      $code = [int]$r.StatusCode
    } catch [System.Net.WebException] {
      $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    }
    $mark = if ($code -eq $c.Want) { 'ok ' } else { $ok = $false; 'BAD' }
    Write-Host "  $mark $($c.Method) $($c.Path) -> $code (want $($c.Want))"
  }
  return $ok
}
