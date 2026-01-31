#!/usr/bin/env bash
# Download or move Ubuntu image to the devices folder
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  echo "Set the context using: windsor context set <context>"
  exit 1
fi
if [ -z "${UBUNTU_IMG_FILE:-}" ]; then
  echo "Error: UBUNTU_IMG_FILE variable is not defined"
  echo "Example: UBUNTU_IMG_FILE=~/Downloads/ubuntu-24.04-desktop-amd64.iso"
  exit 1
fi

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
DEVICES_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices"
UBUNTU_DIR="${DEVICES_DIR}/ubuntu-img"
IMG_FILE="${UBUNTU_DIR}/ubuntu.img"

mkdir -p "${UBUNTU_DIR}"
if [ ! -f "${UBUNTU_IMG_FILE}" ]; then
  echo "Error: Ubuntu image file not found at ${UBUNTU_IMG_FILE}"
  exit 1
fi

echo "Copying Ubuntu image to devices folder..."
cp "${UBUNTU_IMG_FILE}" "${IMG_FILE}"
echo "Ubuntu image copied to: ${IMG_FILE}"
