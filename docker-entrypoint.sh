#!/usr/bin/env bash
set -euo pipefail

echo "[mtproxy] entrypoint started"

MT_DATA_DIR="${MT_DATA_DIR:-/data}"
PORT="${PORT:-443}"
STATS_PORT="${STATS_PORT:-8888}"
WORKERS="${WORKERS:-1}"
PUBLIC_HOST="${PUBLIC_HOST:-}"
SECURE_ONLY="${SECURE_ONLY:-false}"
TAG="${TAG:-}"

mkdir -p "$MT_DATA_DIR"
cd "$MT_DATA_DIR"

curl -fsSL https://core.telegram.org/getProxySecret -o proxy-secret
curl -fsSL https://core.telegram.org/getProxyConfig -o proxy-multi.conf

SERVER_SECRET="${CLIENT_SECRET:-}"
if [ -z "$SERVER_SECRET" ]; then
  SERVER_SECRET="$(openssl rand -hex 16)"
  echo "[mtproxy] generated SERVER_SECRET=${SERVER_SECRET}"
fi

SERVER_SECRET="${SERVER_SECRET#dd}"

if ! printf '%s' "$SERVER_SECRET" | grep -Eq '^[0-9a-fA-F]{32}$'; then
  echo "[mtproxy] invalid CLIENT_SECRET, expected exactly 32 hex chars, got: $SERVER_SECRET"
  exit 1
fi

CLIENT_SECRET_FOR_LINK="$SERVER_SECRET"
if [ "${RANDOM_PADDING:-true}" = "true" ]; then
  CLIENT_SECRET_FOR_LINK="dd${SERVER_SECRET}"
fi

echo "[mtproxy] port=${PORT}"
echo "[mtproxy] stats_port=${STATS_PORT}"
echo "[mtproxy] workers=${WORKERS}"
echo "[mtproxy] random_padding=${RANDOM_PADDING:-true}"
echo "[mtproxy] secure_only=${SECURE_ONLY}"
if [ -n "${TAG}" ]; then
  echo "[mtproxy] tag=${TAG}"
else
  echo "[mtproxy] tag=<empty>"
fi
echo "[mtproxy] server_secret_len=${#SERVER_SECRET}"
echo "[mtproxy] client_secret_len=${#CLIENT_SECRET_FOR_LINK}"

if [ -n "${PUBLIC_HOST}" ]; then
  echo "[mtproxy] tg_link=tg://proxy?server=${PUBLIC_HOST}&port=${PORT}&secret=${CLIENT_SECRET_FOR_LINK}"
  echo "[mtproxy] share_link=https://t.me/proxy?server=${PUBLIC_HOST}&port=${PORT}&secret=${CLIENT_SECRET_FOR_LINK}"
else
  echo "[mtproxy] PUBLIC_HOST is empty; set it to print a ready-to-use Telegram proxy link"
fi

args=(
  /usr/local/bin/mtproto-proxy
  -u nobody
  -p "${STATS_PORT}"
  -H "${PORT}"
  -S "${SERVER_SECRET}"
  --aes-pwd proxy-secret
  proxy-multi.conf
  -M "${WORKERS}"
)

if [ "${SECURE_ONLY}" = "true" ]; then
  args+=(-R)
fi

if [ -n "${TAG}" ]; then
  args+=(-P "${TAG}")
fi

exec "${args[@]}"
