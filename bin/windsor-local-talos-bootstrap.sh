#!/usr/bin/env bash
# Windsor Local Talos TLS First-Apply Bootstrap
#
# On first boot, Talos nodes use self-signed TLS certs. The Terraform Talos provider
# cannot verify these, causing "x509: certificate signed by unknown authority".
#
# Run this script AFTER windsor up fails with that TLS error. It will:
#   1. Extract the control plane config from Terraform
#   2. Apply it via talosctl --insecure (from inside the control plane's network namespace)
#   3. Retry windsor up
#
# Usage: run from the Windsor project root (where windsor init local was run)
#   ./bin/windsor-local-talos-bootstrap.sh
#
# Options:
#   --apply-only [FILE]  Only run apply-config; use FILE if given (else extract)
#   --ensure-pki         Re-apply control plane config with talosconfig (fixes PKI mismatch)
#
# Environment:
#   TARGET_DIR              - Windsor project root (default: $PWD)
#   CONTROL_PLANE_ENDPOINT  - e.g. 127.0.0.1:50000
#   CONTROL_PLANE_CONTAINER - Docker container name (default: controlplane-1.test)
#   TALOS_VERSION           - Talos/talosctl version (default: v1.11.5)

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-$PWD}"
CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT:-127.0.0.1:50000}"
CONTROL_PLANE_CONTAINER="${CONTROL_PLANE_CONTAINER:-controlplane-1.test}"
TALOS_VERSION="${TALOS_VERSION:-v1.11.5}"

cd "${TARGET_DIR}"

log() { echo "[windsor-local-talos-bootstrap] $*"; }

# Return 0 if $1 looks like a valid Talos endpoint (IP or IP:port)
is_valid_endpoint() {
  local e
  e="$(echo "$1" | tr -d '\n\r\t[:space:]')"
  [[ "$e" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] || [[ "$e" =~ ^[a-zA-Z0-9._-]+(:[0-9]+)?$ ]]
}

# Find the Talos Terraform module directory
find_talos_terraform_dir() {
  for base in .windsor/contexts/local .windsor; do
    if [ -d "$base" ]; then
      local dir
      dir=$(find "$base" -type d -path '*terraform*cluster*talos*' 2>/dev/null | head -1)
      [ -z "$dir" ] && dir=$(find "$base" -type d -path '*cluster*talos*' 2>/dev/null | head -1)
      [ -z "$dir" ] && dir=$(find "$base" -name "main.tf" -exec grep -l "talos" {} \; 2>/dev/null | head -1 | xargs dirname)
      if [ -n "$dir" ] && [ -f "$dir/main.tf" ]; then
        echo "$dir"
        return 0
      fi
    fi
  done
  return 1
}

# Extract control plane config from Terraform output, state, console, or disk
# tf_dir: Talos terraform dir (e.g. .windsor/contexts/local/terraform/cluster/talos)
extract_controlplane_config() {
  local tf_dir="$1"
  local out_file="$2"
  local config=""
  local ctx_dir
  ctx_dir=$(cd "$tf_dir" && cd ../../.. 2>/dev/null && pwd)  # context root (e.g. .windsor/contexts/local)

  # 1. Terraform outputs (various naming conventions)
  for out_name in controlplane_config control_plane_config controlplane_machine_configuration machine_configuration_controlplane; do
    if config=$(cd "$tf_dir" && terraform output -raw "$out_name" 2>/dev/null) && [ -n "$config" ] && [ "$config" != "null" ]; then
      echo "$config" > "$out_file"
      return 0
    fi
  done

  # 2. Terraform console (Windsor OCI: module.main wraps the core)
  # Windsor may run terraform from contexts/local with -chdir; try both tf_dir and context root
  local var_file=""
  [ -f "$tf_dir/terraform.tfvars" ] && var_file="-var-file=$tf_dir/terraform.tfvars"
  local work_dirs="$tf_dir"
  [ -d "$ctx_dir" ] && work_dirs="$tf_dir $ctx_dir"
  for work in $work_dirs; do
    [ -f "$work/terraform.tfvars" ] && var_file="-var-file=$work/terraform.tfvars"
    break
  done
  for work in $work_dirs; do
  for expr in \
    "module.main.module.controlplane_bootstrap.data.talos_machine_configuration.this.machine_configuration" \
    "module.main.data.talos_machine_configuration.this.machine_configuration" \
    "module.main.data.talos_machine_configuration.controlplane.machine_configuration" \
    "module.controlplane_bootstrap.data.talos_machine_configuration.this.machine_configuration" \
    "data.talos_machine_configuration.this.machine_configuration" \
    "data.talos_machine_configuration.controlplane.machine_configuration"; do
    config=$(cd "$work" && echo "$expr" | terraform console $var_file -input=false 2>/dev/null) || true
    # Terraform may wrap string in quotes; strip leading/trailing quotes and unescape
    config=$(printf '%s' "$config" | sed 's/^"//;s/"$//' | sed 's/\\n/\n/g' 2>/dev/null)
    if [ -n "$config" ] && [ "$config" != "null" ] && echo "$config" | head -5 | grep -qE '^machine:|^cluster:'; then
      echo "$config" > "$out_file"
      return 0
    fi
  done
  done

  # 3. Terraform state (direct file read or terraform state pull)
  # Windsor stores state in .tfstate/cluster/talos; terraform state pull needs init
  local state_json=""
  for state_path in \
    "$ctx_dir/.tfstate/cluster/talos/terraform.tfstate" \
    "$tf_dir/terraform.tfstate" \
    ".windsor/contexts/local/.tfstate/cluster/talos/terraform.tfstate"; do
    if [ -f "$state_path" ]; then
      state_json=$(<"$state_path") 2>/dev/null || state_json=$(cat "$state_path" 2>/dev/null)
      [ -n "$state_json" ] && break
    fi
  done
  if [ -z "$state_json" ]; then
    for work in $work_dirs; do
      state_json=$(cd "$work" && terraform state pull 2>/dev/null) || true
      [ -n "$state_json" ] && [ "$state_json" != "null" ] && break
    done
  fi
  if [ -n "$state_json" ] && [ "$state_json" != "null" ]; then
    if command -v jq &>/dev/null; then
      # Prefer controlplane_bootstrap; fallback to first talos_machine_configuration
      config=$(echo "$state_json" | jq -r '
        .resources[] | select(.type == "talos_machine_configuration" and ((.module // "") | contains("controlplane"))) |
        .instances[0].attributes.machine_configuration // .instances[0].attributes.result // empty
      ' 2>/dev/null | head -1)
      [ -z "$config" ] && config=$(echo "$state_json" | jq -r '
        .resources[] | select(.type == "talos_machine_configuration") |
        .instances[0].attributes.machine_configuration // .instances[0].attributes.result // empty
      ' 2>/dev/null | head -1)
      [ -n "$config" ] && [ "$config" != "null" ] && echo "$config" > "$out_file" && return 0
    fi
    if command -v python3 &>/dev/null; then
      config=$(echo "$state_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for r in d.get("resources", []):
  if r.get("type") == "talos_machine_configuration" and r.get("instances"):
    attrs = r["instances"][0].get("attributes", {})
    cfg = attrs.get("machine_configuration") or attrs.get("result", "")
    if cfg and ("machine:" in cfg or "cluster:" in cfg):
      print(cfg)
      sys.exit(0)
' 2>/dev/null)
      [ -n "$config" ] && echo "$config" > "$out_file" && return 0
    fi
  fi

  # 4. controlplane.yaml on disk
  for base in "$tf_dir" "$(dirname "$tf_dir")" .windsor/contexts/local .windsor .windsor/.oci_extracted/ghcr.io-windsorcli/core-v0.6.0/terraform/cluster/talos; do
    [ -d "$base" ] || continue
    for f in controlplane.yaml control-plane.yaml; do
      if [ -f "$base/$f" ] && head -5 "$base/$f" 2>/dev/null | grep -qE '^machine:|^cluster:'; then
        cp "$base/$f" "$out_file"
        return 0
      fi
    done
  done

  log "Tried: terraform output, terraform console, terraform state, disk files"
  return 1
}

# Apply control plane config via talosctl --insecure from inside the control plane's network
# Uses docker run --network container:<cp> so 127.0.0.1:50001 = maintenance port
apply_config_via_container() {
  local config_file="$1"

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTROL_PLANE_CONTAINER}$"; then
    log "Control plane container '${CONTROL_PLANE_CONTAINER}' not found. Is windsor up running?"
    docker ps --format '{{.Names}}' | grep -E 'controlplane|talos' || true
    return 1
  fi

  local arch
  arch=$(docker run --rm alpine uname -m 2>/dev/null | sed 's/aarch64/arm64/;s/x86_64/amd64/')
  [ -z "$arch" ] && arch="amd64"

  log "Applying control plane config via container network (127.0.0.1:50001 = maintenance port)..."
  if docker run --rm -i \
    --network "container:${CONTROL_PLANE_CONTAINER}" \
    alpine sh -c "
      apk add --no-cache curl
      curl -sSLo /usr/local/bin/talosctl \"https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-${arch}\"
      chmod +x /usr/local/bin/talosctl
      talosctl apply-config --insecure --nodes 127.0.0.1:50001 --file /dev/stdin
    " < "$config_file"; then
    log "Config applied. Waiting 60s for node to apply..."
    sleep 60
    return 0
  fi

  return 1
}

# --- Main ---

if [[ "${1:-}" == "--ensure-pki" ]]; then
  log "Ensure-PKI mode: re-applying control plane config with talosconfig..."
  tf_dir=$(find_talos_terraform_dir) || { log "Could not find Talos Terraform directory"; exit 1; }
  config_file=$(mktemp)
  trap 'rm -f "$config_file"' EXIT
  extract_controlplane_config "$tf_dir" "$config_file" || { log "Could not extract control plane config"; exit 1; }
  if command -v talosctl &>/dev/null && [ -f "contexts/local/.talos/config" ]; then
    endpoint="${CONTROL_PLANE_ENDPOINT}"
    [[ "$endpoint" != *:* ]] && endpoint="${endpoint}:50000"
    talosctl apply-config --talosconfig contexts/local/.talos/config --nodes "$endpoint" --file "$config_file" || exit 1
  else
    apply_config_via_container "$config_file" || exit 1
  fi
  log "Ensure-PKI complete."
  exit 0
fi

if [[ "${1:-}" == "--apply-only" ]]; then
  log "Apply-only mode: extracting config and applying..."
  tf_dir=$(find_talos_terraform_dir) || { log "Could not find Talos Terraform directory"; exit 1; }
  config_file=$(mktemp)
  trap 'rm -f "$config_file"' EXIT
  if [[ -n "${2:-}" && -f "${2}" ]]; then
    cp "$2" "$config_file"
    log "Using config file: $2"
  else
    extract_controlplane_config "$tf_dir" "$config_file" || { log "Could not extract control plane config"; exit 1; }
  fi
  apply_config_via_container "$config_file" || exit 1
  log "Apply complete. Run 'windsor up' to retry."
  exit 0
fi

# Full flow: extract, apply, retry windsor up
log "TLS first-apply bootstrap..."

tf_dir=$(find_talos_terraform_dir) || { log "Could not find Talos Terraform directory under .windsor"; exit 1; }
log "Using Terraform dir: $tf_dir"

config_file=$(mktemp)
trap 'rm -f "$config_file"' EXIT

extract_controlplane_config "$tf_dir" "$config_file" || {
  log "Could not extract control plane config. Ensure windsor up reached the Terraform apply step."
  exit 1
}

apply_config_via_container "$config_file" || {
  log "talosctl apply-config failed. If you see 'unknown service machine.MachineService',"
  log "the node may have already left maintenance mode. Try: windsor down; docker volume prune -f; windsor up"
  log "Then run this script immediately when Terraform starts failing."
  exit 1
}

log "Retrying windsor up..."
if command -v script &>/dev/null; then
  script -q -c "windsor up" /dev/null || exit 1
else
  windsor up || exit 1
fi

log "Bootstrap complete. Cluster is up."
