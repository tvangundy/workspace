# Troubleshooting Flux Pre-Install Hook Timeout

## Problem
Flux Helm release fails with:
```
failed pre-install: 1 error occurred:
      * timed out waiting for the condition
```

## Debugging Steps

### 1. Check Flux CRDs Status
```bash
# Check if CRDs are installed
kubectl get crds | grep flux

# Check CRD installation jobs (if any)
kubectl get jobs -n system-gitops

# Check for any pending CRDs
kubectl get crds -o json | jq '.items[] | select(.status.conditions[]?.type=="Established" and .status.conditions[]?.status!="True") | .metadata.name'
```

### 2. Check Helm Release Status
```bash
# Get detailed Helm release status
helm status flux2 -n system-gitops

# Check Helm release history
helm history flux2 -n system-gitops

# Get Helm release manifest to see what's being installed
helm get manifest flux2 -n system-gitops
```

### 3. Check Pods and Events
```bash
# Check all pods in the namespace
kubectl get pods -n system-gitops

# Check events for errors
kubectl get events -n system-gitops --sort-by='.lastTimestamp' | tail -30

# Check for image pull errors
kubectl get events --all-namespaces | grep -i "pull\|image\|failed"
```

### 4. Check Pre-Install Hooks
```bash
# List all hooks (jobs) in the namespace
kubectl get jobs -n system-gitops

# Check hook job logs
kubectl logs -n system-gitops -l app.kubernetes.io/name=flux2 --tail=100

# Check for stuck jobs
kubectl get jobs -n system-gitops -o wide
```

### 5. Check API Server and Cluster Health
```bash
# Check API server connectivity
kubectl cluster-info

# Check node status
kubectl get nodes

# Check if API server is responsive
kubectl get --raw /healthz
```

## Common Fixes

### Fix 1: Delete Failed Release and Retry
```bash
# Delete the failed Helm release
helm uninstall flux2 -n system-gitops

# Clean up any remaining resources
kubectl delete namespace system-gitops --wait=false
kubectl delete crds -l app.kubernetes.io/name=flux2

# Wait a moment, then retry
sleep 10
# Re-run your terraform apply or windsor command
```

### Fix 2: Increase Helm Timeout
If using Terraform, you can increase the timeout in the Helm release resource:
```hcl
resource "helm_release" "flux_system" {
  # ... other config ...
  timeout = 600  # Increase from 300 to 600 seconds (10 minutes)
}
```

### Fix 3: Install CRDs Manually First

**Option A: Fix Node Taints Issue (Most Common)**

If the pod is Pending with "untolerated taint(s)", the nodes have taints that prevent scheduling:

```bash
# Check what taints the nodes have
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Option 1: Add tolerations to the Helm release (modify Terraform/values)
# Add this to your Helm values or Terraform configuration:
# tolerations:
#   - key: <taint-key>
#     operator: Equal
#     value: <taint-value>
#     effect: NoSchedule

# Option 2: Remove taints temporarily (if safe to do so)
kubectl taint nodes --all <taint-key>-

# Option 3: Manually run the check and install CRDs (bypasses the hook)
# Install Flux CLI if needed
which flux || curl -s https://fluxcd.io/install.sh | sudo bash

# Run the pre-check manually
flux check --pre --namespace system-gitops

# Install CRDs manually
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller

# Delete deployments but keep CRDs
kubectl delete deployment -n flux-system --all 2>/dev/null || true
kubectl delete serviceaccount -n flux-system --all 2>/dev/null || true
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=flux 2>/dev/null || true

# Delete the stuck job
kubectl delete job -n system-gitops flux2-flux-check

# Uninstall failed release
helm uninstall flux2 -n system-gitops || true

# Retry (CRDs are now installed, so the hook should pass or be skipped)
windsor up
```

**Option B: Diagnose and Fix the Pre-Install Hook**

The pre-install hook runs `flux check --pre` which verifies CRDs are installed. If the pod is Pending, check why:

```bash
# Check why the pod is pending
kubectl describe pod -n system-gitops flux2-flux-check-4j2f7

# Common issues:
# 1. Image pull issues - check events for "Failed to pull image"
# 2. Resource constraints - check for "Insufficient" errors
# 3. Node selectors - check if nodes match requirements

# If the pod can't start, manually run the check locally
# First, install Flux CLI if needed:
# curl -s https://fluxcd.io/install.sh | sudo bash

# Then run the pre-check manually to see what it needs
flux check --pre --namespace system-gitops

# This will tell you what CRDs are missing. Install them:
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller --export | \
  grep -E "kind: CustomResourceDefinition" -A 200 | \
  kubectl apply -f -

# Or install everything and delete deployments (keeps CRDs)
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller
kubectl delete deployment -n flux-system --all
kubectl delete serviceaccount -n flux-system --all
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=flux

# Wait for CRDs to be established
kubectl wait --for condition=established --timeout=120s \
  crd/gitrepositories.source.toolkit.fluxcd.io \
  crd/kustomizations.kustomize.toolkit.fluxcd.io \
  crd/helmrepositories.source.toolkit.fluxcd.io \
  crd/helmcharts.source.toolkit.fluxcd.io

# Delete the stuck job and retry
kubectl delete job -n system-gitops flux2-flux-check
helm uninstall flux2 -n system-gitops || true

# Then retry Helm installation
```

**Option B: Extract CRDs from Helm Chart Pre-Install Hook**
```bash
# The Helm chart has a pre-install hook that installs CRDs
# Let's see what it does and replicate it
helm template fluxcd-community/flux2 --version 2.17.1 | \
  grep -A 50 "kind: Job" | \
  grep -A 30 "pre-install" | \
  head -50

# Or check the actual hook job that failed
kubectl get jobs -n system-gitops
kubectl logs -n system-gitops <job-name>  # See what URL/version it's using

# The hook typically runs: kubectl apply -f <CRD_URL>
# Find the exact URL from the logs and use it
```

**Option C: Download CRDs with Proper Format Handling**
```bash
# Check what's actually being downloaded
curl -sL https://github.com/fluxcd/flux2/releases/download/v2.5.1/crds.yaml | head -20

# If it's HTML (redirect), follow redirects properly
curl -L https://github.com/fluxcd/flux2/releases/download/v2.5.1/crds.yaml -o /tmp/crds.yaml
file /tmp/crds.yaml  # Check file type
kubectl apply -f /tmp/crds.yaml

# Or try the manifest file instead
curl -L https://github.com/fluxcd/flux2/releases/download/v2.5.1/manifests/crds.yaml -o /tmp/crds.yaml
kubectl apply -f /tmp/crds.yaml
```

**Option B: Download from Specific Release (Alternative)**
```bash
# Find the correct version from: https://github.com/fluxcd/flux2/releases
# For version 2.5.1 (example):
FLUX_VERSION="v2.5.1"
kubectl apply -f https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/crds.yaml

# Or use the latest v2 release:
kubectl apply -f https://github.com/fluxcd/flux2/releases/download/v2.5.1/crds.yaml
```

### Fix 4: Skip Pre-Install Hooks (Not Recommended)
```bash
# Only use this if you understand the implications
helm install flux2 fluxcd-community/flux2 \
  --namespace system-gitops \
  --create-namespace \
  --skip-crds \
  --set installCRDs=false
```

### Fix 5: Check Resource Constraints
```bash
# Check node resources
kubectl top nodes

# Check if nodes have enough resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check for resource quotas
kubectl get resourcequota -n system-gitops
```

### Fix 6: Check Network/Image Pull Issues
```bash
# Test image pull manually
kubectl run test-pull --image=ghcr.io/fluxcd/source-controller:v1.5.0 --rm -it --restart=Never

# Check registry connectivity
kubectl get nodes -o wide
# Try pulling images on each node
```

## Windsor-Specific Fix

If using Windsor CLI, you may need to:

1. **Clean up and retry:**
```bash
# In your workspace
windsor destroy  # This will clean up everything
windsor up       # Retry the setup
```

2. **Check Windsor logs:**
```bash
# Check Windsor context state
windsor status

# Check Terraform state
cd .windsor/contexts/local/.terraform/gitops/flux
terraform state list
```

3. **Manual intervention:**
```bash
# If Helm release is stuck, manually clean it up
helm uninstall flux2 -n system-gitops || true
kubectl delete namespace system-gitops --wait=false

# Then retry with Windsor
windsor up
```

## Prevention

1. **Ensure cluster is fully ready** before installing Flux:
   - All nodes should be `Ready`
   - API server should be responsive
   - CoreDNS should be working

2. **Check prerequisites:**
   - Sufficient CPU/memory on nodes
   - Network connectivity to image registries
   - No resource quotas blocking installation

3. **Use proper ordering:**
   - Install Flux after cluster is stable
   - Wait for all system pods to be running
   - Ensure no other installations are in progress

