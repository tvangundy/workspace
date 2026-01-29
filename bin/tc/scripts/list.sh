#!/usr/bin/env bash
# List all Talos clusters
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Set PROJECT_ROOT
PROJECT_ROOT=$(get_windsor_project_root)

# Get the default remote name if available
DEFAULT_REMOTE="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME:-}}"
if [ -z "${DEFAULT_REMOTE}" ]; then
  # Try to get from incus remote list
  DEFAULT_REMOTE=$(incus remote list --format csv 2>/dev/null | grep -E ",(default|current)" | cut -d',' -f1 | head -1 || echo "")
  if [ -z "${DEFAULT_REMOTE}" ]; then
    DEFAULT_REMOTE=$(incus remote list --format csv 2>/dev/null | grep -v "^NAME," | cut -d',' -f1 | head -1 || echo "")
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "${DEFAULT_REMOTE}" ]; then
  echo "Talos Clusters on remote '${DEFAULT_REMOTE}'"
else
  echo "Talos Clusters"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get all VM names first to check if there are any cluster VMs
ALL_VM_NAMES=$(incus list "${DEFAULT_REMOTE}:" --format csv -c n 2>/dev/null || echo "")
if [ -z "${ALL_VM_NAMES}" ]; then
  echo "⚠️  Could not list VMs on remote '${DEFAULT_REMOTE}'"
  echo "   Check that the remote is configured and accessible"
  exit 1
fi

# Filter to only cluster VMs (ending in -cp or -worker-*)
CLUSTER_VM_NAMES=$(echo "${ALL_VM_NAMES}" | grep '\-cp$' | grep -v '^NAME$' || echo "")
CLUSTER_VM_NAMES="${CLUSTER_VM_NAMES} $(echo "${ALL_VM_NAMES}" | grep '\-worker-[0-9]' | grep -v '^NAME$' || echo "")"
CLUSTER_VM_NAMES=$(echo "${CLUSTER_VM_NAMES}" | tr ' ' '\n' | grep -v '^$' | sort -u || echo "")

if [ -z "${CLUSTER_VM_NAMES}" ]; then
  echo "No Talos clusters found."
  echo ""
  echo "To create a cluster:"
  echo "  task tc:instantiate -- <remote-name> [<cluster-name>]"
  exit 0
fi

# List cluster VMs using incus list (same format as vm:list)
# Filter to only show cluster VMs (ending in -cp or -worker-*)
# Use awk to preserve table formatting
incus list "${DEFAULT_REMOTE}:" --format table 2>/dev/null | awk '
BEGIN { in_vm = 0; show_vm = 0 }
/^\+/ {
  if (in_vm && show_vm) print
  if (!in_vm) print
  next
}
/^\|.*NAME.*\|/ {
  print
  next
}
/^\|[[:space:]]*[^|]+[[:space:]]*\|/ && !/^\|.*NAME/ {
  if ($0 ~ /\-cp[[:space:]]*\|/ || $0 ~ /\-worker-[0-9]/) {
    show_vm = 1
    in_vm = 1
    print
  } else {
    show_vm = 0
    in_vm = 1
  }
  next
}
{
  if (in_vm && show_vm) print
  if (!in_vm) print
}
'

echo ""
echo "To destroy a cluster:"
echo "  task tc:destroy [-- <cluster-name>]"
echo ""

