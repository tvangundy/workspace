#!/usr/bin/env bash
# Parse CLI arguments for instantiate task
set -euo pipefail

CLI_ARGS_STR="${1:-}"

if [ -z "${CLI_ARGS_STR}" ]; then
  echo "Error: INCUS_REMOTE_NAME is required"
  echo "Usage: task vm:instantiate -- <incus-remote-name> [<vm-name>] [--keep] [--no-workspace] [--windsor-up]"
  echo ""
  echo "Arguments:"
  echo "  <incus-remote-name>    Required: Name of the Incus remote"
  echo "  <vm-name>              Optional: Name for the VM (default: 'vm')"
  echo ""
  echo "Options:"
  echo "  --keep, --no-cleanup    Keep VM running (default: delete VM)"
  echo "  --no-workspace          Skip workspace initialization (default: initialize workspace)"
  echo "  --windsor-up            Run windsor init and windsor up after workspace setup"
  echo ""
  echo "Examples:"
  echo "  task vm:instantiate -- nuc"
  echo "  task vm:instantiate -- nuc my-vm"
  echo "  task vm:instantiate -- nuc my-vm --keep"
  exit 1
fi

# Initialize flags
SKIP_CLEANUP=false
SKIP_WORKSPACE=false
RUN_WINDSOR_UP=false
VM_NAME_ARG=""

# Parse arguments
eval set -- ${CLI_ARGS_STR}
TEST_REMOTE_NAME="${1}"
shift || true

# Check for VM name (if next arg is not a flag, it's the VM name)
if [ $# -gt 0 ] && [[ ! "${1}" =~ ^-- ]]; then
  VM_NAME_ARG="${1}"
  shift || true
fi

# Check for flags
while [ $# -gt 0 ]; do
  case "${1}" in
    --keep|--no-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    --no-workspace)
      SKIP_WORKSPACE=true
      shift
      ;;
    --windsor-up)
      RUN_WINDSOR_UP=true
      shift
      ;;
    *)
      echo "⚠️  Warning: Unknown argument '${1}', ignoring"
      shift
      ;;
  esac
done

# Determine VM_NAME:
# 1. If explicitly provided as argument, use it (highest priority - overrides active context)
# 2. Else, if there's an active Windsor context, use that
# 3. Else, use existing VM_NAME from environment, or default to 'vm'
if [ -n "${VM_NAME_ARG}" ]; then
  # Parameter explicitly provided - use it (overrides active context)
  VM_NAME="${VM_NAME_ARG}"
  VM_INSTANCE_NAME="${VM_NAME_ARG}"
else
  # Check for active Windsor context
  ACTIVE_CONTEXT=""
  if command -v windsor > /dev/null 2>&1; then
    # Try to get current context
    ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
    # Also check if WINDSOR_CONTEXT is set in environment
    if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
      ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
    fi
  fi
  
  if [ -n "${ACTIVE_CONTEXT}" ]; then
    # Active context exists - use it
    VM_NAME="${ACTIVE_CONTEXT}"
    VM_INSTANCE_NAME="${ACTIVE_CONTEXT}"
  else
    # No active context and no parameter - use environment or default
    VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME:-vm}}"
    VM_INSTANCE_NAME="${VM_INSTANCE_NAME:-${VM_NAME}}"
  fi
fi

# Export for other tasks and scripts
export TEST_REMOTE_NAME
export SKIP_CLEANUP
export SKIP_WORKSPACE
export RUN_WINDSOR_UP
export INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
export VM_NAME
export VM_INSTANCE_NAME

# Write variables to a file for subsequent scripts to source
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
{
  echo "export TEST_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export SKIP_CLEANUP='${SKIP_CLEANUP}'"
  echo "export SKIP_WORKSPACE='${SKIP_WORKSPACE}'"
  echo "export RUN_WINDSOR_UP='${RUN_WINDSOR_UP}'"
  echo "export INCUS_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export VM_NAME='${VM_NAME}'"
  echo "export VM_INSTANCE_NAME='${VM_NAME}'"
} > "${ENV_FILE}"
