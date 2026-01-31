#!/usr/bin/env bash
# Write the Ubuntu image to one or more USB drives
set -euo pipefail

CLI_ARGS="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  exit 1
fi
if [ -z "${USB_DISK:-}" ]; then
  echo "Error: USB_DISK variable is not defined"
  echo "Use 'task device:list-disks' to see available disks"
  exit 1
fi

# Parse disk count from CLI_ARGS
if [ -n "${CLI_ARGS}" ]; then
  eval set -- ${CLI_ARGS}
  DISK_COUNT="${1:-1}"
  if ! [[ "${DISK_COUNT}" =~ ^[0-9]+$ ]] || [ "${DISK_COUNT}" -lt 1 ]; then
    echo "Error: disk_count must be a positive integer (minimum 1)"
    echo "Usage: task device:write-ubuntu-img [-- <disk_count>]"
    exit 1
  fi
  TOTAL_DISKS=${DISK_COUNT}
else
  TOTAL_DISKS=1
fi

BASE_DISK="${USB_DISK}"
if [[ ! "${BASE_DISK}" =~ ^/dev/disk[0-9]+$ ]]; then
  echo "Error: USB_DISK must be in format /dev/disk<N> (e.g., /dev/disk4)"
  exit 1
fi
BASE_DISK_NUM="${BASE_DISK#/dev/disk}"
DISK_PREFIX="/dev/disk"

IMG_FILE="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices/ubuntu-img/ubuntu.img"
if [ ! -f "${IMG_FILE}" ]; then
  echo "Error: Ubuntu image file not found at ${IMG_FILE}"
  echo "Run 'task device:download-ubuntu-img' first to prepare the image"
  exit 1
fi

IMG_SIZE=$(stat -f%z "${IMG_FILE}" 2>/dev/null || stat -c%s "${IMG_FILE}" 2>/dev/null || echo "0")
if [ "${IMG_SIZE}" -lt 1000000 ]; then
  echo "Error: Image file appears to be too small. Please download the image first."
  exit 1
fi

echo "Image file size: $(numfmt --to=iec-i --suffix=B ${IMG_SIZE} 2>/dev/null || echo "${IMG_SIZE} bytes")"
echo ""
echo "Writing Ubuntu image to ${TOTAL_DISKS} disk(s) starting from ${BASE_DISK} in parallel..."
echo ""

declare -a PIDS DISKS LOG_FILES START_TIMES COMPLETED EXIT_CODES
for ((i=0; i<TOTAL_DISKS; i++)); do
  DISK_NUM=$((BASE_DISK_NUM + i))
  DISK="${DISK_PREFIX}${DISK_NUM}"
  DISKS[$i]="${DISK}"
  LOG_FILES[$i]="/tmp/ubuntu-img-write-${DISK_NUM}.log"
  COMPLETED[$i]="0"
  EXIT_CODES[$i]=1
  START_TIMES[$i]=$(date +%s)

  if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "${DISK}" 2>/dev/null || true
    RAW_DISK="/dev/rdisk${DISK_NUM}"
  else
    umount "${DISK}"* 2>/dev/null || true
    RAW_DISK="${DISK}"
  fi

  LOG_FILE="/tmp/ubuntu-img-write-${DISK_NUM}.log"
  echo "🚀 [${DISK}] Starting write process..."
  (
    set -euo pipefail
    sudo dd if="${IMG_FILE}" of="${RAW_DISK}" bs=4M conv=fsync status=progress 2>&1 | tee "${LOG_FILE}"
    echo "dd completed for ${DISK} with exit code: $?" >> "${LOG_FILE}"
  ) &
  PIDS[$i]=$!
done

MAX_WAIT=1800
START_TIME=$(date +%s)
LAST_UPDATE=0

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
    echo "❌ Timeout: Write process exceeded ${MAX_WAIT} seconds"
    for ((i=0; i<TOTAL_DISKS; i++)); do
      [ "${COMPLETED[$i]}" = "0" ] && kill "${PIDS[$i]}" 2>/dev/null || true
    done
    exit 1
  fi

  ALL_DONE=1
  for ((i=0; i<TOTAL_DISKS; i++)); do
    if [ "${COMPLETED[$i]}" = "0" ]; then
      ALL_DONE=0
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        wait "${PIDS[$i]}"
        EXIT_CODES[$i]=$?
        COMPLETED[$i]="1"
        DURATION=$(($(date +%s) - START_TIMES[$i]))
        if [ ${EXIT_CODES[$i]} -eq 0 ]; then
          echo "  ✅ [${DISKS[$i]}] WRITE COMPLETED SUCCESSFULLY! (${DURATION}s)"
        else
          echo "  ❌ [${DISKS[$i]}] WRITE FAILED (exit ${EXIT_CODES[$i]})"
        fi
      elif [ $((ELAPSED - LAST_UPDATE)) -ge 30 ]; then
        COMPLETED_COUNT=0
        for ((j=0; j<TOTAL_DISKS; j++)); do
          [ "${COMPLETED[$j]}" = "1" ] && COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
        done
        echo "📊 Progress: ${COMPLETED_COUNT}/${TOTAL_DISKS} completed | Elapsed: ${ELAPSED}s"
        LAST_UPDATE=${ELAPSED}
      fi
    fi
  done

  [ ${ALL_DONE} -eq 1 ] && break
  sleep 2
done

FAILED=0
for ((i=0; i<TOTAL_DISKS; i++)); do
  [ ${EXIT_CODES[$i]} -ne 0 ] && FAILED=1
done

if [ ${FAILED} -eq 1 ]; then
  echo "❌ One or more writes failed."
  exit 1
fi
echo "✅ All writes completed successfully!"
