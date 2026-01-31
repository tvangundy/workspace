#!/usr/bin/env bash
# Copy BIOS update files to the devices folder
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  echo "Set the context using: windsor context set <context>"
  exit 1
fi
if [ -z "${BIOS_FOLDER:-}" ]; then
  echo "Error: BIOS_FOLDER variable is not defined"
  echo "Example: BIOS_FOLDER=~/Downloads/NUC8i5BEHAS003"
  echo "The folder should contain the .bio file and IFLASH2.exe (for ASUS NUC)"
  exit 1
fi

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
DEVICES_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices"
BIOS_DIR="${DEVICES_DIR}/bios"

mkdir -p "${BIOS_DIR}"
if [ ! -d "${BIOS_FOLDER}" ]; then
  echo "Error: BIOS folder not found at ${BIOS_FOLDER}"
  exit 1
fi

echo "Copying BIOS update files to devices folder..."
cp -r "${BIOS_FOLDER}"/* "${BIOS_DIR}/"
echo "BIOS files copied to: ${BIOS_DIR}"
