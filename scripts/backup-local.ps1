<#
.SYNOPSIS
  Back up the local FITOS database (the Docker volume docker_fitos-pgdata).

.DESCRIPTION
  Audit 2026-10-20: the only copy of the real data lived in one Docker volume
  on this PC, with no backup (the dev database had already been wiped once).
  This takes a pg_dump in custom format INSIDE the container (binary output
  must not pass through a PowerShell pipe), copies it out, checks that
  pg_restore can read it, and keeps the newest -Keep files.

  Backups go OUTSIDE the repository by default: they hold personal data and
  must never be committed.

.EXAMPLE
  .\scripts\backup-local.ps1
  .\scripts\backup-local.ps1 -Destination D:\Backups\fitos -Keep 30

.NOTES
  Restore (into the running container; replaces the database's contents):
    docker cp <file>.dump fitos-postgres:/tmp/restore.dump
    docker exec fitos-postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists /tmp/restore.dump'

  Nightly, with Windows Task Scheduler (run once, as yourself):
    schtasks /Create /TN "FITOS backup" /SC DAILY /ST 23:30 /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"<repo>\scripts\backup-local.ps1\""
#>
param(
  [string]$Destination = (Join-Path $env:USERPROFILE 'FitOS-backups'),
  [int]$Keep = 14,
  [string]$Container = 'fitos-postgres'
)

$ErrorActionPreference = 'Stop'

$running = docker ps --filter "name=^$Container$" --format '{{.Names}}'
if ($running -ne $Container) {
  throw "Container '$Container' is not running. Start it with: docker compose -f docker/docker-compose.yml up -d"
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$file = Join-Path $Destination "fitos-$stamp.dump"
$inside = "/tmp/fitos-$stamp.dump"

docker exec $Container sh -c "pg_dump -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" -Fc -f $inside"
if ($LASTEXITCODE -ne 0) { throw 'pg_dump failed.' }
docker cp "${Container}:$inside" $file
if ($LASTEXITCODE -ne 0) { throw 'Copying the dump out of the container failed.' }

# A backup nobody can restore is not a backup: pg_restore must be able to list it.
docker exec $Container sh -c "pg_restore --list $inside > /dev/null"
$readable = $LASTEXITCODE -eq 0
docker exec $Container rm -f $inside | Out-Null
if (-not $readable) { Remove-Item $file -Force; throw 'The dump could not be read back; it was removed.' }

$size = [math]::Round((Get-Item $file).Length / 1KB, 1)
Write-Host "Backup written: $file ($size KB)"

Get-ChildItem -Path $Destination -Filter 'fitos-*.dump' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -Skip $Keep |
  ForEach-Object { Remove-Item $_.FullName -Force; Write-Host "Removed old backup: $($_.Name)" }
