#!/usr/bin/env bash
# Runner-specific shared utilities
# Source this from runner scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../../lib" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/windsor.sh"
source "${LIB_DIR}/incus.sh"

# Load runner-specific environment
load_runner_env() {
  local project_root
  project_root=$(get_windsor_project_root)
  local env_file="${project_root}/.runner-instantiate.env"
  
  source_env_file "${env_file}"
  
  # Set defaults
  TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME:-}}"
  RUNNER_NAME="${RUNNER_NAME:-runner}"
  RUNNER_USER="${RUNNER_USER:-runner}"
  RUNNER_HOME="${RUNNER_HOME:-/home/${RUNNER_USER}}"
  GITHUB_RUNNER_REPO_URL="${GITHUB_RUNNER_REPO_URL:-}"
  GITHUB_RUNNER_TOKEN="${GITHUB_RUNNER_TOKEN:-}"
  GITHUB_RUNNER_VERSION="${GITHUB_RUNNER_VERSION:-}"
  GITHUB_RUNNER_ARCH="${GITHUB_RUNNER_ARCH:-x64}"
  
  export TEST_REMOTE_NAME RUNNER_NAME RUNNER_USER RUNNER_HOME
  export GITHUB_RUNNER_REPO_URL GITHUB_RUNNER_TOKEN GITHUB_RUNNER_VERSION GITHUB_RUNNER_ARCH
}

