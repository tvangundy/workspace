#!/usr/bin/env bash
# Ensure Talos image is available on remote (warn only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

log_step "Verifying Talos image availability"

TALOS_IMAGE_VERSION="${TALOS_IMAGE_VERSION:-v1.12.0}"
TALOS_IMAGE_ARCH="${TALOS_IMAGE_ARCH:-metal-amd64}"
TALOS_IMAGE_ALIAS="talos-${TALOS_IMAGE_VERSION}-${TALOS_IMAGE_ARCH}"

if incus image alias list "${TEST_REMOTE_NAME}:" --format csv 2>/dev/null | grep -q "^${TALOS_IMAGE_ALIAS},"; then
  echo "✅ Talos image '${TALOS_IMAGE_ALIAS}' exists on remote '${TEST_REMOTE_NAME}'"
else
  echo "⚠️  Talos image '${TALOS_IMAGE_ALIAS}' not found on remote '${TEST_REMOTE_NAME}'"
  echo "   Continuing; image may be pulled during cluster creation."
fi

