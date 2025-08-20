#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash -c 'tr -d "\r" | bash' <<<"$(cat)"
fi
set -Eeuo pipefail 2>/dev/null || set -Eeuo

# ===================== CONFIG =====================
# <<< EDIT THIS BEFORE HOSTING >>>
FIXED_MOK_PASSWORD="PLAIN-TEXT-PASSWORD"

BUNDLE_URL="URL-Where-VMWARE.bundle File Resides"
BUNDLE_NAME="$(basename "$BUNDLE_URL")"
WORKDIR="/tmp/vmware-install.$$"
MOKDIR="/root/vmware-mok"
SUBJECT_CN="/CN=VMware/"
DAYS_VALID=36500
# ==================================================

log(){ printf "\n[vmware-install] %s\n" "$*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

need_root(){
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then die "Run as root (e.g., curl … | sudo -E bash)"; fi
}

detect_secure_boot(){
  command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"
}

ensure_prereqs(){
  log "Installing prerequisites…"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc-12 libgcc-12-dev build-essential linux-headers-$(uname -r) \
    curl ca-certificates openssl mokutil
}

fetch_bundle(){
  mkdir -p "$WORKDIR"
  log "Downloading VMware bundle to $WORKDIR/$BUNDLE_NAME"
  curl -fsSL "$BUNDLE_URL" -o "$WORKDIR/$BUNDLE_NAME"
  chmod +x "$WORKDIR/$BUNDLE_NAME"
}

install_vmware(){
  log "Running VMware installer (non-interactive)…"
  bash "$WORKDIR/$BUNDLE_NAME" --console --required --eulas-agreed
}

build_modules(){
  log "Building VMware kernel modules…"
  command -v vmware-modconfig >/dev/null 2>&1 || die "vmware-modconfig not found. Install may have failed."
  vmware-modconfig --console --install-all || true
}

reload_modules(){
  log "Reloading VMware modules…"
  modprobe -r vmnet vmmon 2>/dev/null || true
  modprobe vmmon || true
  modprobe vmnet || true
}

create_and_import_mok(){
  mkdir -p "$MOKDIR"
  if [[ ! -f "$MOKDIR/MOK.priv" || ! -f "$MOKDIR/MOK.der" ]]; then
    log "Generating MOK keypair for module signing…"
    openssl req -new -x509 -newkey rsa:2048 \
      -keyout "$MOKDIR/MOK.priv" -outform DER -out "$MOKDIR/MOK.der" \
      -nodes -days "$DAYS_VALID" -subj "$SUBJECT_CN"
    chmod 600 "$MOKDIR/MOK.priv"
  else
    log "Reusing existing MOK keypair at $MOKDIR"
  fi

  # Save plaintext so user knows what to enter at reboot
  umask 177
  printf "%s" "$FIXED_MOK_PASSWORD" > "$MOKDIR/mok_password.txt"
  chmod 600 "$MOKDIR/mok_password.txt"

  log "Importing MOK certificate (enrollment will happen on next reboot)…"
  # mokutil prompts twice; feed both lines so it works in non-tty mode
  printf "%s\n%s\n" "$FIXED_MOK_PASSWORD" "$FIXED_MOK_PASSWORD" | mokutil --import "$MOKDIR/MOK.der"
  log "MOK import scheduled."
}

sign_modules(){
  local sign_file="/usr/src/linux-headers-$(uname -r)/scripts/sign-file"
  [[ -x "$sign_file" ]] || die "Kernel sign-file script not found at $sign_file"

  local vmmon_path vmnet_path
  vmmon_path="$(modinfo -n vmmon 2>/dev/null || true)"
  vmnet_path="$(modinfo -n vmnet 2>/dev/null || true)"
  [[ -n "$vmmon_path" && -f "$vmmon_path" ]] || die "vmmon module not found to sign."
  [[ -n "$vmnet_path" && -f "$vmnet_path" ]] || die "vmnet module not found to sign."

  log "Signing vmmon: $vmmon_path"
  "$sign_file" sha256 "$MOKDIR/MOK.priv" "$MOKDIR/MOK.der" "$vmmon_path"
  log "Signing vmnet: $vmnet_path"
  "$sign_file" sha256 "$MOKDIR/MOK.priv" "$MOKDIR/MOK.der" "$vmnet_path"
}

maybe_create_postreboot_unit(){
  local unit="/etc/systemd/system/vmware-post-mok.service"
  log "Creating a one-time post-reboot service to finalize module load…"
  cat > "$unit" <<'EOF'
[Unit]
Description=Finalize VMware modules after MOK enrollment
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vmware-finalize.sh

[Install]
WantedBy=multi-user.target
EOF

  mkdir -p /usr/local/sbin
  cat > /usr/local/sbin/vmware-finalize.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail 2>/dev/null || set -Eeuo
log(){ printf "[vmware-finalize] %s\n" "$*"; }
sign_file="/usr/src/linux-headers-$(uname -r)/scripts/sign-file"
MOKDIR="/root/vmware-mok"

[[ -x "$sign_file" && -f "$MOKDIR/MOK.priv" && -f "$MOKDIR/MOK.der" ]] || exit 0

if command -v modinfo >/dev/null 2>&1; then
  vmmon="$(modinfo -n vmmon 2>/dev/null || true)"
  vmnet="$(modinfo -n vmnet 2>/dev/null || true)"
  [[ -n "$vmmon" && -f "$vmmon" ]] && "$sign_file" sha256 "$MOKDIR/MOK.priv" "$MOKDIR/MOK.der" "$vmmon" || true
  [[ -n "$vmnet" && -f "$vmnet" ]] && "$sign_file" sha256 "$MOKDIR/MOK.priv" "$MOKDIR/MOK.der" "$vmnet" || true
fi

modprobe -r vmnet vmmon 2>/dev/null || true
modprobe vmmon || true
modprobe vmnet || true

systemctl disable vmware-post-mok.service >/dev/null 2>&1 || true
log "Completed."
EOF
  chmod +x /usr/local/sbin/vmware-finalize.sh
  systemctl daemon-reload
  systemctl enable vmware-post-mok.service >/dev/null 2>&1 || true
}

main(){
  need_root
  ensure_prereqs
  fetch_bundle
  install_vmware
  build_modules
  reload_modules

  if detect_secure_boot; then
    log "Secure Boot is ENABLED — preparing MOK enrollment and signing…"
    create_and_import_mok
    sign_modules || true
    maybe_create_postreboot_unit

    echo
    echo "===================================================================="
    echo " Secure Boot: MOK enrollment scheduled."
    echo " 1) REBOOT the machine."
    echo " 2) In the blue 'MOK Manager', choose: Enroll MOK → Continue → Yes"
    echo " 3) Enter the password shown below (also saved to $MOKDIR/mok_password.txt)."
    echo "    PASSWORD: $FIXED_MOK_PASSWORD"
    echo " 4) After reboot, modules will be finalized automatically."
    echo "    (Manual helper: /usr/local/sbin/vmware-finalize.sh)"
    echo "===================================================================="
  else
    log "Secure Boot appears DISABLED; modules should already be loaded."
  fi

  log "Module status:"
  lsmod | grep -E 'vmmon|vmnet' || true

  echo
  echo "=========== IMPORTANT (SAVE THIS) ==========="
  if detect_secure_boot; then
    echo "MOK PASSWORD: $FIXED_MOK_PASSWORD"
    echo "Stored at: $MOKDIR/mok_password.txt (root-only)"
  else
    echo "Secure Boot disabled — MOK password not required."
  fi
  echo "============================================="
  log "Done. Launch VMware with 'vmware'."
}

main
