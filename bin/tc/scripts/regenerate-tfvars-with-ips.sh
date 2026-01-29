#!/usr/bin/env bash
# Regenerate terraform.tfvars with current IPs (from env), then terraform apply (Talos config).
set -euo pipefail

# Save SCRIPT_DIR before sourcing libraries (they may overwrite it)
TC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${TC_SCRIPT_DIR}"
source "${TC_SCRIPT_DIR}/../lib/tc-common.sh"

# Restore SCRIPT_DIR after sourcing (libraries may have overwritten it)
SCRIPT_DIR="${TC_SCRIPT_DIR}"

# Load TC environment
load_tc_env

log_step "Regenerating Terraform configuration and bootstrapping etcd cluster"

if ! "${SCRIPT_DIR}/generate-tfvars.sh" > /tmp/tc_generate_tfvars.log 2>&1; then
  echo "❌ Failed to regenerate terraform.tfvars"
  cat /tmp/tc_generate_tfvars.log
  exit 1
fi

echo "Applying Talos config and bootstrapping cluster..."
if ! "${SCRIPT_DIR}/terraform-apply.sh" > /tmp/tc_terraform_talos.log 2>&1; then
  echo "❌ Talos config apply failed"
  tail -80 /tmp/tc_terraform_talos.log
  exit 1
fi
echo "✅ Talos config applied"

