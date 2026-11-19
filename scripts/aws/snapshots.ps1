<#
.SYNOPSIS
  FITOS beta on AWS: the database's release snapshots, and the old ones deleted.

.DESCRIPTION
  deploy.ps1 snapshots the database before every release and deletes the old
  snapshots then. With no release for a while, this does the same on its own,
  so the privacy policy's promise (2026-11-11, "How long": a snapshot is
  deleted within 30 days) holds:

    1. lists every release snapshot (<db>-pre-*), newest first;
    2. marks the ones beyond the newest three, and any older than 30 days;
    3. with -Delete only, deletes the marked ones. Deleting cannot be undone.

  Without -Delete it changes nothing. Snapshots not named <db>-pre-* (taken
  by hand in the console, or RDS's final snapshot) are never touched.

.EXAMPLE
  .\scripts\aws\snapshots.ps1            # list, and what would be deleted
  .\scripts\aws\snapshots.ps1 -Delete    # delete the marked ones
#>
[CmdletBinding()]
param(
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1',
  [switch]$Delete
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region

$db = Invoke-Aws rds describe-db-instances --query 'DBInstances[0].DBInstanceIdentifier' --output text
$rows = Invoke-Aws rds describe-db-snapshots --db-instance-identifier $db --snapshot-type manual --query 'DBSnapshots[].[DBSnapshotIdentifier,SnapshotCreateTime,AllocatedStorage,Status]' --output text
$old = @(Get-OldSnapshots $db)

Write-Host "Release snapshots of $db (newest first):"
$lines = @("$rows" -split "`n" | Where-Object { $_.Trim() } | Sort-Object { ($_.Trim() -split '\s+')[1] } -Descending)
if ($lines.Count -eq 0) { Write-Host '   none' }
foreach ($line in $lines) {
  $f = $line.Trim() -split '\s+'
  if ($f[0] -notlike "$db-pre-*") { continue }
  $mark = if ($old -contains $f[0]) { 'DELETE' } else { 'keep  ' }
  Write-Host ("   {0}  {1}  {2}  {3} GB  {4}" -f $mark, $f[0], $f[1].Substring(0, 16), $f[2], $f[3])
}

if ($old.Count -eq 0) {
  Write-Host 'Nothing to delete.'
  exit 0
}
if (-not $Delete) {
  Write-Host "$($old.Count) to delete. Run again with -Delete to delete them (cannot be undone)."
  exit 0
}
foreach ($id in $old) {
  Invoke-Aws rds delete-db-snapshot --db-snapshot-identifier $id --query 'DBSnapshot.DBSnapshotIdentifier' --output text | Out-Null
  Write-Host "   deleted $id"
}
Write-Host "Deleted $($old.Count) snapshot(s)."
