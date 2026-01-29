#!/usr/bin/env bash
# Parse CLI arguments for runner:instantiate task
set -euo pipefail

CLI_ARGS_STR="${1:-}"

if [ -z "${CLI_ARGS_STR}" ]; then
  echo "Error: INCUS_REMOTE_NAME is required"
  echo "Usage: task runner:instantiate -- <incus-remote-name> [<runner-name>] [--keep]"
  echo ""
  echo "Arguments:"
  echo "  <incus-remote-name>    Required: Name of the Incus remote"
  echo "  <runner-name>          Optional: Name for the runner VM (default: 'runner')"
  echo ""
  echo "Options:"
  echo "  --keep, --no-cleanup    Keep VM running (default: delete VM)"
  echo ""
  echo "Examples:"
  echo "  task runner:instantiate -- nuc"
  echo "  task runner:instantiate -- nuc my-runner"
  echo "  task runner:instantiate -- nuc my-runner --keep"
  exit 1
fi

# Initialize flags
SKIP_CLEANUP=false
RUNNER_NAME_ARG=""

# Parse arguments
eval set -- ${CLI_ARGS_STR}
TEST_REMOTE_NAME="${1}"
shift || true

# Check for runner name (if next arg is not a flag, it's the runner name)
if [ $# -gt 0 ] && [[ ! "${1}" =~ ^-- ]]; then
  RUNNER_NAME_ARG="${1}"
  shift || true
fi

# Check for flags
while [ $# -gt 0 ]; do
  case "${1}" in
    --keep|--no-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    *)
      echo "⚠️  Warning: Unknown argument '${1}', ignoring"
      shift
      ;;
  esac
done

# Determine RUNNER_NAME:
# 1. If explicitly provided as argument, use it (highest priority)
# 2. Else, use default 'runner'
if [ -n "${RUNNER_NAME_ARG}" ]; then
  RUNNER_NAME="${RUNNER_NAME_ARG}"
else
  RUNNER_NAME="runner"
fi

# Export for other tasks and scripts
export TEST_REMOTE_NAME
export SKIP_CLEANUP
export INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
export RUNNER_NAME
export VM_NAME="${RUNNER_NAME}"  # For compatibility with vm:instantiate
export VM_INSTANCE_NAME="${RUNNER_NAME}"

# Write variables to a file for subsequent scripts to source
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.runner-instantiate.env"
{
  echo "export TEST_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export SKIP_CLEANUP='${SKIP_CLEANUP}'"
  echo "export INCUS_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export RUNNER_NAME='${RUNNER_NAME}'"
  echo "export VM_NAME='${RUNNER_NAME}'"
  echo "export VM_INSTANCE_NAME='${RUNNER_NAME}'"
} > "${ENV_FILE}"

