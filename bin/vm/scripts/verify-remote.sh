#!/usr/bin/env bash
# Verify remote connection exists
set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/vm-common.sh"

# Load VM environment
load_vm_env

# Verify remote
verify_incus_remote "${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
