#!/bin/bash
# FITOS beta: the admin panel on the API server (ADR-022 D1 amendment).
#
# Run as root through Systems Manager by scripts/aws/admin.ps1 — never by
# hand; the server has no SSH. In order, stopping at the first failure while
# what is serving keeps serving:
#
#   1. download the panel's archive (a short-lived S3 link), check its SHA-256;
#   2. unpack it into admin/releases/<release>;
#   3. --files-only stops here (the domain does not point at this server yet,
#      so Caddy could not get a certificate);
#   4. render the Caddyfile from Caddyfile.tmpl for the serving API container,
#      as release.sh does (it holds the fitos_api snippet the panel's /api
#      uses); write sites/admin.caddy; validate, then a graceful reload;
#   5. smoke over HTTPS on this host: the panel, /api/livez through it, and
#      /api/v1/admin/me refused without a token; on failure the previous
#      Caddyfile and site config come back;
#   6. keep the newest three releases.
#
# Usage: admin.sh <domain> <release> <archive-url> <archive-sha256> [--files-only]
set -euo pipefail

DOMAIN="${1:-}"; RELEASE="${2:-}"; URL="${3:-}"; SHA="${4:-}"
shift 4 || { echo "usage: admin.sh <domain> <release> <archive-url> <archive-sha256> [--files-only]" >&2; exit 2; }
FILES_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --files-only) FILES_ONLY=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
[[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || { echo "bad domain" >&2; exit 2; }
[[ "$RELEASE" =~ ^[0-9]{14}-[0-9a-f]{7}(-dirty)?$ ]] || { echo "bad release id" >&2; exit 2; }
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "bad sha256" >&2; exit 2; }

# shellcheck source=/dev/null
source /opt/fitos/host.env   # API_DOMAIN ACME_EMAIL ...
CADDY=/opt/fitos/caddy       # mounted read-only in fitos-caddy as /etc/caddy
ADMIN="$CADDY/admin"
SITES="$CADDY/sites"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log() { printf '[admin %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# ---- 1-2. the panel -----------------------------------------------------------------
log "panel $RELEASE"
curl -fsS --retry 3 --max-time 120 -o "$TMP/admin.tar.gz" "$URL"
echo "$SHA  $TMP/admin.tar.gz" | sha256sum -c --quiet - || { echo "SHA-256 mismatch for the archive" >&2; exit 1; }
install -d -m 0755 "$ADMIN/releases" "$SITES"
rm -rf "$ADMIN/releases/$RELEASE.new"
install -d -m 0755 "$ADMIN/releases/$RELEASE.new"
tar -xzf "$TMP/admin.tar.gz" -C "$ADMIN/releases/$RELEASE.new" --no-same-owner --no-same-permissions
[ -f "$ADMIN/releases/$RELEASE.new/index.html" ] && [ -f "$ADMIN/releases/$RELEASE.new/404.html" ] ||
  { echo "the archive has no index.html or 404.html" >&2; exit 1; }
chmod -R a+rX,go-w "$ADMIN/releases/$RELEASE.new"
rm -rf "$ADMIN/releases/$RELEASE"
mv "$ADMIN/releases/$RELEASE.new" "$ADMIN/releases/$RELEASE"

if [ "$FILES_ONLY" = 1 ]; then
  log "files in place; $DOMAIN is not served yet (--files-only)"
  exit 0
fi

# ---- 4. Caddy -----------------------------------------------------------------------
docker ps --format '{{.Names}}' | grep -qx fitos-caddy || { echo "fitos-caddy is not running (release the API first)" >&2; exit 1; }
current="$(cat /opt/fitos/current 2>/dev/null || true)"
[[ "$current" =~ ^[0-9a-f]{40}$ ]] || { echo "no serving API release (/opt/fitos/current)" >&2; exit 1; }
upstream="fitos-api-${current:0:7}"
docker ps --format '{{.Names}}' | grep -qx "$upstream" || { echo "$upstream is not running" >&2; exit 1; }

cp -p "$CADDY/Caddyfile" "$TMP/Caddyfile.previous"
previous_site=""
[ -f "$SITES/admin.caddy" ] && previous_site="$(cat "$SITES/admin.caddy")"
restore() {
  cp -p "$TMP/Caddyfile.previous" "$CADDY/Caddyfile"
  if [ -n "$previous_site" ]; then printf '%s\n' "$previous_site" > "$SITES/admin.caddy"; else rm -f "$SITES/admin.caddy"; fi
  docker exec fitos-caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
}

# The same rendering as release.sh's caddyfile().
sed -e "s|__API_DOMAIN__|$API_DOMAIN|g" -e "s|__ACME_EMAIL__|$ACME_EMAIL|g" -e "s|__UPSTREAM__|$upstream|g" \
  /opt/fitos/bin/Caddyfile.tmpl > "$CADDY/Caddyfile.new"
chmod 0644 "$CADDY/Caddyfile.new"
mv "$CADDY/Caddyfile.new" "$CADDY/Caddyfile"
sed -e "s|__DOMAIN__|$DOMAIN|g" -e "s|__RELEASE__|$RELEASE|g" /opt/fitos/bin/admin.caddy > "$SITES/admin.caddy.new"
chmod 0644 "$SITES/admin.caddy.new"
mv "$SITES/admin.caddy.new" "$SITES/admin.caddy"
if ! docker exec fitos-caddy caddy validate --config /etc/caddy/Caddyfile >"$TMP/validate.log" 2>&1; then
  tail -5 "$TMP/validate.log" >&2
  restore
  echo "the new config is invalid; the previous one is back" >&2
  exit 1
fi
docker exec fitos-caddy caddy reload --config /etc/caddy/Caddyfile

# ---- 5. smoke over HTTPS, through Caddy, on this host ------------------------------------
probe() { curl -sS -o /dev/null -w '%{http_code}' --max-time 10 --resolve "$1:443:127.0.0.1" "https://$1$2" 2>/dev/null || true; }
ok=0
for _ in $(seq 1 45); do   # the first time, Caddy needs a moment for the certificate
  [ "$(probe "$DOMAIN" /)" = 200 ] && { ok=1; break; }
  sleep 2
done
if [ "$ok" = 1 ]; then
  [ "$(probe "$DOMAIN" /api/livez)" = 200 ] || ok=0
  [ "$(probe "$DOMAIN" /api/v1/admin/me)" = 401 ] || ok=0
  [ "$(probe "$API_DOMAIN" /livez)" = 200 ] || ok=0
fi
if [ "$ok" != 1 ]; then
  docker logs --since 3m fitos-caddy 2>&1 | grep -i "$DOMAIN" | tail -5 >&2 || true
  restore
  echo "HTTPS smoke failed for $DOMAIN; Caddy is back on the previous config. Does $DOMAIN point at this server's Elastic IP?" >&2
  exit 1
fi
log "serving $RELEASE at https://$DOMAIN"

# ---- 6. tidy ------------------------------------------------------------------------
ls -1 "$ADMIN/releases" | grep -v "^$RELEASE\$" | sort -r | tail -n +3 | while read -r old; do rm -rf "${ADMIN:?}/releases/$old"; done
printf '%s\n' "$RELEASE" > "$ADMIN/current"
