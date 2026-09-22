#!/usr/bin/env bash
# FITOS closed-alpha build (Phase 6.6 Gate 6) — bash twin of tool/alpha.ps1.
# Reads apps/mobile/alpha.env, turns it into --dart-define flags, builds /
# installs / runs against the LAN backend. Nothing from alpha.env reaches Git.
#
#   tool/alpha.sh                # debug APK
#   tool/alpha.sh --release      # release-like APK (Gate 7)
#   tool/alpha.sh --install      # build, then adb install -r
#   tool/alpha.sh --run          # flutter run on the connected phone
#   tool/alpha.sh --host 192.168.1.20
set -euo pipefail

mobile="$(cd "$(dirname "$0")/.." && pwd)"
env_file="$mobile/alpha.env"
mode=--debug; install=0; run=0; host_override=""
while [ $# -gt 0 ]; do
  case "$1" in
    --release) mode=--release ;;
    --install) install=1 ;;
    --run) run=1 ;;
    --host) host_override="$2"; shift ;;
    --env) env_file="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -f "$env_file" ] || { echo "No $env_file. Copy alpha.env.example to alpha.env and fill it in." >&2; exit 1; }

declare -A cfg
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  key="${line%%=*}"; val="${line#*=}"
  key="$(echo "$key" | xargs)"; val="$(echo "$val" | xargs)"
  [ -n "$key" ] && cfg["$key"]="$val"
done < "$env_file"

for k in FIREBASE_API_KEY FIREBASE_APP_ID FIREBASE_MESSAGING_SENDER_ID FIREBASE_PROJECT_ID GOOGLE_WEB_CLIENT_ID; do
  [ -n "${cfg[$k]:-}" ] || { echo "alpha.env is missing: $k" >&2; exit 1; }
done

api_host="${host_override:-${cfg[API_HOST]:-auto}}"
if [ "$api_host" = auto ]; then
  if command -v ipconfig >/dev/null 2>&1; then
    # Windows (Git Bash): first IPv4 that is not loopback / link-local / a virtual adapter.
    api_host="$(ipconfig | awk '/adapter/{a=$0} /IPv4/{ip=$NF; if (a !~ /vEthernet|WSL|VirtualBox|VMware|Hyper-V/ && ip !~ /^(127|169\.254)/) {print ip; exit}}')"
  elif command -v ip >/dev/null 2>&1; then
    api_host="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  elif command -v ipconfig >/dev/null 2>&1 || command -v ifconfig >/dev/null 2>&1; then
    api_host="$(ifconfig | awk '/inet /{print $2}' | grep -v '^127' | head -1)"
  fi
  [ -n "$api_host" ] || { echo "Could not detect a LAN IPv4; set API_HOST in alpha.env." >&2; exit 1; }
fi
case "$api_host" in 10.0.2.2|localhost|127.0.0.1) echo "API_HOST=$api_host is not reachable from a phone. Use the PC's LAN IP." >&2; exit 1 ;; esac
api_port="${cfg[API_PORT]:-8080}"
api_base_url="http://${api_host}:${api_port}"

mask() { local v="$1"; [ ${#v} -le 8 ] && echo '***' || echo "${v:0:4}…${v: -4}"; }
echo "FITOS alpha build"
echo "  API_BASE_URL          $api_base_url   (cleartext allowed for $api_host only)"
echo "  FIREBASE_PROJECT_ID   ${cfg[FIREBASE_PROJECT_ID]}"
echo "  FIREBASE_APP_ID       $(mask "${cfg[FIREBASE_APP_ID]}")"
echo "  FIREBASE_API_KEY      $(mask "${cfg[FIREBASE_API_KEY]}")"
echo "  GOOGLE_WEB_CLIENT_ID  $(mask "${cfg[GOOGLE_WEB_CLIENT_ID]}")"

version="$(sed -n 's/^version:[[:space:]]*//p' "$mobile/pubspec.yaml" | cut -d+ -f1 | tr -d '[:space:]')"
defines=(
  "--dart-define=FLAVOR=alpha"
  "--dart-define=APP_VERSION=$version"
  "--dart-define=API_BASE_URL=$api_base_url"
  "--dart-define=FIREBASE_API_KEY=${cfg[FIREBASE_API_KEY]}"
  "--dart-define=FIREBASE_APP_ID=${cfg[FIREBASE_APP_ID]}"
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${cfg[FIREBASE_MESSAGING_SENDER_ID]}"
  "--dart-define=FIREBASE_PROJECT_ID=${cfg[FIREBASE_PROJECT_ID]}"
  "--dart-define=GOOGLE_WEB_CLIENT_ID=${cfg[GOOGLE_WEB_CLIENT_ID]}"
)

cd "$mobile"
if [ "$run" = 1 ]; then
  exec flutter run "${defines[@]}"
fi
flutter build apk "$mode" "${defines[@]}"
apk="build/app/outputs/flutter-apk/app-${mode#--}.apk"
echo "APK: $mobile/$apk"
if [ "$install" = 1 ]; then
  adb install -r "$apk"
fi
