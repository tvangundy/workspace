#!/usr/bin/env bash
# Set the VM timezone and current time to match the host machine that is deploying.
# Run after VM is up and we can exec (e.g. after setup-ssh).
set -euo pipefail

# Windsor context first, then session file
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
if command -v windsor >/dev/null 2>&1; then eval "$(windsor env 2>/dev/null)" || true; fi
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then source "${ENV_FILE}"; fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# Detect host timezone (deploying machine)
HOST_TZ=""
if command -v timedatectl >/dev/null 2>&1; then
  HOST_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || true)
fi
if [ -z "${HOST_TZ}" ] && [ -f /etc/timezone ]; then
  HOST_TZ=$(cat /etc/timezone 2>/dev/null | tr -d ' \n' || true)
fi
if [ -z "${HOST_TZ}" ] && [ -L /etc/localtime ]; then
  HOST_TZ=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || true)
fi
if [ -z "${HOST_TZ}" ] && command -v systemsetup >/dev/null 2>&1; then
  HOST_TZ=$(systemsetup -gettimezone 2>/dev/null | sed 's/Time Zone: //' | tr -d ' ' || true)
fi
if [ -z "${HOST_TZ}" ]; then
  HOST_TZ="Etc/UTC"
  echo "  Warning: Could not detect host timezone, using ${HOST_TZ}"
fi

# Host current time (YYYY-MM-DD HH:MM:SS for timedatectl set-time)
HOST_TIME=$(date +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Set VM timezone and time to match host"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Host timezone: ${HOST_TZ}"
echo "  Host time:     ${HOST_TIME}"

incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail
HOST_TZ=\"${HOST_TZ}\"
HOST_TIME=\"${HOST_TIME}\"

# Set timezone (valid IANA zone; timedatectl accepts it). incus exec runs as root.
if command -v timedatectl >/dev/null 2>&1; then
  timedatectl set-timezone \"\${HOST_TZ}\" 2>/dev/null || true
  # Set clock to match host (disable NTP briefly so set-time is allowed)
  NTP_WAS_ON=false
  if timedatectl show -p NTP --value 2>/dev/null | grep -q true; then
    NTP_WAS_ON=true
    timedatectl set-ntp false 2>/dev/null || true
  fi
  timedatectl set-time \"\${HOST_TIME}\" 2>/dev/null || true
  [ \"\${NTP_WAS_ON}\" = true ] && timedatectl set-ntp true 2>/dev/null || true
else
  # Fallback: symlink /etc/localtime (e.g. minimal container)
  if [ -f \"/usr/share/zoneinfo/\${HOST_TZ}\" ]; then
    ln -sf \"/usr/share/zoneinfo/\${HOST_TZ}\" /etc/localtime 2>/dev/null || true
  fi
fi
"

echo "  VM timezone set to ${HOST_TZ}; time synced to host (${HOST_TIME})"
