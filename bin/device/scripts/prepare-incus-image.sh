#!/usr/bin/env bash
# Copy IncusOS image from Downloads (or specified path) to the devices folder
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  echo "Set the context using: windsor context set <context>"
  exit 1
fi
if [ -z "${INCUS_IMAGE_FILE:-}" ]; then
  echo "Error: INCUS_IMAGE_FILE variable is not defined"
  echo "Example: INCUS_IMAGE_FILE=~/Downloads/IncusOS_202512250102.img"
  exit 1
fi

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
DEVICES_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices"
INCUS_DIR="${DEVICES_DIR}/incus"
IMAGE_FILE="${INCUS_DIR}/incusos.img"

mkdir -p "${INCUS_DIR}"
if [ ! -f "${INCUS_IMAGE_FILE}" ]; then
  echo "Error: IncusOS image file not found at ${INCUS_IMAGE_FILE}"
  exit 1
fi

echo "Copying IncusOS image to devices folder..."
cp "${INCUS_IMAGE_FILE}" "${IMAGE_FILE}"
echo "IncusOS image copied to: ${IMAGE_FILE}"
