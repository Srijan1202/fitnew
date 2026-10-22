#!/bin/bash
# FITOS beta (ADR-025): release one CI-built image on the API server.
#
# Run as root through Systems Manager by scripts/aws/deploy.ps1 (and
# rollback.ps1) — never by hand over SSH; the server has no SSH. In order,
# stopping at the first failure while the release that is serving keeps
# serving:
#
#   1. pull <repo>:<sha> from ECR (CI pushed it after its smoke test);
#   2. render the env files from Parameter Store (root-only, fresh each time);
#   3. migrations as fitos_migrator (forward-only, backward-compatible, so the
#      old container keeps working against the new schema); the seed with --seed;
#   4. start fitos-api-<sha7> beside the old one and wait for /health;
#   5. point Caddy at it (a graceful reload: no dropped requests);
#   6. smoke through Caddy over HTTPS on this host;
#   7. only then remove the old container and record current/previous.
#
# Usage: release.sh <40-hex sha> [--skip-migrate] [--seed]
set -euo pipefail

SHA="${1:-}"
shift || true
MIGRATE=1
SEED=0
for arg in "$@"; do
  case "$arg" in
    --skip-migrate) MIGRATE=0 ;;
    --seed) SEED=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || { echo "usage: release.sh <40-hex sha> [--skip-migrate] [--seed]" >&2; exit 2; }

# shellcheck source=/dev/null
source /opt/fitos/host.env   # API_DOMAIN ACME_EMAIL AWS_REGION IMAGE_REPO LOG_GROUP
IMAGE="$IMAGE_REPO:$SHA"
NAME="fitos-api-${SHA:0:7}"
CADDY_IMAGE="caddy:2.10-alpine"
SECRETS=/opt/fitos/secrets
umask 077

# CloudWatch Logs when the server has a log group (always, on AWS); the
# default driver otherwise (a local rehearsal).
cloudwatch() { if [ -n "${LOG_GROUP:-}" ]; then printf '%s\n' --log-driver awslogs --log-opt "awslogs-region=$AWS_REGION" --log-opt "awslogs-group=$LOG_GROUP" --log-opt "awslogs-stream=$1"; fi; }

log() { printf '[release %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# ---- 1. image --------------------------------------------------------------------
log "pulling $IMAGE"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${IMAGE_REPO%%/*}" >/dev/null 2>&1 ||
  { echo "ECR login failed" >&2; exit 1; }
docker pull --quiet "$IMAGE" >/dev/null
docker network inspect fitos >/dev/null 2>&1 || docker network create fitos >/dev/null

# ---- 2. configuration ------------------------------------------------------------
# /fitos/beta/env/<NAME> becomes NAME=value for the API; /fitos/beta/migrator/
# for the migrate and seed jobs; /fitos/beta/files/firebase-credential.json is
# the Firebase credential (a federation config, or the fallback key).
params_to_env() {
  aws ssm get-parameters-by-path --region "$AWS_REGION" --path "$1" --with-decryption \
    --query 'Parameters[*].[Name,Value]' --output text |
    while IFS=$'\t' read -r name value; do printf '%s=%s\n' "${name##*/}" "$value"; done
}
install -d -m 0700 "$SECRETS"
install -d -m 0755 "$SECRETS/firebase"
params_to_env /fitos/beta/env/ > "$SECRETS/api.env.new"
params_to_env /fitos/beta/migrator/ > "$SECRETS/migrate.env.new"
for required in DATABASE_URL CONSENT_IP_SALT FIREBASE_PROJECT_ID; do
  grep -q "^$required=" "$SECRETS/api.env.new" || { echo "missing /fitos/beta/env/$required (scripts/aws/bootstrap.ps1, set-parameter.ps1)" >&2; exit 1; }
done
grep -q '^DATABASE_URL=' "$SECRETS/migrate.env.new" || { echo "missing /fitos/beta/migrator/DATABASE_URL (scripts/aws/bootstrap.ps1)" >&2; exit 1; }
aws ssm get-parameter --region "$AWS_REGION" --name /fitos/beta/files/firebase-credential.json --with-decryption \
  --query Parameter.Value --output text > "$SECRETS/firebase/credential.json.new"
mv "$SECRETS/api.env.new" "$SECRETS/api.env"
mv "$SECRETS/migrate.env.new" "$SECRETS/migrate.env"
mv "$SECRETS/firebase/credential.json.new" "$SECRETS/firebase/credential.json"
# The image runs as `node` (uid 1000): it may read the credential, nothing else.
chown 1000:1000 "$SECRETS/firebase/credential.json"
chmod 0400 "$SECRETS/firebase/credential.json"

job() { docker run --rm --network fitos --env-file "$SECRETS/migrate.env" "$IMAGE" "$@"; }

# ---- 3. schema -------------------------------------------------------------------
if [ "$MIGRATE" = 1 ]; then log "migrations"; job node apps/api/dist/db/migrate.js up; fi
if [ "$SEED" = 1 ]; then log "seed"; job node apps/api/dist/db/seed.js; fi

# ---- 4. the new container --------------------------------------------------------
previous="$(cat /opt/fitos/current 2>/dev/null || true)"
if [ "$previous" = "$SHA" ]; then log "$SHA is already serving: restarting it with fresh configuration"; fi
docker rm -f "$NAME" >/dev/null 2>&1 || true
log "starting $NAME"
docker run -d --name "$NAME" --network fitos --restart unless-stopped \
  --memory 1200m \
  --env-file "$SECRETS/api.env" \
  -e NODE_ENV=production -e PORT=8080 \
  -e TRUST_PROXY=1 \
  -e MESS_MIRROR_INTERVAL_HOURS=12 \
  -e GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/firebase/credential.json \
  -v "$SECRETS/firebase:/run/secrets/firebase:ro" \
  $(cloudwatch "$NAME") \
  "$IMAGE" >/dev/null

probe() { docker exec "$NAME" node -e "fetch('http://127.0.0.1:8080$1').then((r) => process.exit(r.status === 200 ? 0 : 1), () => process.exit(1))"; }
healthy=0
for _ in $(seq 1 30); do
  if probe /health 2>/dev/null; then healthy=1; break; fi
  sleep 2
done
if [ "$healthy" != 1 ]; then
  log "$NAME never answered /health 200; the serving release is untouched"
  docker logs --tail 60 "$NAME" || true
  docker rm -f "$NAME" >/dev/null
  exit 1
fi

# ---- 5. Caddy --------------------------------------------------------------------
# The directory is mounted (not the file) so a rewritten Caddyfile is seen.
caddyfile() {
  install -d -m 0755 /opt/fitos/caddy
  sed -e "s|__API_DOMAIN__|$API_DOMAIN|g" -e "s|__ACME_EMAIL__|$ACME_EMAIL|g" -e "s|__UPSTREAM__|$1|g" \
    /opt/fitos/bin/Caddyfile.tmpl > /opt/fitos/caddy/Caddyfile
  chmod 0644 /opt/fitos/caddy/Caddyfile
}
caddyfile "$NAME"
if docker ps --format '{{.Names}}' | grep -qx fitos-caddy; then
  docker exec fitos-caddy caddy reload --config /etc/caddy/Caddyfile
else
  log "starting Caddy (HTTPS for $API_DOMAIN)"
  docker rm -f fitos-caddy >/dev/null 2>&1 || true
  docker run -d --name fitos-caddy --network fitos --restart unless-stopped \
    -p 80:80 -p 443:443 \
    -v /opt/fitos/caddy:/etc/caddy:ro -v fitos-caddy-data:/data -v fitos-caddy-config:/config \
    $(cloudwatch caddy) \
    "$CADDY_IMAGE" >/dev/null
fi

# ---- 6. smoke over HTTPS, through Caddy, on this host --------------------------------
smoke_ok=0
for _ in $(seq 1 45); do
  if curl -fsS -o /dev/null --max-time 5 --resolve "$API_DOMAIN:443:127.0.0.1" "https://$API_DOMAIN/livez"; then smoke_ok=1; break; fi
  sleep 2
done
if [ "$smoke_ok" != 1 ]; then
  if [ -n "$previous" ] && [ "$previous" != "$SHA" ] && docker ps --format '{{.Names}}' | grep -qx "fitos-api-${previous:0:7}"; then
    log "HTTPS smoke failed: Caddy goes back to fitos-api-${previous:0:7}"
    caddyfile "fitos-api-${previous:0:7}"
    docker exec fitos-caddy caddy reload --config /etc/caddy/Caddyfile
    docker rm -f "$NAME" >/dev/null
  else
    log "HTTPS smoke failed on the first release. Does $API_DOMAIN point at this server's Elastic IP? (docker logs fitos-caddy)"
  fi
  exit 1
fi

# ---- 7. retire the old container --------------------------------------------------
if [ -n "$previous" ] && [ "$previous" != "$SHA" ]; then
  docker rm -f "fitos-api-${previous:0:7}" >/dev/null 2>&1 || true
  printf '%s\n' "$previous" > /opt/fitos/previous
fi
printf '%s\n' "$SHA" > /opt/fitos/current
# Only this repository's images, and never the two a rollback needs (ECR
# keeps the last 30 anyway).
for ref in $(docker images "$IMAGE_REPO" --format '{{.Repository}}:{{.Tag}}'); do
  case "${ref##*:}" in "$SHA" | "$previous") ;; *) docker rmi "$ref" >/dev/null 2>&1 || true ;; esac
done
log "serving $SHA at https://$API_DOMAIN (previous: ${previous:-none})"
