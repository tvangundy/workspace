#!/usr/bin/env bash
# Download the Talos image from the Image Factory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  echo "Set the context using: windsor context set <context>"
  exit 1
fi
if [ -z "${RPI_IMAGE_ARCH:-}" ]; then
  echo "Error: RPI_IMAGE_ARCH variable is not defined"
  echo "RPI_IMAGE_ARCH should be set in the task variables (e.g., metal-arm64, metal-amd64)"
  exit 1
fi
if [ -z "${RPI_IMAGE_SCHEMATIC_ID:-}" ]; then
  echo "Error: RPI_IMAGE_SCHEMATIC_ID variable is not defined"
  exit 1
fi
if [ -z "${RPI_IMAGE_VERSION:-}" ]; then
  echo "Error: RPI_IMAGE_VERSION variable is not defined"
  echo "RPI_IMAGE_VERSION should be set in the task variables (e.g., v1.11.5)"
  exit 1
fi

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
DEVICES_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices"
ARCH_DIR="${DEVICES_DIR}/${RPI_IMAGE_ARCH}"
IMAGE_FILE="${ARCH_DIR}/${RPI_IMAGE_ARCH}.raw"
IMAGE_XZ="${IMAGE_FILE}.xz"

mkdir -p "${ARCH_DIR}"
curl -L -o "${IMAGE_XZ}" "https://factory.talos.dev/image/${RPI_IMAGE_SCHEMATIC_ID}/${RPI_IMAGE_VERSION}/${RPI_IMAGE_ARCH}.raw.xz"
xz -d "${IMAGE_XZ}"
echo "Image downloaded to: ${IMAGE_FILE}"
