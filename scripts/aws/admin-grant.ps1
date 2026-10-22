<#
.SYNOPSIS
  FITOS beta (ADR-022 D2): make an account an administrator, take it away,
  or list who is one, on the live server.

.DESCRIPTION
  Runs apps/api's admin-grant in the serving API container through Systems
  Manager. That container already has the Firebase credentials, so nothing
  secret passes through this PC. The account must have signed in to FITOS
  once (the app or admin.tryfitos.me). It must then sign out and in again,
  or wait up to an hour, for its token to carry the change.

  An administrator can use https://admin.tryfitos.me (every change audited)
  and has Premium by role.

.EXAMPLE
  .\scripts\aws\admin-grant.ps1 -Email friend@example.com
  .\scripts\aws\admin-grant.ps1 -Email friend@example.com -Revoke
  .\scripts\aws\admin-grant.ps1 -List
#>
[CmdletBinding(DefaultParameterSetName = 'grant')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = 'grant')]
  [ValidatePattern('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')]
  [string]$Email,
  [Parameter(ParameterSetName = 'grant')][switch]$Revoke,
  [Parameter(Mandatory = $true, ParameterSetName = 'list')][switch]$List,
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [string]$Stack = 'fitos-beta'
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region
$out = Get-StackOutputs $Stack

# The serving container: fitos-api-<first 7 of /opt/fitos/current>.
$container = 'C=fitos-api-$(cut -c1-7 /opt/fitos/current); docker ps --format "{{.Names}}" | grep -qx "$C" || { echo "no serving API container" >&2; exit 1; }'

if ($List) {
  # Read-only: every Firebase account with role admin.
  $js = @'
const { getAuth } = await import('firebase-admin/auth');
const { firebaseApp } = await import('./dist/lib/token-verifier.js');
const cp = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const auth = getAuth(firebaseApp({ projectId: process.env.FIREBASE_PROJECT_ID, ...(cp ? { credentialsPath: cp } : {}) }));
let token; let n = 0; const admins = [];
do {
  const r = await auth.listUsers(1000, token);
  for (const u of r.users) {
    n++;
    if (u.customClaims?.role === 'admin') admins.push(`${u.email ?? u.uid} | ${u.providerData.map((p) => p.providerId).join('+')} | last sign-in ${u.metadata.lastSignInTime ?? 'never'}`);
  }
  token = r.pageToken;
} while (token);
console.log(`Accounts: ${n}. Administrators: ${admins.length}`);
for (const a of admins) console.log('  ' + a);
'@
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($js -replace "`r`n", "`n")))
  $cmd = "$container; W=`$(docker inspect -f '{{.Config.WorkingDir}}' `"`$C`"); docker exec -w `"`$W/apps/api`" `"`$C`" node --input-type=module -e `"`$(printf '%s' '$b64' | base64 -d)`""
} else {
  $flag = if ($Revoke) { ' --revoke' } else { '' }
  # $Email is validated above (no quotes, spaces or shell characters).
  $cmd = "$container; docker exec `"`$C`" node apps/api/dist/scripts/admin-grant.js '$Email'$flag"
}
Invoke-ServerScript $out.InstanceId $cmd 120 | Out-Null
