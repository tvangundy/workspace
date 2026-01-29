#!/usr/bin/env bash
# Initialize Terraform for the Talos cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

if [ -z "${WINDSOR_PROJECT_ROOT:-}" ]; then
  echo "Error: WINDSOR_PROJECT_ROOT variable is not defined"
  echo "Run this from within a Windsor workspace"
  exit 1
fi

if [ ! -d "${TERRAFORM_DIR}" ]; then
  echo "Error: Terraform directory not found: ${TERRAFORM_DIR}"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Initializing Terraform providers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Working directory: $(pwd)"
echo "Terraform directory: ${TERRAFORM_DIR}"
cd "${TERRAFORM_DIR}"
echo "Changed to: $(pwd)"
echo ""

if [ -d ".terraform" ] && [ -f ".terraform.lock.hcl" ]; then
  echo "ℹ️  Terraform already initialized"
  echo "   Skipping init (providers already installed)"
else
  echo "🔧 Initializing Terraform (this may take a moment to download providers)..."
  echo "   (Downloading providers may take 1-5 minutes depending on network speed)"
  
  # Run terraform init directly (works quickly when run manually)
  echo ""
  EXIT_CODE=0  # Initialize to prevent unbound variable error
  set +e  # Temporarily disable exit on error to capture exit code
  terraform init
  EXIT_CODE=$?
  set -e  # Re-enable exit on error immediately
  
  # Check result and exit immediately on failure
  if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "✅ Terraform initialized successfully"
  elif [ ${EXIT_CODE} -eq 124 ]; then
    echo ""
    echo "❌ Terraform init timed out"
    echo "   This may indicate a network issue. Please check your connection and try again."
    exit ${EXIT_CODE}
  else
    echo ""
    echo "❌ Terraform init failed with exit code ${EXIT_CODE}"
    echo ""
    echo "Common issues:"
    echo "  - Network connectivity: Cannot reach registry.terraform.io"
    echo "  - DNS resolution: Check if 'registry.terraform.io' resolves"
    echo "  - Firewall/proxy: May be blocking HTTPS connections"
    echo ""
    echo "To diagnose, try:"
    echo "  curl -v https://registry.terraform.io/.well-known/terraform.json"
    exit ${EXIT_CODE}
  fi
fi

# Select or create workspace for this cluster to isolate state
echo ""
echo "Selecting Terraform workspace for cluster '${CLUSTER_NAME}'..."
WORKSPACE_EXISTS=false
# Check if workspace exists (handle * marker for current workspace and spaces for others)
# Pattern matches: "* workspace-name" or "  workspace-name" (with leading spaces)
if terraform workspace list 2>/dev/null | grep -qE "^[[:space:]]*\*[[:space:]]+${CLUSTER_NAME}[[:space:]]*$|^[[:space:]]+${CLUSTER_NAME}[[:space:]]*$"; then
  WORKSPACE_EXISTS=true
fi

if [ "${WORKSPACE_EXISTS}" = "true" ]; then
  echo "  Workspace '${CLUSTER_NAME}' already exists, selecting it..."
  if terraform workspace select "${CLUSTER_NAME}" 2>/dev/null; then
    echo "✅ Selected existing Terraform workspace '${CLUSTER_NAME}'"
  else
    echo "❌ Error: Failed to select workspace '${CLUSTER_NAME}'"
    exit 1
  fi
else
  echo "  Creating new workspace '${CLUSTER_NAME}'..."
  if terraform workspace new "${CLUSTER_NAME}" 2>/dev/null; then
    echo "✅ Created and selected Terraform workspace '${CLUSTER_NAME}'"
  else
    # Workspace might have been created between check and creation, try to select it
    if terraform workspace select "${CLUSTER_NAME}" 2>/dev/null; then
      echo "✅ Workspace '${CLUSTER_NAME}' was created by another process, selected it"
    else
      echo "❌ Error: Failed to create or select workspace '${CLUSTER_NAME}'"
      exit 1
    fi
  fi
fi

CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "")
if [ "${CURRENT_WORKSPACE}" = "${CLUSTER_NAME}" ]; then
  echo "✅ Using Terraform workspace '${CLUSTER_NAME}'"
else
  echo "❌ Error: Failed to select workspace '${CLUSTER_NAME}' (current: '${CURRENT_WORKSPACE}')"
  exit 1
fi

