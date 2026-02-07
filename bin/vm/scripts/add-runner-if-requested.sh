#!/usr/bin/env bash
# If VM_ADD_RUNNER was set (--runner flag on vm:instantiate), write runner env and run runner setup.
set -euo pipefail

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
VM_ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
RUNNER_ENV_FILE="${PROJECT_ROOT}/.workspace/.runner-instantiate.env"

if [ ! -f "${VM_ENV_FILE}" ]; then
  echo "Error: ${VM_ENV_FILE} not found"
  exit 1
fi
source "${VM_ENV_FILE}"

if [ "${VM_ADD_RUNNER:-false}" != "true" ]; then
  exit 0
fi

# Write .runner-instantiate.env so runner scripts see the same VM and remote
VM_INSTANCE_NAME="${VM_NAME:-${VM_INSTANCE_NAME:-runner}}"
mkdir -p "${PROJECT_ROOT}/.workspace"
{
  echo "export TEST_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export INCUS_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export INCUS_REMOTE_IP='${INCUS_REMOTE_IP}'"
  echo "export INCUS_REMOTE_FROM_CLI='${TEST_REMOTE_NAME}'"
  echo "export VM_NAME='${VM_INSTANCE_NAME}'"
  echo "export VM_INSTANCE_NAME='${VM_INSTANCE_NAME}'"
  echo "export VM_DESTROY='false'"
  echo "export SKIP_CLEANUP='true'"
} > "${RUNNER_ENV_FILE}"

RUNNER_SCRIPTS="${PROJECT_ROOT}/bin/vm/scripts/runner"
"${RUNNER_SCRIPTS}/setup-runner-user.sh"
"${RUNNER_SCRIPTS}/install-github-runner.sh"
