#!/usr/bin/env bash
# Terraform-specific utilities
# Source this from other scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize Terraform in a directory
terraform_init() {
  local terraform_dir="$1"
  
  if [ ! -d "${terraform_dir}" ]; then
    log_error "Terraform directory not found: ${terraform_dir}"
    return 1
  fi
  
  log_step "Initialize Terraform"
  cd "${terraform_dir}"
  terraform init -upgrade
}

# Apply Terraform configuration
terraform_apply() {
  local terraform_dir="$1"
  
  if [ ! -d "${terraform_dir}" ]; then
    log_error "Terraform directory not found: ${terraform_dir}"
    return 1
  fi
  
  log_step "Apply Terraform configuration"
  cd "${terraform_dir}"
  terraform apply -auto-approve
}

# Destroy Terraform resources
terraform_destroy() {
  local terraform_dir="$1"
  local var_overrides="${2:-}"
  
  if [ ! -d "${terraform_dir}" ]; then
    log_error "Terraform directory not found: ${terraform_dir}"
    return 1
  fi
  
  log_step "Destroy Terraform resources"
  cd "${terraform_dir}"
  
  if [ -n "${var_overrides}" ]; then
    terraform destroy -auto-approve ${var_overrides}
  else
    terraform destroy -auto-approve
  fi
}

# Get Terraform output value
terraform_output() {
  local terraform_dir="$1"
  local output_name="$2"
  
  if [ ! -d "${terraform_dir}" ]; then
    log_error "Terraform directory not found: ${terraform_dir}"
    return 1
  fi
  
  cd "${terraform_dir}"
  terraform output -raw "${output_name}" 2>/dev/null || return 1
}

