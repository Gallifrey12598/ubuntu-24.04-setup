#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail

# --- Config ---
: "${ENV_URL:=http://10.0.0.6/ubuntu/headscale/.env}"   # can be overridden: ENV_URL=... curl ... | sudo -E bash

# Only allow these keys from the .env
ALLOWED_KEYS=(
  HEADSCALE_URL
  AUTH_KEY
  HOSTNAME
  ADVERTISE_ROUTES
  ADVERTISE_TAGS
  USE_EXIT_NODE
  SHIELDS_UP
  ACCEPT_ROUTES
)

log() { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[!]\033[0m %s\n" "$*" >&2; }
need_root() { [ "$(id -u)" -eq 0 ] || { err "Run as root (use sudo)."; exit 1; }; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }

need_root
need_cmd curl

# --- Fetch & load ENV (safely) ---
TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT

log "Fetching env from: $ENV_URL"
# Fetch and strip CRLF, keep as LF
curl -fsSL "$ENV_URL" | tr -d '\r' > "$TMP_ENV"

# Parse: keep only ALLOWED_KEYS=... lines, strip comments and surrounding quotes
sanitize_and_export_env() {
  local key rx
  # Remove comments and blank lines
  sed -i -e 's/^[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$TMP_ENV"

  # For each allowed key, extract last assignment if multiple present
  for key in "${ALLOWED_KEYS[@]}"; do
    # match lines like KEY=value or KEY="value"
    rx="^[[:space:]]*${key}[[:space:]]*="
    if grep -Eq "$rx" "$TMP_ENV"; then
      # Take the last occurrence
      local line
      line="$(grep -E "$rx" "$TMP_ENV" | tail -n1)"
      # Split once on '='
      local val="${line#*=}"
      # Trim whitespace
      val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      # Strip optional surrounding single or double quotes
      val="$(printf '%s' "$val" | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')"
      export "$key=$val"
    fi
  done
}

sanitize_and_export_env

# Validate required vars
: "${HEADSCALE_URL:?HEADSCALE_URL is required in the .env}"
: "${AUTH_KEY:?AUTH_KEY is required in the .env}"

# Optional booleans default
: "${USE_EXIT_NODE:=false}"
: "${SHIELDS_UP:=false}"
: "${ACCEPT_ROUTES:=false}"

# --- Determine device name ---
need_cmd awk
get_serial() {
  if command -v dmidecode >/dev/null 2>&1; then
    local s
    s="$(dmidecode -s system-serial-number 2>/dev/null | awk 'NF{print; exit}')"
    if [ -n "$s" ] && [[ ! "$s" =~ ^(Unknown|To[[:space:]]Be[[:space:]]Filled|Default|string|System)$ ]]; then
      echo "$s"; return
    fi
  fi
  if [ -r /sys/class/dmi/id/product_uuid ]; then
    tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/product_uuid | tr -cd '[:alnum:]-' || true
    return
  fi
  hostname -s
}

DEVICE_NAME="${HOSTNAME:-$(get_serial)}"
DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"

log "Using device name: $DEVICE_NAME"
log "Headscale URL: $HEADSCALE_URL"

# --- Install Tailscale (Ubuntu) ---
if ! [ -f /etc/os-release ]; then
  err "This script supports Ubuntu only."; exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
CODENAME="${VERSION_CODENAME:-}"
if [ -z "$CODENAME" ]; then
  # crude fallback based on VERSION_ID
  case "${VERSION_ID:-}" in
    24.04) CODENAME="noble" ;;
    22.04) CODENAME="jammy" ;;
    20.04) CODENAME="focal" ;;
    18.04) CODENAME="bionic" ;;
    *) CODENAME="jammy" ;;
  esac
fi

if ! command -v tailscale >/dev/null 2>&1; then
  log "Installing Tailscale package and repo for $CODENAME..."
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.noarmor.gpg" \
    | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.tailscale-keyring.list" \
    | tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
else
  log "Tailscale already installed."
fi

# --- Enable service ---
systemctl enable --now tailscaled
sleep 1

# --- Build tailscale up args ---
UP_FLAGS=(--login-server="${HEADSCALE_URL}" --hostname="${DEVICE_NAME}")

if [ -n "${ADVERTISE_ROUTES:-}" ]; then
  UP_FLAGS+=(--advertise-routes="${ADVERTISE_ROUTES}")
fi
if [ -n "${ADVERTISE_TAGS:-}" ]; then
  UP_FLAGS+=(--advertise-tags="${ADVERTISE_TAGS}")
fi
if [[ "${USE_EXIT_NODE}" == "true" ]]; then
  UP_FLAGS+=(--exit-node-allow-lan-access)
fi
if [[ "${SHIELDS_UP}" == "true" ]]; then
  UP_FLAGS+=(--shields-up)
fi
if [[ "${ACCEPT_ROUTES}" == "true" ]]; then
  UP_FLAGS+=(--accept-routes)
fi

already_up() {
  tailscale status --json >/dev/null 2>&1
}

# --- Authenticate / Configure ---
if already_up; then
  log "Tailscale appears to be up. Re-applying configuration (no key)..."
  tailscale up "${UP_FLAGS[@]}" || true
else
  log "Bringing Tailscale up with pre-auth key..."
  tailscale up "${UP_FLAGS[@]}" --auth-key="${AUTH_KEY}"
fi

# --- Verify ---
if tailscale ip -4 >/dev/null 2>&1; then
  TS_IP4="$(tailscale ip -4 | head -n1 || true)"
  TS_IP6="$(tailscale ip -6 | head -n1 || true)"
  log "Tailscale is up. IPv4: ${TS_IP4:-none}  IPv6: ${TS_IP6:-none}"
else
  err "Tailscale failed to start. See: journalctl -u tailscaled --no-pager"
  exit 1
fi

# --- Cleanup secrets ---
unset AUTH_KEY
rm -f "$TMP_ENV"
trap - EXIT

log "Done."
