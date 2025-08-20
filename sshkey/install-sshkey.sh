#!/usr/bin/env bash
# install-sshkey.sh
set -euo pipefail

ENV_URL="URL to .env"
USER_NAME="USER_NAME"
HOME_DIR="/home/${USER_NAME}"
SSH_DIR="${HOME_DIR}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

log() { printf '[ssh-key-setup] %s\n' "$*"; }

# --- Fetch SSH_KEY from .env ---
log "Fetching SSH_KEY from ${ENV_URL} ..."
if ! ENV_CONTENT="$(curl -fsSL --retry 3 --connect-timeout 5 "$ENV_URL")"; then
  log "ERROR: Unable to download .env from ${ENV_URL}"
  exit 1
fi

# Extract SSH_KEY=... line
SSH_KEY="$(printf '%s\n' "$ENV_CONTENT" \
  | sed -n 's/^[[:space:]]*SSH_KEY[[:space:]]*=[[:space:]]*//p' \
  | head -n1)"

# Strip quotes if present
SSH_KEY="${SSH_KEY%\"}"; SSH_KEY="${SSH_KEY#\"}"
SSH_KEY="${SSH_KEY%\'}"; SSH_KEY="${SSH_KEY#\'}"

# Normalize
SSH_KEY="$(printf '%s' "$SSH_KEY" | tr -d '\r' | sed -E 's/[[:space:]]+$//')"

if [[ -z "${SSH_KEY}" ]]; then
  log "ERROR: SSH_KEY is empty or not set in .env"
  exit 1
fi

# --- Prepare .ssh directory and permissions ---
if [[ ! -d "${SSH_DIR}" ]]; then
  log "Creating ${SSH_DIR} ..."
  mkdir -p "${SSH_DIR}"
fi
chown -R "${USER_NAME}:${USER_NAME}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# --- Ensure SSH_KEY is present in authorized_keys ---
if [[ -f "${AUTH_KEYS}" ]]; then
  if grep -qxF "${SSH_KEY}" "${AUTH_KEYS}"; then
    log "authorized_keys already contains SSH_KEY. No changes needed."
  else
    log "Appending SSH_KEY to authorized_keys ..."
    printf '\n%s\n' "${SSH_KEY}" >> "${AUTH_KEYS}"
  fi
else
  log "Creating authorized_keys with SSH_KEY ..."
  printf '%s\n' "${SSH_KEY}" > "${AUTH_KEYS}"
fi

# Set perms
chmod 600 "${AUTH_KEYS}"
chown "${USER_NAME}:${USER_NAME}" "${AUTH_KEYS}"

log "Done. ${AUTH_KEYS} contains SSH_KEY."
