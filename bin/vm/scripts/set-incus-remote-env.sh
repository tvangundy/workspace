#!/usr/bin/env bash
# Set INCUS_REMOTE_NAME, INCUS_REMOTE_IP, and INCUS_REMOTE_TOKEN on the VM system-wide (/etc/environment)
# so all users have the instantiation-time remote name, IP, and trust token available.
# INCUS_REMOTE_IP is taken from the mandatory argument passed to vm:instantiate (see parse-args.sh).
# INCUS_REMOTE_TOKEN is generated on the host and written to the VM for adding the remote.
set -euo pipefail

# Ensure incus is available (Task may run with a minimal PATH)
if ! command -v incus >/dev/null 2>&1; then
  echo "Error: incus not found in PATH. Ensure Incus client is installed and in PATH." >&2
  exit 127
fi

# Load environment variables from file (written by vm parse-args with mandatory remote-ip)
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# INCUS_REMOTE_IP is mandatory and set by vm:instantiate -- <remote> <remote-ip> [<vm-name>] ...
if [ -z "${INCUS_REMOTE_IP:-}" ]; then
  echo "Error: INCUS_REMOTE_IP is not set. Pass <remote-ip> to vm:instantiate." >&2
  echo "Usage: task vm:instantiate -- <incus-remote-name> <remote-ip> [<vm-name>] [--destroy] [--windsor-up]" >&2
  exit 1
fi

# Get the Incus remote trust token (for VM to add remote) and store it in the VM's environment.
# CRITICAL: Create the token on the same remote where the VM lives. The fallback to default remote
# caused "No matching certificate add operation found" when the host's default was a different server.
INCUS_REMOTE_TOKEN=""
CLIENT_NAME="${VM_NAME}"
PREV_REMOTE=""
set +e
# Switch host to target remote so trust add runs on the correct server (token must exist on VM's server)
if incus remote list --format csv -c n 2>/dev/null | grep -q "^${TEST_REMOTE_NAME}$"; then
  PREV_REMOTE=$(incus remote get-default 2>/dev/null || echo "")
  incus remote switch "${TEST_REMOTE_NAME}" 2>/dev/null || true
fi
TRUST_OUTPUT=$(incus config trust add "${CLIENT_NAME}" 2>&1 || echo "")
# Restore previous default remote (avoid switching if already on target or prev was empty)
if [ -n "${PREV_REMOTE}" ] && [ "${PREV_REMOTE}" != "${TEST_REMOTE_NAME}" ]; then
  incus remote switch "${PREV_REMOTE}" 2>/dev/null || true
fi
INCUS_REMOTE_TOKEN=$(echo "${TRUST_OUTPUT}" | awk '/token:/ {getline; print}' | head -1 | tr -d '[:space:]' || echo "")
if [ -z "${INCUS_REMOTE_TOKEN}" ] || [ "${#INCUS_REMOTE_TOKEN}" -lt 64 ]; then
  INCUS_REMOTE_TOKEN=$(echo "${TRUST_OUTPUT}" | grep -oE '[a-zA-Z0-9_-]{64,}' | head -1 || echo "")
fi
set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Set Incus remote env on VM (system-wide)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  INCUS_REMOTE_NAME=${TEST_REMOTE_NAME}"
echo "  INCUS_REMOTE_IP=${INCUS_REMOTE_IP:-<unknown>}"
echo "  INCUS_REMOTE_TOKEN=${INCUS_REMOTE_TOKEN:+<set>}"

# Write to VM /etc/environment so all users get these at login (idempotent)
# Pass name and IP as args; pass token via env to avoid quoting issues
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- env INCUS_REMOTE_TOKEN="${INCUS_REMOTE_TOKEN:-}" bash -c '
set -euo pipefail
R_NAME="${1:-}"
R_IP="${2:-}"
R_TOKEN="${INCUS_REMOTE_TOKEN:-}"
if [ -f /etc/environment ]; then
  grep -v -E "^INCUS_REMOTE_NAME=|^INCUS_REMOTE_IP=|^INCUS_REMOTE_TOKEN=" /etc/environment > /etc/environment.tmp || true
  mv /etc/environment.tmp /etc/environment
fi
echo "INCUS_REMOTE_NAME=\"${R_NAME}\"" >> /etc/environment
echo "INCUS_REMOTE_IP=\"${R_IP}\"" >> /etc/environment
if [ -n "${R_TOKEN}" ]; then
  R_TOKEN_ESCAPED=$(printf "%s" "${R_TOKEN}" | sed "s/\"/\\\\\"/g")
  echo "INCUS_REMOTE_TOKEN=\"${R_TOKEN_ESCAPED}\"" >> /etc/environment
fi
echo "  Written to /etc/environment on VM"
' _ "${TEST_REMOTE_NAME}" "${INCUS_REMOTE_IP:-}"

if [ -n "${INCUS_REMOTE_TOKEN:-}" ]; then
  echo "✅ INCUS_REMOTE_NAME, INCUS_REMOTE_IP, and INCUS_REMOTE_TOKEN set on VM (available to all users)"
else
  echo "✅ INCUS_REMOTE_NAME and INCUS_REMOTE_IP set on VM (INCUS_REMOTE_TOKEN not set; trust token generation may have failed)"
fi
