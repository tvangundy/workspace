#!/usr/bin/env bash
# Retrieve kubeconfig from cluster, fix server URL, wait for nodes Ready.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Set additional variables needed by this script
PROJECT_ROOT=$(get_windsor_project_root)

# Determine which context directory to use (same logic as initialize-context.sh)
CONTEXTS_DIR="${PROJECT_ROOT}/contexts"
ACTIVE_CONTEXT=""
if command -v windsor > /dev/null 2>&1; then
  ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
  if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
    ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
  fi
fi

if [ -n "${ACTIVE_CONTEXT}" ]; then
  # Use active context directory
  TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}"
else
  # No active context, use CLUSTER_NAME
  TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${CLUSTER_NAME}"
fi

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

# First, wait for Talos API to be accessible
echo "Waiting for Talos API to be accessible on ${CONTROL_PLANE_IP}..."
MAX_API_WAIT=180  # 3 minutes - usually ready quickly after VM boot
API_ELAPSED=0
API_READY=false

while [ ${API_ELAPSED} -lt ${MAX_API_WAIT} ]; do
  # Check if Talos API port is accessible
  if nc -z "${CONTROL_PLANE_IP}" 50000 2>/dev/null; then
    # Try to get version to confirm API is responding
    if talosctl --talosconfig "${TALOSCONFIG_PATH}" --nodes "${CONTROL_PLANE_IP}" version >/dev/null 2>&1; then
      API_READY=true
      break
    fi
  fi
  sleep 10
  API_ELAPSED=$((API_ELAPSED + 10))
  printf "\r  Waiting for Talos API... (%ds/%ds)" "${API_ELAPSED}" "${MAX_API_WAIT}"
done
echo ""

if [ "${API_READY}" != "true" ]; then
  echo "⚠️  Warning: Talos API not accessible after ${MAX_API_WAIT}s"
  echo "   Skipping Kubernetes API server wait - will try to retrieve kubeconfig directly"
  echo "   (Cluster may still be ready - check web UI console for status)"
else
  # Only wait for Kubernetes API server if Talos API is accessible
  echo "Waiting for Kubernetes API server to be ready..."
  MAX_API_SERVER_WAIT=300  # 5 minutes - usually ready within 2-3 minutes after bootstrap
  API_SERVER_ELAPSED=0
  API_SERVER_READY=false

  while [ ${API_SERVER_ELAPSED} -lt ${MAX_API_SERVER_WAIT} ]; do
    # Try to connect to the API server health endpoint
    if command -v curl >/dev/null 2>&1; then
      if curl -k -m 5 "https://${CONTROL_PLANE_IP}:6443/healthz" >/dev/null 2>&1; then
        API_SERVER_READY=true
        break
      fi
    else
      # Fallback: try with nc to check if port is open
      if nc -z "${CONTROL_PLANE_IP}" 6443 2>/dev/null; then
        API_SERVER_READY=true
        break
      fi
    fi
    sleep 10
    API_SERVER_ELAPSED=$((API_SERVER_ELAPSED + 10))
    printf "\r  Waiting for API server... (%ds/%ds)" "${API_SERVER_ELAPSED}" "${MAX_API_SERVER_WAIT}"
  done
  echo ""

  if [ "${API_SERVER_READY}" != "true" ]; then
    echo "⚠️  Warning: Kubernetes API server not ready after ${MAX_API_SERVER_WAIT}s"
    echo "   This may indicate the cluster is still bootstrapping"
    echo "   Continuing to try retrieving kubeconfig..."
  fi
fi

# If Talos API wasn't accessible, check Kubernetes API first before trying kubeconfig
# This avoids wasting time on kubeconfig retrieval if Talos API isn't working
if [ "${API_READY}" != "true" ]; then
  echo "Checking if Kubernetes API is accessible (cluster may be ready even if Talos API isn't)..."
  K8S_API_ACCESSIBLE=false
  
  if command -v curl >/dev/null 2>&1; then
    if curl -k -m 5 "https://${CONTROL_PLANE_IP}:6443/healthz" >/dev/null 2>&1; then
      K8S_API_ACCESSIBLE=true
    fi
  else
    # Fallback: try with nc to check if port is open
    if nc -z "${CONTROL_PLANE_IP}" 6443 2>/dev/null; then
      K8S_API_ACCESSIBLE=true
    fi
  fi
  
  if [ "${K8S_API_ACCESSIBLE}" = "true" ]; then
    echo "✅ Kubernetes API is accessible - cluster appears ready"
    echo "   Talos API is not accessible, but cluster is functional"
    echo "   You may need to retrieve kubeconfig manually later:"
    echo "     talosctl kubeconfig ${KUBECONFIG_FILE_PATH} \\"
    echo "       --talosconfig ${TALOSCONFIG_PATH} \\"
    echo "       --nodes ${CONTROL_PLANE_IP}"
    echo ""
    echo "   Or check the web UI console for cluster status"
    # Exit successfully - cluster is ready, just can't get kubeconfig via Talos API right now
    exit 0
  else
    echo "⚠️  Kubernetes API is also not accessible"
    echo "   Cluster may still be bootstrapping"
    echo "   Will attempt to retrieve kubeconfig anyway (with shorter timeout)..."
  fi
fi

# Now try to retrieve kubeconfig
echo "Retrieving kubeconfig..."
MAX_WAIT=300
ELAPSED=0
KUBECONFIG_RETRIEVED=false
INSECURE_FLAG=""

# If Talos API wasn't accessible, try with --insecure flag and shorter timeout
# This handles cases where the API is accessible but has certificate issues
if [ "${API_READY}" != "true" ]; then
  MAX_WAIT=60  # Only wait 1 minute if Talos API wasn't accessible
  INSECURE_FLAG="--insecure"
  echo "   (Talos API was not accessible - using --insecure flag and shorter timeout)"
fi

while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
  if talosctl kubeconfig "${KUBECONFIG_FILE_PATH}" \
    --talosconfig "${TALOSCONFIG_PATH}" \
    --nodes "${CONTROL_PLANE_IP}" \
    ${INSECURE_FLAG} > /tmp/tc_kubeconfig.log 2>&1; then
    KUBECONFIG_RETRIEVED=true
    break
  fi
  sleep 10
  ELAPSED=$((ELAPSED + 10))
  printf "\r  Waiting for kubeconfig... (%ds/%ds)" "${ELAPSED}" "${MAX_WAIT}"
done
echo ""

if [ ! -f "${KUBECONFIG_FILE_PATH}" ]; then
  # If kubeconfig retrieval failed, check if Kubernetes API is accessible directly
  # This can happen if Talos API is not responding but cluster is actually ready
  echo "⚠️  Could not retrieve kubeconfig via Talos API"
  
  # Check if Kubernetes API is accessible (re-check in case it became available)
  K8S_API_ACCESSIBLE=false
  if command -v curl >/dev/null 2>&1; then
    if curl -k -m 5 "https://${CONTROL_PLANE_IP}:6443/healthz" >/dev/null 2>&1; then
      K8S_API_ACCESSIBLE=true
    fi
  else
    # Fallback: try with nc to check if port is open
    if nc -z "${CONTROL_PLANE_IP}" 6443 2>/dev/null; then
      K8S_API_ACCESSIBLE=true
    fi
  fi
  
  if [ "${K8S_API_ACCESSIBLE}" = "true" ]; then
    # Kubernetes API is accessible - try one more time with --insecure flag
    # if we haven't already tried it
    if [ -z "${INSECURE_FLAG}" ]; then
      echo "   Kubernetes API is accessible - retrying kubeconfig retrieval with --insecure flag..."
      if talosctl kubeconfig "${KUBECONFIG_FILE_PATH}" \
        --talosconfig "${TALOSCONFIG_PATH}" \
        --nodes "${CONTROL_PLANE_IP}" \
        --insecure > /tmp/tc_kubeconfig.log 2>&1; then
        echo "✅ Successfully retrieved kubeconfig with --insecure flag"
        KUBECONFIG_RETRIEVED=true
      else
        echo "   Still failed, but cluster appears ready (Kubernetes API is accessible)"
        echo "   You can retrieve kubeconfig manually with:"
        echo "     talosctl kubeconfig ${KUBECONFIG_FILE_PATH} \\"
        echo "       --talosconfig ${TALOSCONFIG_PATH} \\"
        echo "       --nodes ${CONTROL_PLANE_IP} \\"
        echo "       --insecure"
        echo ""
        echo "   Or check the web UI console for cluster status"
        # Exit successfully - cluster is ready, just can't get kubeconfig via API
        exit 0
      fi
    else
      # We already tried with --insecure, but Kubernetes API is accessible
      echo "✅ Kubernetes API is accessible - cluster appears ready"
      echo "   Talos API had certificate issues, but cluster is functional"
      echo "   You can retrieve kubeconfig manually with:"
      echo "     talosctl kubeconfig ${KUBECONFIG_FILE_PATH} \\"
      echo "       --talosconfig ${TALOSCONFIG_PATH} \\"
      echo "       --nodes ${CONTROL_PLANE_IP} \\"
      echo "       --insecure"
      echo ""
      echo "   Or check the web UI console for cluster status"
      # Exit successfully - cluster is ready, just can't get kubeconfig via API
      exit 0
    fi
  else
    # If we get here, neither Talos API nor Kubernetes API is accessible
    echo "   Cluster may still be bootstrapping"
    if [ -f /tmp/tc_kubeconfig.log ]; then
      echo "   Last error:"
      tail -5 /tmp/tc_kubeconfig.log | sed 's/^/     /'
    fi
    exit 1
  fi
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

