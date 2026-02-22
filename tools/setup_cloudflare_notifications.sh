#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-hrmstore}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CF_DIR="$REPO_ROOT/cloudflare"
WRANGLER_BIN=(npx --prefix "$CF_DIR" wrangler)
FIREBASE_CFG="$HOME/.config/configstore/firebase-tools.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required."
  exit 1
fi

if [[ ! -f "$CF_DIR/wrangler.toml" ]]; then
  if [[ -f "$CF_DIR/wrangler.toml.example" ]]; then
    cp "$CF_DIR/wrangler.toml.example" "$CF_DIR/wrangler.toml"
  else
    echo "Missing cloudflare/wrangler.toml and cloudflare/wrangler.toml.example."
    exit 1
  fi
fi

if [[ ! -f "$FIREBASE_CFG" ]]; then
  echo "Firebase CLI config not found at $FIREBASE_CFG."
  exit 1
fi

WHOAMI_OUT="$("${WRANGLER_BIN[@]}" whoami 2>&1 || true)"
if echo "$WHOAMI_OUT" | grep -qi "not authenticated"; then
  echo "Wrangler is not authenticated. Run:"
  echo "  npx --prefix cloudflare wrangler login --browser false"
  exit 2
fi

ACCESS_TOKEN="$(jq -r '.tokens.access_token // ""' "$FIREBASE_CFG")"
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Unable to read Firebase access token from $FIREBASE_CFG."
  exit 1
fi

RC_GET_URL="https://firebaseremoteconfig.googleapis.com/v1/projects/$PROJECT_ID/remoteConfig"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RC_FILE="$TMP_DIR/remoteconfig.json"
curl -sS \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/json" \
  "$RC_GET_URL" \
  -o "$RC_FILE"

ONESIGNAL_APP_ID="$(jq -r '.parameters.onesignal_app_id.defaultValue.value // ""' "$RC_FILE")"
ONESIGNAL_REST_KEY="$(jq -r '.parameters.onesignal_reset_api.defaultValue.value // ""' "$RC_FILE")"
ADMIN_WHATSAPP="$(jq -r '.parameters.admin_whatsapp.defaultValue.value // ""' "$RC_FILE")"

if [[ -z "$ONESIGNAL_APP_ID" || -z "$ONESIGNAL_REST_KEY" ]]; then
  echo "onesignal_app_id / onesignal_reset_api missing in Remote Config."
  exit 1
fi

WORKER_NAME="$(awk -F'=' '/^name[[:space:]]*=/{gsub(/[ "]/,"",$2); print $2; exit}' "$CF_DIR/wrangler.toml")"
if [[ -z "$WORKER_NAME" ]]; then
  echo "Cannot read Worker name from cloudflare/wrangler.toml."
  exit 1
fi

WORKER_TOKEN="$(openssl rand -hex 32)"

printf '%s' "$ONESIGNAL_APP_ID" | "${WRANGLER_BIN[@]}" secret put ONESIGNAL_APP_ID --config "$CF_DIR/wrangler.toml" --name "$WORKER_NAME" >/dev/null
printf '%s' "$ONESIGNAL_REST_KEY" | "${WRANGLER_BIN[@]}" secret put ONESIGNAL_REST_KEY --config "$CF_DIR/wrangler.toml" --name "$WORKER_NAME" >/dev/null
printf '%s' "$WORKER_TOKEN" | "${WRANGLER_BIN[@]}" secret put WORKER_TOKEN --config "$CF_DIR/wrangler.toml" --name "$WORKER_NAME" >/dev/null

DEPLOY_LOG="$TMP_DIR/deploy.log"
if ! "${WRANGLER_BIN[@]}" deploy --config "$CF_DIR/wrangler.toml" >"$DEPLOY_LOG" 2>&1; then
  cat "$DEPLOY_LOG"
  echo "Worker deploy failed."
  exit 1
fi

WORKER_URL="$(grep -Eo 'https://[A-Za-z0-9._-]+\.workers\.dev' "$DEPLOY_LOG" | head -n1 || true)"
if [[ -z "$WORKER_URL" ]]; then
  cat "$DEPLOY_LOG"
  echo "Could not detect workers.dev URL from deploy output."
  exit 1
fi

RC_NEW="$TMP_DIR/remoteconfig_new.json"
jq \
  --arg workerUrl "$WORKER_URL" \
  --arg workerToken "$WORKER_TOKEN" \
  --arg adminWhatsapp "$ADMIN_WHATSAPP" \
  '
  .parameters = (.parameters // {}) |
  .parameters.cloudflare_notify_enabled = (.parameters.cloudflare_notify_enabled // {}) |
  .parameters.cloudflare_notify_enabled.defaultValue = (.parameters.cloudflare_notify_enabled.defaultValue // {}) |
  .parameters.cloudflare_notify_enabled.defaultValue.value = "true" |
  .parameters.cloudflare_client_sender_enabled = (.parameters.cloudflare_client_sender_enabled // {}) |
  .parameters.cloudflare_client_sender_enabled.defaultValue = (.parameters.cloudflare_client_sender_enabled.defaultValue // {}) |
  .parameters.cloudflare_client_sender_enabled.defaultValue.value = "true" |
  .parameters.notification_mode = (.parameters.notification_mode // {}) |
  .parameters.notification_mode.defaultValue = (.parameters.notification_mode.defaultValue // {}) |
  .parameters.notification_mode.defaultValue.value = "onesignal" |
  .parameters.cloudflare_notify_url = (.parameters.cloudflare_notify_url // {}) |
  .parameters.cloudflare_notify_url.defaultValue = (.parameters.cloudflare_notify_url.defaultValue // {}) |
  .parameters.cloudflare_notify_url.defaultValue.value = $workerUrl |
  .parameters.cloudflare_notify_token = (.parameters.cloudflare_notify_token // {}) |
  .parameters.cloudflare_notify_token.defaultValue = (.parameters.cloudflare_notify_token.defaultValue // {}) |
  .parameters.cloudflare_notify_token.defaultValue.value = $workerToken |
  .parameters.cloudflare_admin_whatsapp = (.parameters.cloudflare_admin_whatsapp // {}) |
  .parameters.cloudflare_admin_whatsapp.defaultValue = (.parameters.cloudflare_admin_whatsapp.defaultValue // {}) |
  .parameters.cloudflare_admin_whatsapp.defaultValue.value = $adminWhatsapp
  ' \
  "$RC_FILE" >"$RC_NEW"

RC_PUT_RESP="$TMP_DIR/remoteconfig_put_response.json"
curl -sS -X PUT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json; UTF-8" \
  -H "If-Match: *" \
  --data-binary "@$RC_NEW" \
  "$RC_GET_URL" \
  -o "$RC_PUT_RESP"

NEW_VERSION="$(jq -r '.version.versionNumber // ""' "$RC_PUT_RESP")"

echo "Cloudflare notifications setup completed."
echo "Project: $PROJECT_ID"
echo "Worker: $WORKER_NAME"
echo "Worker URL: $WORKER_URL"
echo "Remote Config version: ${NEW_VERSION:-unknown}"
echo "Worker token (save safely): $WORKER_TOKEN"
