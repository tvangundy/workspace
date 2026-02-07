#!/usr/bin/env bash
# Remove GitHub Actions runner from the repository (if installed on the VM). Called by vm:destroy before destroying the VM.
# Usage: REMOTE=<incus-remote> VM_NAME=<vm-name> (or VM_INSTANCE_NAME=) unregister-from-github.sh
#   or: unregister-from-github.sh <remote> <vm-instance-name>
set -euo pipefail

if [ $# -ge 2 ]; then
  TEST_REMOTE_NAME="${1}"
  VM_INSTANCE_NAME="${2}"
else
  TEST_REMOTE_NAME="${REMOTE:-${TEST_REMOTE_NAME:-}}"
  VM_INSTANCE_NAME="${VM_INSTANCE_NAME:-${VM_NAME:-}}"
fi

if [ -z "${TEST_REMOTE_NAME}" ] || [ -z "${VM_INSTANCE_NAME}" ]; then
  exit 0
fi

# Save target VM/remote before loading Windsor env (which overwrites VM_INSTANCE_NAME/INCUS_REMOTE_NAME with active context)
TARGET_REMOTE="${TEST_REMOTE_NAME}"
TARGET_VM="${VM_INSTANCE_NAME}"

RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_HOME="${RUNNER_HOME:-/home/${RUNNER_USER}}"

# Load token from .runner-instantiate.env or Windsor if available
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.workspace/.runner-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  set +e
  source "${ENV_FILE}" 2>/dev/null || true
  set -e
fi
if command -v windsor > /dev/null 2>&1; then
  set +e
  eval "$(windsor env --decrypt 2>/dev/null)" || true
  set -e
fi

# Check if VM exists and has runner installed (use TARGET_* to avoid Windsor env overwriting with active context)
if ! incus list "${TARGET_REMOTE}:${TARGET_VM}" --format csv -c n 2>/dev/null | grep -q "^${TARGET_VM}$"; then
  exit 0
fi

RUNNER_INSTALLED=false
if incus exec "${TARGET_REMOTE}:${TARGET_VM}" -- test -f "${RUNNER_HOME}/actions-runner/svc.sh" 2>/dev/null; then
  RUNNER_INSTALLED=true
fi

if [ "${RUNNER_INSTALLED}" != "true" ]; then
  exit 0
fi

echo "  Removing runner from GitHub repository..."
TOKEN="${GITHUB_RUNNER_TOKEN:-}"
if [ -z "${TOKEN}" ]; then
  echo "  ⚠️  GITHUB_RUNNER_TOKEN not set; runner may remain in GitHub Settings → Actions → Runners"
else
  set +e
  incus exec "${TARGET_REMOTE}:${TARGET_VM}" -- bash -c "
    cd ${RUNNER_HOME}/actions-runner 2>/dev/null || exit 0
    if [ -f ./svc.sh ]; then sudo ./svc.sh stop 2>/dev/null || true; sudo ./svc.sh uninstall 2>/dev/null || true; fi
    if [ -f ./config.sh ]; then sudo -u ${RUNNER_USER} ./config.sh remove --token '${TOKEN}' 2>&1; fi
  "
  set -e
  echo "  ✅ Runner unregistered from GitHub"
fi
