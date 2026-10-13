#!/usr/bin/env bash
# Export your existing GPG secret key to contexts/<context>/sops-pgp.asc so the runner VM
# can decrypt SOPS secrets (e.g. test-mailu) in CI. Use the same key that encrypts your
# secrets.enc.yaml files. Run from the project root (e.g. forest-shadows).
# Usage: export-sops-key.sh [context-name]. Default context: test-runner.
set -euo pipefail

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CONTEXT_NAME="${1:-${CONTEXT_NAME:-test-runner}}"
OUTPUT_DIR="${PROJECT_ROOT}/contexts/${CONTEXT_NAME}"
OUTPUT_FILE="${OUTPUT_DIR}/sops-pgp.asc"

if [ ! -d "${PROJECT_ROOT}/contexts" ]; then
  echo "❌ Project root has no contexts/ directory. Run this script from the project root (e.g. forest-shadows)."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Export your GPG key for runner (context: ${CONTEXT_NAME})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will export your existing GPG secret key to:"
echo "  ${OUTPUT_FILE}"
echo ""
echo "Use the same key that encrypts your context secrets (e.g. test-mailu secrets.enc.yaml)."
echo "That key will be copied to the runner VM at instantiate so CI can run windsor env --decrypt."
echo ""

# List secret keys: keyid and primary uid per key (gpg outputs sec then uid lines)
mapfile -t KEY_LIST < <(gpg --list-secret-keys --with-colons --keyid-format=long 2>/dev/null | \
  awk -F: '
    $1=="sec" { keyid=$5; gsub(/.*\//,"",keyid); next }
    $1=="uid" && keyid!="" { print keyid " " $10; keyid="" }
  ')

if [ ${#KEY_LIST[@]} -eq 0 ]; then
  echo "❌ No GPG secret keys found. Create a key first (e.g. gpg --full-generate-key) and use it to encrypt your context secrets (e.g. with sops)."
  exit 1
fi

echo "Your secret keys:"
n=1
for entry in "${KEY_LIST[@]}"; do
  keyid="${entry%% *}"
  uid="${entry#* }"
  echo "  $n) $keyid  $uid"
  ((n++)) || true
done
echo ""

read -p "Which key to export? (enter number, key ID, or email): " CHOICE
CHOICE="${CHOICE#"${CHOICE%%[![:space:]]*}"}"
CHOICE="${CHOICE%"${CHOICE##*[![:space:]]}"}"

KEY_ID=""
if [[ "${CHOICE}" =~ ^[0-9]+$ ]] && [ "${CHOICE}" -ge 1 ] && [ "${CHOICE}" -le ${#KEY_LIST[@]} ]; then
  KEY_ID="${KEY_LIST[$((CHOICE-1))]%% *}"
elif [ -n "${CHOICE}" ]; then
  # Resolve key ID or email to a key ID
  KEY_ID=$(gpg --list-secret-keys --with-colons --keyid-format=long "${CHOICE}" 2>/dev/null | \
    awk -F: '$1=="sec" {gsub(/.*\//,"",$5); print $5; exit}')
fi

if [ -z "${KEY_ID}" ]; then
  echo "❌ Could not resolve to a secret key. Use a number from the list, or a key ID, or an email."
  exit 1
fi

if [ -f "${OUTPUT_FILE}" ]; then
  read -p "File ${OUTPUT_FILE} already exists. Overwrite? [y/N]: " OVERWRITE
  if [ "${OVERWRITE}" != "y" ] && [ "${OVERWRITE}" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
  rm -f "${OUTPUT_FILE}"
fi

mkdir -p "${OUTPUT_DIR}"
gpg --armor --export-secret-keys "${KEY_ID}" > "${OUTPUT_FILE}" || {
  echo "❌ Export failed. If the key has a passphrase, you may be prompted for it."
  exit 1
}
chmod 600 "${OUTPUT_FILE}"

echo ""
echo "✅ Your GPG key has been exported to: ${OUTPUT_FILE}"
echo ""
echo "Next step: Run task test-runner:instantiate (or task vm:runner:instantiate with this context)"
echo "so the key is copied to the runner VM. CI will then be able to decrypt your context secrets."
echo ""
