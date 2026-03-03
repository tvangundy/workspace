#!/usr/bin/env bash
# If VM_ADD_MAILU_USER or VM_ADD_VPN_USER was set (--mailu / --vpn flag on vm:instantiate), run service user setup.
# Uses same env as add-runner-if-requested: .vm-instantiate.env.
set -euo pipefail

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
VM_ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"

if [ ! -f "${VM_ENV_FILE}" ]; then
  echo "Error: ${VM_ENV_FILE} not found"
  exit 1
fi
source "${VM_ENV_FILE}"

if [ "${VM_ADD_MAILU_USER:-false}" != "true" ] && [ "${VM_ADD_VPN_USER:-false}" != "true" ]; then
  exit 0
fi

SCRIPT_DIR="${BIN_ROOT:-${PROJECT_ROOT}/bin}/vm/scripts"
"${SCRIPT_DIR}/setup-service-user.sh"
