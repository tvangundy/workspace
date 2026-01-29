#!/usr/bin/env bash
# List all VMs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/vm-common.sh"

# Get the default remote name
REMOTE="${INCUS_REMOTE_NAME:-${TEST_REMOTE_NAME:-}}"
if [ -z "${REMOTE}" ]; then
  # Try to get from incus remote list (check for default or current)
  REMOTE=$(incus remote list --format csv 2>/dev/null | grep -E ",(default|current)" | cut -d',' -f1 | head -1 || echo "")
  # If still empty, try to get the first remote
  if [ -z "${REMOTE}" ]; then
    REMOTE=$(incus remote list --format csv 2>/dev/null | grep -v "^NAME," | cut -d',' -f1 | head -1 || echo "")
  fi
fi

if [ -z "${REMOTE}" ]; then
  echo "❌ Error: No Incus remote found"
  echo "   Please set INCUS_REMOTE_NAME or configure an Incus remote"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ubuntu VMs on remote '${REMOTE}'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get all VM names first to check if there are any Ubuntu VMs
ALL_VM_NAMES=$(incus list "${REMOTE}:" --format csv -c n 2>/dev/null || echo "")
if [ -z "${ALL_VM_NAMES}" ]; then
  echo "⚠️  Could not list VMs on remote '${REMOTE}'"
  echo "   Check that the remote is configured and accessible"
  exit 1
fi

# Filter out cluster VMs (ending in -cp or -worker-*)
UBUNTU_VM_NAMES=$(echo "${ALL_VM_NAMES}" | grep -v '\-cp$' | grep -v '\-worker-[0-9]' | grep -v '^NAME$' || echo "")

if [ -z "${UBUNTU_VM_NAMES}" ]; then
  echo "No VMs found."
  echo ""
  echo "To create a VM:"
  echo "  task vm:instantiate -- <remote-name> [<vm-name>]"
  exit 0
fi

# List all VMs on the remote, excluding Talos cluster VMs
# Filter out VMs ending in -cp or -worker-* (these are Talos cluster VMs)
# Use awk to preserve table formatting
incus list "${REMOTE}:" --format table 2>/dev/null | awk '
BEGIN { in_vm = 0; skip_vm = 0 }
/^\+/ {
  if (in_vm && !skip_vm) print
  if (!in_vm) print
  next
}
/^\|.*NAME.*\|/ {
  print
  next
}
/^\|[[:space:]]*[^|]+[[:space:]]*\|/ && !/^\|.*NAME/ {
  if ($0 ~ /\-cp[[:space:]]*\|/ || $0 ~ /\-worker-[0-9]/) {
    skip_vm = 1
    in_vm = 1
  } else {
    skip_vm = 0
    in_vm = 1
    print
  }
  next
}
{
  if (in_vm && !skip_vm) print
  if (!in_vm) print
}
'

echo ""
echo "To destroy a VM:"
echo "  task vm:destroy [-- <vm-name>]"
echo ""

