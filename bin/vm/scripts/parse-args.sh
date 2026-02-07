#!/usr/bin/env bash
# Parse CLI arguments for instantiate task
set -euo pipefail

CLI_ARGS_STR="${1:-}"

if [ -z "${CLI_ARGS_STR}" ]; then
  echo "Error: INCUS_REMOTE_NAME and INCUS_REMOTE_IP are required"
  echo "Usage: task vm:instantiate -- <incus-remote-name> <remote-ip> [<vm-name>] [--destroy] [--windsor-up] [--workspace] [--runner]"
  echo ""
  echo "Arguments:"
  echo "  <incus-remote-name>    Required: Name of the Incus remote"
  echo "  <remote-ip>            Required: IP address of the Incus remote (set on VM as INCUS_REMOTE_IP)"
  echo "  <vm-name>              Optional: Name for the VM (default: 'vm')"
  echo ""
  echo "Options:"
  echo "  --destroy               Destroy VM at end of instantiate (default: keep VM)"
  echo "  --windsor-up            Run windsor init and windsor up after workspace setup"
  echo "  --workspace             Copy and initialize workspace on the VM (default: skip workspace init)"
  echo "  --runner                Add a GitHub Actions runner to the VM at the end (runner user + install-github-runner)"
  echo ""
  echo "Examples:"
  echo "  task vm:instantiate -- nuc 192.168.2.100"
  echo "  task vm:instantiate -- nuc 192.168.2.100 my-vm"
  echo "  task vm:instantiate -- nuc 192.168.2.100 my-vm --destroy"
  echo "  task vm:instantiate -- nuc 192.168.2.100 my-vm --workspace"
  echo "  task vm:instantiate -- nuc 192.168.2.100 my-vm --runner"
  exit 1
fi

# Initialize flags: default keep VM (skip cleanup); --destroy sets skip cleanup false
# Workspace init is off by default; only run when --workspace is present
SKIP_CLEANUP=true
RUN_WINDSOR_UP=false
VM_INIT_WORKSPACE=false
VM_ADD_RUNNER=false
VM_NAME_ARG=""

# Parse arguments
eval set -- ${CLI_ARGS_STR}
TEST_REMOTE_NAME="${1}"
shift || true

# Remote IP is required (second positional argument)
if [ $# -eq 0 ] || [[ "${1}" =~ ^-- ]]; then
  echo "Error: <remote-ip> is required"
  echo "Usage: task vm:instantiate -- <incus-remote-name> <remote-ip> [<vm-name>] [--destroy] [--windsor-up] [--workspace] [--runner]"
  exit 1
fi
INCUS_REMOTE_IP_ARG="${1}"
shift || true

# Check for VM name (if next arg is not a flag, it's the VM name)
if [ $# -gt 0 ] && [[ ! "${1}" =~ ^-- ]]; then
  VM_NAME_ARG="${1}"
  shift || true
fi

# Check for flags
while [ $# -gt 0 ]; do
  case "${1}" in
    --destroy)
      SKIP_CLEANUP=false
      shift
      ;;
    --windsor-up)
      RUN_WINDSOR_UP=true
      shift
      ;;
    --workspace)
      VM_INIT_WORKSPACE=true
      shift
      ;;
    --runner)
      VM_ADD_RUNNER=true
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

# When --runner was used without an explicit VM name, ensure the active context is appropriate for a runner VM.
# This avoids creating a VM with a non-runner context (e.g. dev-cluster) and failing later or misnaming the VM.
if [ "${VM_ADD_RUNNER}" = "true" ] && [ -z "${VM_NAME_ARG}" ]; then
  _project_root="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
  CONTEXTS_DIR="${_project_root}/contexts"
  CONTEXT_LOOKS_LIKE_RUNNER=false
  if [[ "${VM_NAME}" == *"runner"* ]]; then
    CONTEXT_LOOKS_LIKE_RUNNER=true
  elif [ -f "${CONTEXTS_DIR}/${VM_NAME}/windsor.yaml" ]; then
    if (grep -qE '^\s+(VM_INSTANCE_NAME|GITHUB_RUNNER_REPO_URL):' "${CONTEXTS_DIR}/${VM_NAME}/windsor.yaml" 2>/dev/null); then
      CONTEXT_LOOKS_LIKE_RUNNER=true
    fi
  fi
  if [ "${CONTEXT_LOOKS_LIKE_RUNNER}" = "false" ]; then
    RUNNER_CONTEXTS=""
    if [ -d "${CONTEXTS_DIR}" ]; then
      RUNNER_CONTEXTS=$(find "${CONTEXTS_DIR}" -maxdepth 1 -type d -name '*runner*' -exec basename {} \; 2>/dev/null | sort -u | tr '\n' ' ')
    fi
    echo ""
    echo "❌ Error: You passed --runner but the current context is not a runner context."
    echo "   VM name would be: '${VM_NAME}' (from active Windsor context)."
    echo "   A runner VM should use a context that has runner configuration (e.g. VM_INSTANCE_NAME and GITHUB_RUNNER_* in windsor.yaml)."
    if [ -n "${RUNNER_CONTEXTS}" ]; then
      echo ""
      echo "   Runner-like context(s) found: ${RUNNER_CONTEXTS}"
      echo "   Set one before running, e.g.:  windsor context set dev-runner"
    fi
    echo ""
    echo "   Then run: task vm:instantiate -- ${TEST_REMOTE_NAME} ${INCUS_REMOTE_IP_ARG} --runner"
    echo ""
    exit 1
  fi
fi

# Export for other tasks and scripts
export TEST_REMOTE_NAME
export INCUS_REMOTE_IP="${INCUS_REMOTE_IP_ARG}"
export SKIP_CLEANUP
export RUN_WINDSOR_UP
export VM_INIT_WORKSPACE
export VM_ADD_RUNNER
export INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
export VM_NAME
export VM_INSTANCE_NAME

# Write variables to a file for subsequent scripts to source
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
mkdir -p "${PROJECT_ROOT}/.workspace"
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"

# Read VM_IMAGE from windsor.yaml (context dir from active context or VM_NAME)
# Must be in initial write so check-vm-image gets it (each task runs in new shell)
VM_IMAGE_FOR_ENV=""
ACTIVE_CTX=$(windsor context get 2>/dev/null || echo "${WINDSOR_CONTEXT:-}")
CONTEXT_DIR="${ACTIVE_CTX:-${VM_NAME}}"
WINDSOR_YAML="${PROJECT_ROOT}/contexts/${CONTEXT_DIR}/windsor.yaml"
if [ -f "${WINDSOR_YAML}" ]; then
  VM_IMAGE_FOR_ENV=$( (grep -E '^\s+VM_IMAGE:' "${WINDSOR_YAML}" 2>/dev/null | head -1 | sed -E 's/.*VM_IMAGE:[[:space:]]*["]?([^"]*)["]?.*/\1/' | tr -d ' ') || true)
fi
VM_IMAGE_FOR_ENV="${VM_IMAGE_FOR_ENV:-ubuntu/25.04}"

{
  echo "export TEST_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export INCUS_REMOTE_IP='${INCUS_REMOTE_IP}'"
  echo "export SKIP_CLEANUP='${SKIP_CLEANUP}'"
  echo "export RUN_WINDSOR_UP='${RUN_WINDSOR_UP}'"
  echo "export VM_INIT_WORKSPACE='${VM_INIT_WORKSPACE}'"
  echo "export VM_ADD_RUNNER='${VM_ADD_RUNNER}'"
  echo "export INCUS_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export VM_NAME='${VM_NAME}'"
  echo "export VM_INSTANCE_NAME='${VM_NAME}'"
  echo "export VM_IMAGE='${VM_IMAGE_FOR_ENV}'"
} > "${ENV_FILE}"

# Always report which VM name is being used so the user can spot wrong-context mistakes
if [ -n "${VM_NAME_ARG}" ]; then
  echo "Using VM name: '${VM_NAME}' (from explicit argument)"
else
  _ctx="${ACTIVE_CONTEXT:-none}"
  echo "Using VM name: '${VM_NAME}' (from Windsor context '${_ctx}')"
fi
if [ "${VM_ADD_RUNNER}" = "true" ]; then
  echo "Runner will be added to this VM at the end of instantiate."
fi
