#!/bin/bash
# FITOS beta (ADR-025): one-time database and secret setup, run as root on the
# API server through Systems Manager by scripts/aws/bootstrap.ps1.
#
# - creates fitos_migrator and fitos_app on RDS (db-roles.sql) with passwords
#   generated here, and stores their connection strings in Parameter Store;
# - generates the consent-hash salt.
# Nothing is printed except what was created. Refuses to run twice (the
# roles would exist); --force is not offered on purpose: re-creating roles is
# a manual decision.
#
# Needs the stack's BootstrapMode=true (read the RDS master secret, write
# parameters). Set it back to false afterwards.
#
# Usage: bootstrap.sh <master secret arn> <database host>
set -euo pipefail
SECRET_ARN="${1:?master secret arn}"
DB_HOST="${2:?database host}"
# shellcheck source=/dev/null
source /opt/fitos/host.env
umask 077

exists() { aws ssm get-parameter --region "$AWS_REGION" --name "$1" >/dev/null 2>&1; }
put() { aws ssm put-parameter --region "$AWS_REGION" --name "$1" --type SecureString --value "$2" >/dev/null; }

if exists /fitos/beta/env/DATABASE_URL || exists /fitos/beta/migrator/DATABASE_URL; then
  echo "already bootstrapped: /fitos/beta/env/DATABASE_URL exists. Nothing changed." >&2
  exit 1
fi

master_json="$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$SECRET_ARN" --query SecretString --output text)"
master_user="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["username"])' <<<"$master_json")"
master_password="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])' <<<"$master_json")"
unset master_json

# Hex: no character needs escaping in a URL.
migrator_password="$(openssl rand -hex 24)"
app_password="$(openssl rand -hex 24)"

echo "creating the roles on $DB_HOST"
docker network inspect fitos >/dev/null 2>&1 || docker network create fitos >/dev/null
docker run --rm -i --network fitos -e PGPASSWORD="$master_password" postgres:18-alpine \
  psql "host=$DB_HOST port=5432 dbname=fitos user=$master_user sslmode=require" \
  -v migrator_password="$migrator_password" -v app_password="$app_password" \
  < /opt/fitos/bin/db-roles.sql
unset master_password

put /fitos/beta/migrator/DATABASE_URL "postgres://fitos_migrator:$migrator_password@$DB_HOST:5432/fitos?sslmode=require"
put /fitos/beta/env/DATABASE_URL "postgres://fitos_app:$app_password@$DB_HOST:5432/fitos?sslmode=require"
unset migrator_password app_password
if ! exists /fitos/beta/env/CONSENT_IP_SALT; then put /fitos/beta/env/CONSENT_IP_SALT "$(openssl rand -hex 32)"; fi

echo "created: fitos_migrator, fitos_app; /fitos/beta/migrator/DATABASE_URL, /fitos/beta/env/DATABASE_URL, /fitos/beta/env/CONSENT_IP_SALT"
