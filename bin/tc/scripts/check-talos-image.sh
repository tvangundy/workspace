#!/usr/bin/env bash
# Ensure Talos image is available on remote; fetch from Image Factory if missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Vanilla schematic ID (empty customization) - from Talos Image Factory docs
TALOS_VANILLA_SCHEMATIC_ID="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"

# Load TC environment
load_tc_env

log_step "Verifying Talos image availability"

TALOS_IMAGE_VERSION="${TALOS_IMAGE_VERSION:-v1.12.0}"
TALOS_IMAGE_ARCH="${TALOS_IMAGE_ARCH:-metal-amd64}"
TALOS_IMAGE_ALIAS="talos-${TALOS_IMAGE_VERSION}-${TALOS_IMAGE_ARCH}"
SCHEMATIC_ID="${TALOS_IMAGE_SCHEMATIC_ID:-${TALOS_VANILLA_SCHEMATIC_ID}}"

if incus image alias list "${TEST_REMOTE_NAME}:" --format csv 2>/dev/null | grep -q "^${TALOS_IMAGE_ALIAS},"; then
  echo "✅ Talos image '${TALOS_IMAGE_ALIAS}' exists on remote '${TEST_REMOTE_NAME}'"
  exit 0
fi

echo "Talos image '${TALOS_IMAGE_ALIAS}' not found on remote '${TEST_REMOTE_NAME}'; attempting to fetch..."

# Image Factory uses metal-amd64.raw.zst format
IMAGE_URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_IMAGE_VERSION}/metal-amd64.raw.zst"

TMP_DIR="$HOME/tmp-talos-$$"
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

IMAGE_ZST="${TMP_DIR}/metal-amd64.raw.zst"
IMAGE_RAW="${TMP_DIR}/metal-amd64.raw"
IMAGE_QCOW2="${TMP_DIR}/talos-metal-amd64.qcow2"

for cmd in curl zstd qemu-img; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "⚠️  Cannot fetch: ${cmd} is not installed (macOS: brew install zstd qemu  # or equivalent)"
    echo "   Continuing; image may be pulled during cluster creation."
    exit 0
  fi
done

echo "Downloading from Image Factory..."
if ! curl -fsSL -o "${IMAGE_ZST}" "${IMAGE_URL}"; then
  echo "⚠️  Failed to download Talos image from ${IMAGE_URL}"
  echo "   Continuing; image may be pulled during cluster creation."
  exit 0
fi

echo "Extracting and converting to QCOW2..."
zstd -d -q -f "${IMAGE_ZST}" -o "${IMAGE_RAW}" || {
  echo "⚠️  Failed to extract Talos image"
  exit 0
}
qemu-img convert -f raw -O qcow2 "${IMAGE_RAW}" "${IMAGE_QCOW2}" || {
  echo "⚠️  Failed to convert Talos image to QCOW2"
  exit 0
}

# Create minimal metadata for VM image (required for incus import)
METADATA_FILE="${TMP_DIR}/metadata.yaml"
CREATION_DATE=$(date +%s)
printf "architecture: x86_64\ncreation_date: %s\nproperties:\n  description: Talos Linux %s for VMs\n  os: Talos\n  release: %s\n" \
  "${CREATION_DATE}" "${TALOS_IMAGE_VERSION}" "${TALOS_IMAGE_VERSION}" > "${METADATA_FILE}"
METADATA_TAR="${TMP_DIR}/metadata.tar.gz"
tar -czf "${METADATA_TAR}" -C "${TMP_DIR}" metadata.yaml

echo "Importing to remote '${TEST_REMOTE_NAME}'..."
if incus image import "${METADATA_TAR}" "${IMAGE_QCOW2}" "${TEST_REMOTE_NAME}:" --alias "${TALOS_IMAGE_ALIAS}"; then
  echo "✅ Talos image '${TALOS_IMAGE_ALIAS}' fetched and imported successfully"
else
  echo "⚠️  Failed to import image; continuing. Image may be pulled during cluster creation."
fi

