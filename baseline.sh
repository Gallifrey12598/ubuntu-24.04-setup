#!/usr/bin/env bash
# baseline.sh — Bootstrap baseline on Ubuntu
# Usage: curl -fsSL http://{SERVER_IP}/ubuntu/baseline.sh | sudo bash

set -Eeuo pipefail

### --- Config (This is where you will input your specified parameters) ---
BASE_URL="http://{SERVER_IP}/ubuntu"

# Remote script URLs
URL_TAILSCALE="${BASE_URL}/headscale/install-tailscale.sh"
URL_VMWARE="${BASE_URL}/vmware/install-vmware.sh"
URL_SSHKEY="${BASE_URL}/sshkey/install-sshkey.sh"

# Optional .env URLs (only loaded if reachable)
URL_HEADSCALE_ENV="${BASE_URL}/headscale/.env"
# Support either /sshkey/.env or legacy /ssh/.env (first one that responds 200)
URL_SSHKEY_ENV_CANDIDATES=("${BASE_URL}/sshkey/.env" "${BASE_URL}/ssh/.env")

LOG_FILE="/var/log/baseline.log"
MARKER_FILE="/etc/baseline_last_run"
TMP_DIR="$(mktemp -d /tmp/baseline.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

### --- Helpers ---
need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "[-] Please run as root (use: curl ... | sudo bash)"; exit 1
  fi
}

log_setup() {
  mkdir -p "$(dirname "$LOG_FILE")"
  # tee all stdout/stderr to the log
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "=== Baseline started at $(date -Is) ==="
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[-] Required command '$1' not found."; exit 1; }
}

http_ok() {
  # Returns 0 if URL returns HTTP 200
  local url="$1"
  local code
  code="$(curl -fsSLI -o /dev/null -w '%{http_code}' --retry 3 --retry-delay 2 "$url" || true)"
  [[ "$code" == "200" ]]
}

load_env_if_available() {
  local url="$1"
  local name="$2" # label for logging
  if http_ok "$url"; then
    echo "[*] Loading ${name} env from: $url"
    local f="$TMP_DIR/${name}.env"
    curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$f"
    # Export all variables defined in the .env
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  else
    echo "[*] No ${name} .env found at $url (skipping)"
  fi
}

fetch_and_run() {
  local url="$1"
  local label="$2"
  echo "[*] Running: ${label} (${url})"
  local f="$TMP_DIR/$(basename "$label").sh"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$f"
  chmod +x "$f"
  bash "$f"
  echo "[+] Completed: ${label}"
}

### --- Pre-flight ---
need_root
log_setup
require_cmd curl
require_cmd bash

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "[*] Detected: $PRETTY_NAME"
  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "[-] This baseline is intended for Ubuntu. Detected ID='$ID'." ; exit 1
  fi
fi

### --- Load optional envs ---
# Headscale/Tailscale .env (if hosted)
load_env_if_available "$URL_HEADSCALE_ENV" "headscale"

# SSH key .env (try candidates)
for cand in "${URL_SSHKEY_ENV_CANDIDATES[@]}"; do
  if http_ok "$cand"; then
    load_env_if_available "$cand" "sshkey"
    break
  fi
done

### --- Execute baseline components ---
# 1) Tailscale / Headscale enrollment
fetch_and_run "$URL_TAILSCALE" "install-tailscale"

# 2) VMware (DKMS/MOK flow handled inside its own script)
fetch_and_run "$URL_VMWARE" "install-vmware"

# 3) Ensure SSH key baseline (authorized_keys management handled in its script)
fetch_and_run "$URL_SSHKEY" "install-sshkey"

### --- Done ---
date -Is > "$MARKER_FILE"
echo "[✓] Baseline completed at $(cat "$MARKER_FILE")"
echo "    Log: $LOG_FILE"
