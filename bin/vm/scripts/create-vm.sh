#!/usr/bin/env bash
# Create VM using Terraform
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# Check Terraform state first to see if there's a VM managed by Terraform with a different name
TERRAFORM_DIR="${PROJECT_ROOT}/terraform/vm"
TERRAFORM_STATE_VM_NAME=""

if [ -d "${TERRAFORM_DIR}" ]; then
  # Check if Terraform state exists and get the VM name from it
  cd "${TERRAFORM_DIR}" 2>/dev/null || true
  
  # Try to get VM name from Terraform state using terraform state list and show
  if [ -d ".terraform" ] || [ -f "terraform.tfstate" ]; then
    # Initialize Terraform if needed (backend=false to avoid backend config issues)
    if terraform init -backend=false >/dev/null 2>&1; then
      # Check if incus_instance.vm exists in state
      if terraform state list 2>/dev/null | grep -q "incus_instance.vm"; then
        # Get the VM name from state - extract just the value between quotes
        # terraform state show outputs: name = "runner" (with quotes)
        NAME_LINE=$(terraform state show incus_instance.vm 2>/dev/null | grep -E '^\s+name\s*=' | head -1)
        if [ -n "${NAME_LINE}" ]; then
          # Extract value - handle both quoted and unquoted formats
          # First try to extract quoted value: name = "runner"
          TERRAFORM_STATE_VM_NAME=$(echo "${NAME_LINE}" | sed -E 's/.*name\s*=\s*"([^"]*)".*/\1/')
          # If that didn't work (no quotes found), try unquoted: name = runner
          if [ -z "${TERRAFORM_STATE_VM_NAME}" ] || [ "${TERRAFORM_STATE_VM_NAME}" = "${NAME_LINE}" ]; then
            TERRAFORM_STATE_VM_NAME=$(echo "${NAME_LINE}" | sed -E 's/.*name\s*=\s*([^[:space:]]+).*/\1/')
          fi
          # Clean up any remaining quotes, special characters, and whitespace
          TERRAFORM_STATE_VM_NAME=$(echo "${TERRAFORM_STATE_VM_NAME}" | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | sed "s/^[[:space:]]*'//;s/'[[:space:]]*$//" | tr -d '[:space:]')
          # Additional safety check: if it still contains "name=", something went wrong
          if echo "${TERRAFORM_STATE_VM_NAME}" | grep -q "name="; then
            # Try a more aggressive extraction
            TERRAFORM_STATE_VM_NAME=$(echo "${TERRAFORM_STATE_VM_NAME}" | sed -E 's/.*"([^"]+)".*/\1/' | sed -E 's/.*=([^[:space:]]+).*/\1/' | tr -d '[:space:]')
          fi
        fi
      fi
    fi
  fi
  
  cd - > /dev/null 2>&1 || true
fi

# Check if the VM we want to create already exists in Incus
VM_EXISTS_IN_INCUS=false
if incus list "${TEST_REMOTE_NAME}:${VM_NAME}" --format csv -c n 2>/dev/null | grep -q "^${VM_NAME}$"; then
  VM_EXISTS_IN_INCUS=true
fi

# If Terraform state has the same VM name, we can reuse it - skip destroy and continue
if [ -n "${TERRAFORM_STATE_VM_NAME}" ] && [ "${TERRAFORM_STATE_VM_NAME}" = "${VM_NAME}" ]; then
  echo "ℹ️  Terraform state already has VM '${VM_NAME}' - reusing existing VM"
  echo "   Skipping VM creation, continuing with setup..."
  # Skip the terraform apply step - VM already exists
  SKIP_TERRAFORM_APPLY=true
elif [ -n "${TERRAFORM_STATE_VM_NAME}" ] && [ "${TERRAFORM_STATE_VM_NAME}" != "${VM_NAME}" ]; then
  # Validate that TERRAFORM_STATE_VM_NAME is a clean value (no special characters that would break commands)
  if [[ ! "${TERRAFORM_STATE_VM_NAME}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "⚠️  Warning: Invalid VM name extracted from Terraform state: '${TERRAFORM_STATE_VM_NAME}'"
    echo "   This might be a parsing error. Attempting to clean it up..."
    # Try to extract just alphanumeric characters, dots, dashes, and underscores
    TERRAFORM_STATE_VM_NAME=$(echo "${TERRAFORM_STATE_VM_NAME}" | grep -oE '[a-zA-Z0-9_.-]+' | head -1)
    if [ -z "${TERRAFORM_STATE_VM_NAME}" ]; then
      echo "   ❌ Could not extract valid VM name. Skipping state check."
      TERRAFORM_STATE_VM_NAME=""
      SKIP_TERRAFORM_APPLY=false
    else
      echo "   Using cleaned VM name: '${TERRAFORM_STATE_VM_NAME}'"
    fi
  fi
  
  if [ -n "${TERRAFORM_STATE_VM_NAME}" ] && [ "${TERRAFORM_STATE_VM_NAME}" != "${VM_NAME}" ]; then
    # Terraform state has a different VM name - ask user what to do
    echo ""
    echo "⚠️  Warning: Terraform state has VM '${TERRAFORM_STATE_VM_NAME}', but you're trying to create '${VM_NAME}'"
    echo "   This would cause Terraform to rename the existing VM, which may not be desired."
    echo ""
    echo "   Do you want to destroy the existing VM '${TERRAFORM_STATE_VM_NAME}' and create '${VM_NAME}' instead?"
    echo "   (This will permanently delete the VM and all its data)"
    echo ""
    read -p "   Destroy existing VM and continue? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "   Aborting. No changes made."
      echo ""
      echo "   To proceed manually:"
      echo "     task vm:destroy -- ${TERRAFORM_STATE_VM_NAME}"
      echo "     task vm:instantiate -- ${TEST_REMOTE_NAME} ${VM_NAME}"
      exit 0
    fi
    
    echo ""
    echo "   Destroying existing VM '${TERRAFORM_STATE_VM_NAME}'..."
    task vm:destroy -- "${TERRAFORM_STATE_VM_NAME}" || {
      echo "   ❌ Failed to destroy existing VM. Aborting."
      exit 1
    }
    echo "   ✅ Existing VM destroyed"
    sleep 2
    SKIP_TERRAFORM_APPLY=false
  fi
else
  SKIP_TERRAFORM_APPLY=false
fi

# If the VM exists in Incus with the same name we want, and we're not reusing from Terraform state, destroy it first
if [ "${VM_EXISTS_IN_INCUS}" = "true" ] && [ "${SKIP_TERRAFORM_APPLY:-false}" != "true" ]; then
  echo "⚠️  Warning: VM '${VM_NAME}' already exists. Destroying..."
  task vm:destroy -- ${VM_NAME} || true
  sleep 5
fi

# Generate terraform.tfvars
task vm:generate-tfvars

# Initialize Terraform
task vm:terraform:init

# Apply Terraform configuration to create VM (unless we're reusing existing)
if [ "${SKIP_TERRAFORM_APPLY:-false}" != "true" ]; then
  task vm:terraform:apply
else
  echo "ℹ️  Skipping Terraform apply - reusing existing VM '${VM_NAME}'"
fi

# Export variables for subsequent tasks
export VM_NAME="${VM_NAME}"
export TEST_REMOTE_NAME="${TEST_REMOTE_NAME}"
