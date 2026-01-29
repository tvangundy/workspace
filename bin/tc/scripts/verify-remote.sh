#!/usr/bin/env bash
# Verify Incus remote exists and we can connect.
set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

log_step "Verifying Incus remote connection"

# Verify remote
verify_incus_remote "${TEST_REMOTE_NAME:-${REMOTE_NAME}}"

