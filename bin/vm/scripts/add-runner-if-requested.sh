#!/usr/bin/env bash
# If VM_ADD_RUNNER was set (--runner flag on vm:instantiate), run runner setup.
# Runner scripts use windsor env + .vm-instantiate.env (no .runner-instantiate.env).
set -euo pipefail

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
VM_ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"

if [ ! -f "${VM_ENV_FILE}" ]; then
  echo "Error: ${VM_ENV_FILE} not found"
  exit 1
fi
source "${VM_ENV_FILE}"

if [ "${VM_ADD_RUNNER:-false}" != "true" ]; then
  exit 0
fi

# Runner scripts load windsor env (--decrypt) and .vm-instantiate.env via load_runner_env
RUNNER_SCRIPTS="${BIN_ROOT:-${PROJECT_ROOT}/bin}/vm/scripts/runner"
"${RUNNER_SCRIPTS}/setup-runner-user.sh"
"${RUNNER_SCRIPTS}/install-github-runner.sh"
