#!/usr/bin/env bash
# Generate terraform.tfvars from environment variables
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Determine WINDSOR_CONTEXT - use active context if available, otherwise use CLUSTER_NAME
WINDSOR_CONTEXT="${WINDSOR_CONTEXT:-}"
if [ -z "${WINDSOR_CONTEXT}" ]; then
  # Check for active Windsor context
  if command -v windsor > /dev/null 2>&1; then
    WINDSOR_CONTEXT=$(windsor context get 2>/dev/null || echo "")
  fi
fi
# Fallback to CLUSTER_NAME if still not set
if [ -z "${WINDSOR_CONTEXT}" ] && [ -n "${CLUSTER_NAME}" ]; then
  WINDSOR_CONTEXT="${CLUSTER_NAME}"
fi
if [ -z "${WINDSOR_CONTEXT}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  echo "Set the context using: windsor context set <context>"
  exit 1
fi

if [ -z "${REMOTE_NAME}" ]; then
  echo "Error: INCUS_REMOTE_NAME variable is not defined"
  exit 1
fi

if [ -z "${CLUSTER_NAME}" ]; then
  echo "Error: CLUSTER_NAME variable is not defined"
  exit 1
fi

if [ -z "${TALOS_IMAGE_VERSION:-}" ]; then
  echo "Error: TALOS_IMAGE_VERSION variable is not defined"
  exit 1
fi

if [ -z "${TALOSCONFIG:-}" ]; then
  echo "Error: TALOSCONFIG environment variable is not defined"
  echo "Set TALOSCONFIG in contexts/${WINDSOR_CONTEXT}/windsor.yaml"
  exit 1
fi

if [ -z "${KUBECONFIG_FILE:-}" ]; then
  echo "Error: KUBECONFIG_FILE environment variable is not defined"
  echo "Set KUBECONFIG_FILE in contexts/${WINDSOR_CONTEXT}/windsor.yaml"
  exit 1
fi

CONTROL_PLANE_VM="${CONTROL_PLANE_VM:-talos-cp}"
WORKER_0_VM="${WORKER_0_VM:-talos-worker-0}"
WORKER_1_VM="${WORKER_1_VM:-talos-worker-1}"
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-}"
WORKER_0_IP="${WORKER_0_IP:-}"
WORKER_1_IP="${WORKER_1_IP:-}"
# MAC addresses for fixed IP assignment via DHCP reservations
CONTROL_PLANE_MAC="${CONTROL_PLANE_MAC:-10:66:6a:9d:c1:d6}"
WORKER_0_MAC="${WORKER_0_MAC:-10:66:6a:ef:12:03}"
WORKER_1_MAC="${WORKER_1_MAC:-10:66:6a:32:10:2f}"
CONTROL_PLANE_MEMORY="${CONTROL_PLANE_MEMORY:-2GB}"
CONTROL_PLANE_CPU="${CONTROL_PLANE_CPU:-2}"
WORKER_MEMORY="${WORKER_MEMORY:-2GB}"
WORKER_CPU="${WORKER_CPU:-2}"
PHYSICAL_NETWORK_NAME="${PHYSICAL_INTERFACE:-eno1}"
STORAGE_POOL="${STORAGE_POOL:-local}"
COMMON_CONFIG_PATCHES="${COMMON_CONFIG_PATCHES:-}"
TALOS_IMAGE_ALIAS="talos-${TALOS_IMAGE_VERSION}-metal-amd64"

TFVARS_DIR="${TERRAFORM_DIR}"
TFVARS_FILE="${TFVARS_DIR}/terraform.tfvars"
mkdir -p "${TFVARS_DIR}"

{
  printf "# Generated from environment variables - do not edit manually\n"
  printf "# Update environment variables in contexts/%s/windsor.yaml instead\n" "${WINDSOR_CONTEXT}"
  printf "\n"
  printf "# Incus remote configuration\n"
  printf "incus_remote_name = \"%s\"\n" "${REMOTE_NAME}"
  printf "\n"
  printf "# Cluster configuration\n"
  printf "cluster_name = \"%s\"\n" "${CLUSTER_NAME}"
  printf "\n"
  printf "# VM names\n"
  printf "control_plane_vm_name = \"%s\"\n" "${CONTROL_PLANE_VM}"
  printf "worker_0_vm_name      = \"%s\"\n" "${WORKER_0_VM}"
  printf "worker_1_vm_name      = \"%s\"\n" "${WORKER_1_VM}"
  printf "\n"
  printf "# IP addresses (expected IPs - actual IPs will be assigned by DHCP)\n"
  printf "# Leave empty for new installations - Terraform will prompt you to fill them in\n"
  printf "control_plane_ip = \"%s\"\n" "${CONTROL_PLANE_IP}"
  printf "worker_0_ip      = \"%s\"\n" "${WORKER_0_IP}"
  printf "worker_1_ip      = \"%s\"\n" "${WORKER_1_IP}"
  printf "\n"
  printf "# MAC addresses (optional - leave empty for auto-assignment)\n"
  printf "# Set these to ensure VMs get the same MAC address when recreated\n"
  printf "# Get MACs with: incus list <remote>:<vm> --format json\n"
  printf "control_plane_mac = \"%s\"\n" "${CONTROL_PLANE_MAC:-}"
  printf "worker_0_mac      = \"%s\"\n" "${WORKER_0_MAC:-}"
  printf "worker_1_mac      = \"%s\"\n" "${WORKER_1_MAC:-}"
  printf "\n"
  printf "# VM resources\n"
  printf "control_plane_memory = \"%s\"\n" "${CONTROL_PLANE_MEMORY}"
  printf "control_plane_cpu    = \"%s\"\n" "${CONTROL_PLANE_CPU}"
  printf "worker_memory        = \"%s\"\n" "${WORKER_MEMORY}"
  printf "worker_cpu           = \"%s\"\n" "${WORKER_CPU}"
  printf "\n"
  printf "# Talos image alias (generated from TALOS_IMAGE_VERSION)\n"
  printf "talos_image_alias = \"%s\"\n" "${TALOS_IMAGE_ALIAS}"
  printf "\n"
  printf "# Talos version\n"
  printf "talos_version = \"%s\"\n" "${TALOS_IMAGE_VERSION}"
  printf "\n"
  printf "# Physical network interface name\n"
  printf "physical_network_name = \"%s\"\n" "${PHYSICAL_NETWORK_NAME}"
  printf "\n"
  printf "# Storage pool name\n"
  printf "storage_pool = \"%s\"\n" "${STORAGE_POOL}"
  printf "\n"
  printf "# Configuration file paths (from environment variables)\n"
  printf "talosconfig_path = \"%s\"\n" "${TALOSCONFIG}"
  printf "kubeconfig_file = \"%s\"\n" "${KUBECONFIG_FILE}"
  printf "\n"
  printf "# Common configuration patches (optional)\n"
  if [ -n "${COMMON_CONFIG_PATCHES}" ]; then
    printf "common_config_patches = <<EOF_PATCH\n"
    printf "%s\n" "${COMMON_CONFIG_PATCHES}"
    printf "EOF_PATCH\n"
  else
    printf "common_config_patches = \"\"\n"
  fi
} > "${TFVARS_FILE}"

echo "✅ Generated ${TFVARS_FILE} from environment variables"

