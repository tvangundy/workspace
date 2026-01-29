#!/usr/bin/env bash
# Check status of GitHub Actions runner service
set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/runner-common.sh"

# Load runner environment
load_runner_env

TEST_REMOTE_NAME="${TEST_REMOTE_NAME}"
RUNNER_NAME="${RUNNER_NAME}"
RUNNER_USER="${RUNNER_USER}"
RUNNER_HOME="${RUNNER_HOME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GitHub Actions Runner Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VM: ${TEST_REMOTE_NAME}:${RUNNER_NAME}"
echo "  User: ${RUNNER_USER}"
echo ""

# Check if runner is installed
RUNNER_INSTALLED=false
if incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- test -f "${RUNNER_HOME}/actions-runner/svc.sh" 2>/dev/null; then
  RUNNER_INSTALLED=true
fi

if [ "${RUNNER_INSTALLED}" = "false" ]; then
  echo "❌ GitHub Actions runner is not installed"
  echo "   Run: task runner:instantiate -- ${TEST_REMOTE_NAME} ${RUNNER_NAME} --keep"
  exit 1
fi

# Get service status
echo "  Service Status:"
incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
  cd ${RUNNER_HOME}/actions-runner
  if [ -f ./svc.sh ]; then
    sudo ./svc.sh status
  fi
" || {
  echo "  ⚠️  Could not retrieve service status"
}

# Get runner configuration info if available
echo ""
echo "  Runner Configuration:"
if incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- test -f "${RUNNER_HOME}/actions-runner/.runner" 2>/dev/null; then
  # Parse JSON on the VM using jq (which should be installed)
  RUNNER_NAME_CONFIG=$(incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "jq -r '.agent.name // empty' ${RUNNER_HOME}/actions-runner/.runner 2>/dev/null" || echo "Unknown")
  RUNNER_URL=$(incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "jq -r '.serverUrl // empty' ${RUNNER_HOME}/actions-runner/.runner 2>/dev/null" || echo "Unknown")
  
  # If jq parsing failed, try alternative method
  if [ "${RUNNER_NAME_CONFIG}" = "Unknown" ] || [ -z "${RUNNER_NAME_CONFIG}" ]; then
    # Fallback: read the file and parse with sed
    RUNNER_CONFIG=$(incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- cat "${RUNNER_HOME}/actions-runner/.runner" 2>/dev/null || echo "")
    if [ -n "${RUNNER_CONFIG}" ]; then
      RUNNER_NAME_CONFIG=$(echo "${RUNNER_CONFIG}" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || echo "Unknown")
      RUNNER_URL=$(echo "${RUNNER_CONFIG}" | sed -n 's/.*"serverUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || echo "Unknown")
    fi
  fi
  
  if [ "${RUNNER_NAME_CONFIG}" != "Unknown" ] && [ -n "${RUNNER_NAME_CONFIG}" ]; then
    echo "  Runner Name: ${RUNNER_NAME_CONFIG}"
  else
    echo "  Runner Name: Unknown"
  fi
  
  if [ "${RUNNER_URL}" != "Unknown" ] && [ -n "${RUNNER_URL}" ]; then
    echo "  Repository: ${RUNNER_URL}"
  else
    echo "  Repository: Unknown"
  fi
else
  echo "  ⚠️  Runner configuration file not found"
fi

echo ""
echo "✅ Status check complete"

