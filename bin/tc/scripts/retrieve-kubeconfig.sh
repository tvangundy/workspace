#!/usr/bin/env bash
# Retrieve kubeconfig from cluster, fix server URL, wait for nodes Ready.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Set additional variables needed by this script
PROJECT_ROOT=$(get_windsor_project_root)

# Context directory: WINDSOR_CONTEXT takes precedence over CLUSTER_NAME
TEST_CONTEXT_DIR=$(get_tc_context_dir "${PROJECT_ROOT}" "${CLUSTER_NAME}")

TALOSCONFIG_PATH="${TEST_CONTEXT_DIR}/.talos/talosconfig"
KUBECONFIG_FILE_PATH="${TEST_CONTEXT_DIR}/.kube/config"

log_step "Retrieving kubeconfig and waiting for all nodes to become Ready"

CONTROL_PLANE_IP=""
if [ -d "${TERRAFORM_DIR}" ]; then
  cd "${TERRAFORM_DIR}"
  # Ensure we're using the correct workspace for this cluster
  CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
  if [ "${CURRENT_WORKSPACE}" != "${CLUSTER_NAME}" ]; then
    if terraform workspace list 2>/dev/null | grep -q "^[[:space:]]*${CLUSTER_NAME}$"; then
      terraform workspace select "${CLUSTER_NAME}"
    fi
  fi
  CONTROL_PLANE_IP=$(terraform output -raw control_plane_ip 2>/dev/null || echo "")
  cd - >/dev/null
fi
if [ -z "${CONTROL_PLANE_IP}" ]; then
  echo "❌ CONTROL_PLANE_IP not set"
  exit 1
fi

[ ! -f "${TALOSCONFIG_PATH}" ] && echo "❌ talosconfig not found at ${TALOSCONFIG_PATH}" && exit 1
mkdir -p "$(dirname "${KUBECONFIG_FILE_PATH}")"

# Retrieve kubeconfig - talosctl succeeds as soon as the cluster is ready
# Use timeout so failed attempts fail fast and we retry sooner
echo "Retrieving kubeconfig from ${CONTROL_PLANE_IP}..."
MAX_WAIT=300  # 5 minutes for slow bootstrap
TRY_TIMEOUT=15  # seconds per attempt - fail fast so we retry sooner

# Use timeout if available (GNU coreutils, or gtimeout on macOS with coreutils)
TALOSCTL_CMD=(talosctl kubeconfig "${KUBECONFIG_FILE_PATH}" --talosconfig "${TALOSCONFIG_PATH}" --nodes "${CONTROL_PLANE_IP}")
if command -v timeout >/dev/null 2>&1; then
  RUN_CMD=(timeout ${TRY_TIMEOUT} "${TALOSCTL_CMD[@]}")
elif command -v gtimeout >/dev/null 2>&1; then
  RUN_CMD=(gtimeout ${TRY_TIMEOUT} "${TALOSCTL_CMD[@]}")
else
  RUN_CMD=("${TALOSCTL_CMD[@]}")
fi

START_TS=$(date +%s)
while true; do
  if "${RUN_CMD[@]}" > /tmp/tc_kubeconfig.log 2>&1; then
    break
  fi
  ELAPSED=$(($(date +%s) - START_TS))
  [ ${ELAPSED} -ge ${MAX_WAIT} ] && break
  sleep 3
  ELAPSED=$(($(date +%s) - START_TS))
  printf "\r  Waiting for cluster... (%ds/%ds)" "${ELAPSED}" "${MAX_WAIT}"
done
echo ""

if [ ! -f "${KUBECONFIG_FILE_PATH}" ]; then
  echo "⚠️  Could not retrieve kubeconfig"
  if [ -f /tmp/tc_kubeconfig.log ]; then
    echo "   Error output:"
    head -20 /tmp/tc_kubeconfig.log | sed 's/^/     /'
  fi
  echo ""
  echo "   Try manually (must use -n with a single control plane IP):"
  echo "     talosctl kubeconfig ${KUBECONFIG_FILE_PATH} \\"
  echo "       --talosconfig ${TALOSCONFIG_PATH} \\"
  echo "       -n ${CONTROL_PLANE_IP}"
  echo ""
  if [ -f /tmp/tc_kubeconfig.log ] && grep -q "unknown authority\|certificate signed" /tmp/tc_kubeconfig.log 2>/dev/null; then
    echo "   TLS/certificate error: talosconfig may not match the cluster's certificates."
    echo "   This can happen after orphaned VMs were destroyed and recreated."
    echo "   Fix: Run 'task tc:destroy' to fully tear down, then 'task instantiate:dev-cluster' to recreate."
  fi
  exit 1
fi

if [[ "$(uname)" = "Darwin" ]]; then
  sed -i '' "s|server: https://[^:]*:6443|server: https://${CONTROL_PLANE_IP}:6443|g" "${KUBECONFIG_FILE_PATH}"
else
  sed -i "s|server: https://[^:]*:6443|server: https://${CONTROL_PLANE_IP}:6443|g" "${KUBECONFIG_FILE_PATH}"
fi

echo "✅ kubeconfig at ${KUBECONFIG_FILE_PATH}"

export KUBECONFIG="${KUBECONFIG_FILE_PATH}"

  # Wait for nodes to become Ready
  echo "Waiting for all nodes to become Ready..."
  MAX_NODES=600  # 10 minutes - nodes usually Ready within 5-8 minutes after bootstrap
  ELAPSED=0
  while [ ${ELAPSED} -lt ${MAX_NODES} ]; do
    # Wrap loop body in error handling to prevent premature exits
    set +e  # Temporarily disable exit on error for kubectl and arithmetic operations
    
    # Use JSON output for reliable parsing
    NODES_JSON=$(kubectl get nodes -o json --request-timeout=5s 2>/dev/null)
    KUBECTL_EXIT=$?
    
    READY=0
    TOTAL=0
    
    if [ ${KUBECTL_EXIT} -eq 0 ] && [ -n "${NODES_JSON}" ]; then
      # Parse JSON to count nodes and Ready nodes
      # Check if jq is available, if not fall back to text parsing
      if command -v jq >/dev/null 2>&1; then
        TOTAL=$(echo "${NODES_JSON}" | jq -r '.items | length' 2>/dev/null || echo "0")
        # Count nodes where status.conditions contains a condition with type="Ready" and status="True"
        READY=$(echo "${NODES_JSON}" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True")) | .metadata.name' 2>/dev/null | wc -l | awk '{print $1}' || echo "0")
      else
        # Fallback to text parsing if jq is not available
        OUT=$(kubectl get nodes --no-headers --request-timeout=5s 2>/dev/null)
        if [ -n "${OUT}" ] && ! echo "${OUT}" | grep -qiE "no resources found|no.*found"; then
          NODE_LINES=$(echo "${OUT}" | grep -vE "^[[:space:]]*$" | grep -vE "^Error|^Unable|^time=" | grep -E "^[a-zA-Z0-9]" || echo "")
          if [ -n "${NODE_LINES}" ]; then
            TOTAL=$(echo "${NODE_LINES}" | wc -l | awk '{print $1}')
            READY=$(echo "${NODE_LINES}" | awk '{gsub(/[[:space:]]+/, " "); if($2 ~ /^Ready/ || $2 == "Ready") count++} END {print count+0}' 2>/dev/null || echo "0")
          fi
        fi
      fi
      
      # Ensure values are numeric (sanitize first)
      READY=$(echo "${READY}" | tr -d '[:space:]' || echo "0")
      TOTAL=$(echo "${TOTAL}" | tr -d '[:space:]' || echo "0")
      READY=$((READY + 0))
      TOTAL=$((TOTAL + 0))
    fi
    
    set -e
    
    # Check pod status - simpler approach: check if any pods are NOT Running or Succeeded
    set +e
    ALL_PODS_RUNNING=false
    TOTAL_PODS=0
    RUNNING_PODS=0
    
    # Use JSON output for reliable parsing
    PODS_JSON=$(kubectl get pods -n kube-system -o json --request-timeout=5s 2>/dev/null)
    POD_CHECK_EXIT=$?
    
    if [ ${POD_CHECK_EXIT} -eq 0 ] && [ -n "${PODS_JSON}" ]; then
      if command -v jq >/dev/null 2>&1; then
        # Count total pods
        TOTAL_PODS=$(echo "${PODS_JSON}" | jq -r '.items | length' 2>/dev/null || echo "0")
        
        # Count pods that are Running or Succeeded
        RUNNING_PODS=$(echo "${PODS_JSON}" | jq -r '.items[] | select(.status.phase == "Running" or .status.phase == "Succeeded") | .metadata.name' 2>/dev/null | wc -l | awk '{print $1}' || echo "0")
        
        # If all pods are Running or Succeeded, we're done
        if [ "${TOTAL_PODS}" -gt 0 ] && [ "${RUNNING_PODS}" -eq "${TOTAL_PODS}" ]; then
          ALL_PODS_RUNNING=true
        fi
      else
        # Fallback to text parsing if jq is not available
        POD_OUTPUT=$(kubectl get pods -n kube-system --no-headers 2>/dev/null)
        if [ -n "${POD_OUTPUT}" ]; then
          TOTAL_PODS=$(echo "${POD_OUTPUT}" | grep -vE "^[[:space:]]*$" | wc -l | awk '{print $1}' || echo "0")
          # Count pods that are Running or Completed
          RUNNING_PODS=$(echo "${POD_OUTPUT}" | grep -cE " Running | Completed " 2>/dev/null || echo "0")
          
          if [ "${TOTAL_PODS}" -gt 0 ] && [ "${RUNNING_PODS}" -eq "${TOTAL_PODS}" ]; then
            ALL_PODS_RUNNING=true
          fi
        fi
      fi
      
      # Ensure values are numeric
      TOTAL_PODS=$((TOTAL_PODS + 0)) || TOTAL_PODS=0
      RUNNING_PODS=$((RUNNING_PODS + 0)) || RUNNING_PODS=0
    fi
    
    set -e
    
    # Primary check: If all pods are running, consider cluster ready
    # Secondary check: Also verify nodes are Ready if possible
    if [ "${ALL_PODS_RUNNING}" = "true" ] && [ "${TOTAL}" -ge 3 ]; then
        # Kubernetes nodes are Ready and all pods are running, now verify Talos nodes are also ready
        # Get worker IPs from environment or Terraform (only once)
        if [ -z "${WORKER_0_IP:-}" ] || [ -z "${WORKER_1_IP:-}" ]; then
          if [ -d "${TERRAFORM_DIR}" ]; then
            cd "${TERRAFORM_DIR}"
            # Ensure we're using the correct workspace for this cluster
            CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
            if [ "${CURRENT_WORKSPACE}" != "${CLUSTER_NAME}" ]; then
              if terraform workspace list 2>/dev/null | grep -q "^[[:space:]]*${CLUSTER_NAME}$"; then
                terraform workspace select "${CLUSTER_NAME}"
              fi
            fi
            WORKER_0_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_0"] // ""' 2>/dev/null || echo "")
            WORKER_1_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_1"] // ""' 2>/dev/null || echo "")
            cd - >/dev/null
          fi
        fi
        
        # All pods are running and all nodes are Ready - cluster is ready!
        # Talos health checks are optional and can be slow, so we exit immediately
        echo ""
        echo "✅ All system pods running"
        echo "✅ All 3 Kubernetes nodes Ready"
        unset KUBECONFIG
        exit 0
    fi
  
  # Show pod status every 30 seconds
  if [ $((ELAPSED % 30)) -eq 0 ] && [ ${ELAPSED} -gt 0 ]; then
    echo ""
    set +e
    POD_OUTPUT=$(kubectl get pods -n kube-system --no-headers 2>/dev/null)
    if [ -n "${POD_OUTPUT}" ]; then
      RUNNING=$(echo "${POD_OUTPUT}" | grep -cE " Running " 2>/dev/null || echo "0")
      PENDING=$(echo "${POD_OUTPUT}" | grep -cE " Pending " 2>/dev/null || echo "0")
      TOTAL_PODS_DISPLAY=$(echo "${POD_OUTPUT}" | wc -l | awk '{print $1}')
      # Sanitize values for display
      RUNNING=$(echo "${RUNNING}" | tr -d '[:space:]' || echo "0")
      PENDING=$(echo "${PENDING}" | tr -d '[:space:]' || echo "0")
      TOTAL_PODS_DISPLAY=$(echo "${TOTAL_PODS_DISPLAY}" | tr -d '[:space:]' || echo "0")
      RUNNING=$((RUNNING + 0)) || RUNNING=0
      PENDING=$((PENDING + 0)) || PENDING=0
      TOTAL_PODS_DISPLAY=$((TOTAL_PODS_DISPLAY + 0)) || TOTAL_PODS_DISPLAY=0
      echo "  System pods: ${RUNNING} Running, ${PENDING} Pending (${TOTAL_PODS_DISPLAY} total)"
      echo "${POD_OUTPUT}" | head -10 | awk '{printf "    %-45s %-12s %s\n", $1, $3, $2}'
      if [ "${TOTAL_PODS_DISPLAY}" -gt 10 ]; then
        echo "    ... and $((TOTAL_PODS_DISPLAY - 10)) more"
      fi
    else
      echo "  System pods: (no pods found yet)"
    fi
    set -e
  fi
  
  # Update elapsed time and display status
  sleep 15
  ELAPSED=$((ELAPSED + 15))
  
  # Use the same integer values for display consistency (safe arithmetic)
  set +e
  READY_DISPLAY=$((READY + 0)) || READY_DISPLAY=0
  TOTAL_DISPLAY=$((TOTAL + 0)) || TOTAL_DISPLAY=0
  set -e
  
  # Display pod status as primary indicator
  if [ "${ALL_PODS_RUNNING}" = "true" ] && [ "${TOTAL_PODS}" -gt 0 ]; then
    # All pods are running, waiting for Talos health checks
    printf "\r  All pods running, waiting for Talos nodes to be healthy... (%ds)" "${ELAPSED}"
  elif [ "${TOTAL_PODS}" -gt 0 ]; then
    # Show pod status as primary indicator
    printf "\r  Waiting for pods... (%ds, %d/%d pods running, %d nodes Ready)" "${ELAPSED}" "${RUNNING_PODS}" "${TOTAL_PODS}" "${READY_DISPLAY}"
  elif [ "${TOTAL_DISPLAY}" -ge 3 ]; then
    # Nodes exist but no pods yet
    printf "\r  Waiting for pods to start... (%ds, %d nodes Ready)" "${ELAPSED}" "${READY_DISPLAY}"
  else
    # Waiting for nodes
    printf "\r  Waiting for nodes... (%ds, %d Ready / %d Total)" "${ELAPSED}" "${READY_DISPLAY}" "${TOTAL_DISPLAY}"
  fi
done
echo ""
echo "⚠️  Not all nodes Ready after ${MAX_NODES}s"
echo ""
echo "  Final node status:"
set +e
export KUBECONFIG="${KUBECONFIG_FILE_PATH}"
kubectl get nodes 2>&1 || echo "  (could not retrieve node status)"
unset KUBECONFIG
set -e
echo ""
echo "  Cluster may still be bootstrapping. You can check status later with:"
echo "    kubectl get nodes"
exit 1

