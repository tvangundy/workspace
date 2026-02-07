#!/usr/bin/env bash
# Parse CLI arguments for tc:instantiate. Exports TEST_REMOTE_NAME, INCUS_REMOTE_IP, SKIP_CLEANUP, CLUSTER_NAME.
# Source this script to inherit exports. Writes .workspace/.tc-instantiate.env for other scripts.
set -euo pipefail

CLI_ARGS_STR="${1:-}"

if [ -z "${CLI_ARGS_STR}" ]; then
  echo "Error: INCUS_REMOTE_NAME and INCUS_REMOTE_IP are required"
  echo "Usage: task tc:instantiate -- <remote-name> <remote-ip> [<cluster-name>] [--destroy]"
  echo ""
  echo "Arguments:"
  echo "  <remote-name>          Required: Name of the Incus remote"
  echo "  <remote-ip>            Required: IP address of the Incus remote"
  echo "  <cluster-name>         Optional: Name for the cluster (default: 'talos-test-cluster')"
  echo ""
  echo "Options:"
  echo "  --destroy               Destroy cluster at end of instantiate (default: keep cluster)"
  echo ""
  echo "Examples:"
  echo "  task tc:instantiate -- nuc 192.168.2.101"
  echo "  task tc:instantiate -- nuc 192.168.2.101 my-cluster"
  echo "  task tc:instantiate -- nuc 192.168.2.101 my-cluster --destroy"
  exit 1
fi

# Default: keep cluster (skip cleanup). --destroy sets SKIP_CLEANUP=false to run cleanup.
SKIP_CLEANUP=true
CLUSTER_NAME_ARG=""

eval set -- ${CLI_ARGS_STR}
TEST_REMOTE_NAME="${1}"
shift || true

# Remote IP is required (second positional argument)
if [ $# -eq 0 ] || [[ "${1}" =~ ^-- ]]; then
  echo "Error: <remote-ip> is required"
  echo "Usage: task tc:instantiate -- <remote-name> <remote-ip> [<cluster-name>] [--destroy]"
  exit 1
fi
INCUS_REMOTE_IP_ARG="${1}"
shift || true

# Check for cluster name (if next arg is not a flag, it's the cluster name)
if [ $# -gt 0 ] && [[ ! "${1}" =~ ^-- ]]; then
  CLUSTER_NAME_ARG="${1}"
  shift || true
fi

while [ $# -gt 0 ]; do
  case "${1}" in
    --destroy)
      SKIP_CLEANUP=false
      shift
      ;;
    *)
      echo "⚠️  Warning: Unknown argument '${1}', ignoring"
      shift
      ;;
  esac
done

# Determine CLUSTER_NAME:
# 1. If explicitly provided as argument, use it (highest priority - overrides active context)
# 2. Else, if there's an active Windsor context, use that
# 3. Else, use existing CLUSTER_NAME from environment, or default to 'talos-test-cluster'
if [ -n "${CLUSTER_NAME_ARG}" ]; then
  # Parameter explicitly provided - use it (overrides active context)
  CLUSTER_NAME="${CLUSTER_NAME_ARG}"
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
    CLUSTER_NAME="${ACTIVE_CONTEXT}"
  else
    # No active context and no parameter - use environment or default
    CLUSTER_NAME="${CLUSTER_NAME:-talos-test-cluster}"
  fi
fi

export TEST_REMOTE_NAME
export INCUS_REMOTE_IP="${INCUS_REMOTE_IP_ARG}"
export SKIP_CLEANUP
export INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
export CLUSTER_NAME

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
mkdir -p "${PROJECT_ROOT}/.workspace"
ENV_FILE="${PROJECT_ROOT}/.workspace/.tc-instantiate.env"
{
  echo "export CLUSTER_NAME='${CLUSTER_NAME}'"
  echo "export INCUS_REMOTE_IP='${INCUS_REMOTE_IP}'"
  echo "export INCUS_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export TEST_REMOTE_NAME='${TEST_REMOTE_NAME}'"
  echo "export SKIP_CLEANUP='${SKIP_CLEANUP}'"
} > "${ENV_FILE}"
