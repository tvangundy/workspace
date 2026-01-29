#!/usr/bin/env bash
# Create VM using vm:instantiate task
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.runner-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Create Runner VM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Creating VM '${RUNNER_NAME}' on remote '${TEST_REMOTE_NAME}'..."

# Build task command
TASK_CMD="task vm:instantiate -- ${TEST_REMOTE_NAME} ${RUNNER_NAME} --no-workspace"
if [ "${SKIP_CLEANUP}" = "true" ]; then
  TASK_CMD="${TASK_CMD} --keep"
fi

# Execute vm:instantiate task
echo "  Running: ${TASK_CMD}"
${TASK_CMD}

echo "✅ VM '${RUNNER_NAME}' created successfully"

