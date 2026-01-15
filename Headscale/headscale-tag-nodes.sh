#!/usr/bin/env bash
set -euo pipefail

# headscale-tag-nodes.sh
# Interactive script to apply one or more Headscale tags to one or more node IDs.

die() {
  echo "ERROR: $*" >&2
  exit 1
}

trim() {
  # Trim leading/trailing whitespace from a string
  local s="$1"
  # shellcheck disable=SC2001
  s="$(echo "$s" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  echo "$s"
}

split_csv() {
  # Split a comma-delimited string into lines, trimming whitespace, dropping empties
  # Usage: split_csv "a, b, c"
  local input="$1"
  echo "$input" \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sed '/^$/d'
}

confirm() {
  local prompt="${1:-Proceed? [y/N]: }"
  read -r -p "$prompt" ans
  ans="$(echo "${ans:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

command -v headscale >/dev/null 2>&1 || die "headscale command not found in PATH."

echo
echo "Available Headscale nodes:"
echo "------------------------------------------------------------"
sudo headscale nodes list --tags
echo "------------------------------------------------------------"
echo

read -r -p "Enter node ID(s) to tag (comma-delimited, e.g., 1,2,5): " IDS_RAW
IDS_RAW="$(trim "${IDS_RAW:-}")"
[[ -n "$IDS_RAW" ]] || die "No node IDs provided."

# Parse and validate IDs (must be numeric)
mapfile -t NODE_IDS < <(split_csv "$IDS_RAW")
[[ "${#NODE_IDS[@]}" -gt 0 ]] || die "No valid node IDs parsed."

for id in "${NODE_IDS[@]}"; do
  [[ "$id" =~ ^[0-9]+$ ]] || die "Invalid node ID '$id' (must be numeric)."
done

read -r -p "Enter tag(s) to apply (comma-delimited, e.g., prod,web,linux): " TAGS_RAW
TAGS_RAW="$(trim "${TAGS_RAW:-}")"
[[ -n "$TAGS_RAW" ]] || die "No tags provided."

mapfile -t TAGS < <(split_csv "$TAGS_RAW")
[[ "${#TAGS[@]}" -gt 0 ]] || die "No valid tags parsed."

# Validate tags (no spaces, no empty; allow letters/numbers/_/./- to be safe)
# Headscale tags typically look like "tag:foo". We'll accept "foo" and prefix tag:.
for t in "${TAGS[@]}"; do
  [[ -n "$t" ]] || die "Empty tag detected."
  [[ "$t" =~ ^[A-Za-z0-9_.-]+$ ]] || die "Invalid tag '$t'. Allowed: letters, numbers, underscore, dot, dash."
done

echo
echo "Summary:"
echo "  Node IDs: ${NODE_IDS[*]}"
echo "  Tags:     ${TAGS[*]}"
echo

if ! confirm "Apply these tags to the selected node(s)? [y/N]: "; then
  echo "Aborted."
  exit 0
fi

echo
echo "Applying tags..."
for id in "${NODE_IDS[@]}"; do
  # Build args: --tags tag:<tag> repeated
  tag_args=()
  for t in "${TAGS[@]}"; do
    tag_args+=( "--tags" "tag:${t}" )
  done

  echo
  echo "Node ID: $id"
  echo "Running: sudo headscale nodes tags -i ${id} ${tag_args[*]}"
  sudo headscale nodes tags -i "$id" "${tag_args[@]}"
done

echo
echo "Done."
