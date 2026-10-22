<#
.SYNOPSIS
  FITOS beta (ADR-022 D1 amendment): publish the admin panel at
  https://admin.<domain> on the API server.

.DESCRIPTION
  Run by the owner with their own AWS CLI profile. In order, stopping at the
  first failure while what is serving keeps serving:

    1. `pnpm --filter @fitos/admin build:static` (unless -SkipBuild): the panel
       as plain files in apps/admin/out, with the Firebase client config from
       apps/admin/.env.local; then one archive of it;
    2. the archive to the private transfer bucket (stack
       fitos-website-transfer, made by the website's deploy), a 15-minute link;
    3. on the server, through Systems Manager, deploy/aws/server/admin.sh:
       SHA-256 check, unpack, the Caddyfile rendered for the serving API
       container, sites/admin.caddy, a graceful reload, an HTTPS smoke test;
    4. the transfer file deleted; public checks from this PC.

  Until the domain points at the server's Elastic IP, step 3 only puts the
  files in place and this prints the DNS record to add; run it again then.
  Sign-in also needs the domain in Firebase (Authentication -> Settings ->
  Authorized domains).

.EXAMPLE
  .\scripts\aws\admin.ps1
  .\scripts\aws\admin.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
  [string]$Domain = 'admin.tryfitos.me',
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [string]$Stack = 'fitos-beta',
  [switch]$SkipBuild
)

. (Join-Path $PSScriptRoot 'common.ps1')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Initialize-Aws $AwsProfileName $Region
$out = Get-StackOutputs $Stack
$adminDir = Join-Path $script:RepoRoot 'apps\admin'

# Does the domain point at the server? (Caddy can only get a certificate then.)
try {
  $a = @(Resolve-DnsName $Domain -Type A -Server 1.1.1.1 -DnsOnly -ErrorAction Stop |
      Where-Object { $_.Section -eq 'Answer' -and $_.Type -eq 'A' } | ForEach-Object { $_.IPAddress })
} catch { $a = @() }
$pointed = $a.Count -gt 0 -and @($a | Where-Object { $_ -ne $out.ElasticIp }).Count -eq 0

if (-not $SkipBuild) {
  Write-Host '1. build'
  if (-not (Test-Path (Join-Path $adminDir '.env.local'))) { throw 'apps/admin/.env.local (the Firebase client config) is missing; see .env.example.' }
  Push-Location $script:RepoRoot
  try {
    & pnpm --filter @fitos/admin build:static
    if ($LASTEXITCODE -ne 0) { throw 'The build failed.' }
  } finally { Pop-Location }
}
$built = Join-Path $adminDir 'out'
if (-not (Test-Path (Join-Path $built 'index.html'))) { throw 'apps/admin/out/index.html is missing: build first.' }
$commit = (& git -C $script:RepoRoot rev-parse --short=7 HEAD).Trim()
$dirty = if (& git -C $script:RepoRoot status --porcelain -- apps/admin packages/contracts) { '-dirty' } else { '' }
$release = "$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))-$commit$dirty"
$archive = Join-Path $env:TEMP "fitos-admin-$release.tar.gz"
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tar)) { $tar = 'tar' }
& $tar -czf $archive -C $built .
if ($LASTEXITCODE -ne 0) { throw 'Packing apps/admin/out failed.' }
$sha = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
Write-Host "   release $release ($([math]::Round((Get-Item $archive).Length / 1KB)) KB)"

Write-Host '2. transfer'
try { $bucket = (Get-StackOutputs 'fitos-website-transfer').BucketName }
catch { throw 'The transfer bucket (stack fitos-website-transfer) does not exist: run the website deploy (fitos-website, deploy\deploy.ps1) once.' }
$key = "s3://$bucket/admin-$release.tar.gz"
Invoke-Aws s3 cp $archive $key --only-show-errors | Out-Null
$url = Invoke-Aws s3 presign $key --expires-in 900
$command = "/opt/fitos/bin/admin.sh $Domain $release '$url' $sha"
if (-not $pointed) { $command += ' --files-only' }

Write-Host "3. on the server $($out.InstanceId)"
try {
  Invoke-ServerScript $out.InstanceId $command | Out-Null
} finally {
  Invoke-Aws s3 rm $key --only-show-errors | Out-Null
  Remove-Item $archive -ErrorAction SilentlyContinue
}

if (-not $pointed) {
  Write-Host "`nThe files are on the server, but $Domain is not served yet: it does not point at the server." -ForegroundColor Yellow
  Write-Host 'At Namecheap (Domain List -> tryfitos.me -> Advanced DNS) add:'
  Write-Host "  A  host: $($Domain.Split('.')[0])  value: $($out.ElasticIp)"
  Write-Host "In Firebase (Authentication -> Settings -> Authorized domains) add $Domain."
  Write-Host 'Then run this again with -SkipBuild.'
  exit 0
}

Write-Host "4. public checks on https://$Domain"
$checks = @(
  @{ Path = '/'; Want = 200 },
  @{ Path = '/users/'; Want = 200 },
  @{ Path = '/api/livez'; Want = 200 },
  @{ Path = '/api/v1/admin/me'; Want = 401 },
  @{ Path = '/robots.txt'; Want = 200 }
)
$ok = $true
foreach ($c in $checks) {
  try {
    $r = Invoke-WebRequest -Uri "https://$Domain$($c.Path)" -UseBasicParsing -TimeoutSec 15
    $code = [int]$r.StatusCode
  } catch [System.Net.WebException] {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
  }
  $mark = if ($code -eq $c.Want) { 'ok ' } else { $ok = $false; 'BAD' }
  Write-Host "  $mark GET $($c.Path) -> $code (want $($c.Want))"
}
if (-not $ok) { Write-Host 'A public check failed (the server-side smoke passed).' -ForegroundColor Red; exit 1 }
Write-Host "Published $release at https://$Domain/"
