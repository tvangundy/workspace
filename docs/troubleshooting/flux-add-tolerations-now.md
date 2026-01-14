# Adding Tolerations to Flux Helm Release - Immediate Fix

## Current Issue
- Disk-pressure taint keeps returning (nodes are out of disk space)
- Control-plane taint exists on controlplane-1
- Pre-install hook job can't schedule because it lacks tolerations

## Quick Fix: Patch the Job Template

Since the pre-install hook job is created by Helm, we need to add tolerations. The quickest way is to patch the job after Helm creates it but before it times out:

```bash
# In a separate terminal, watch for the job and patch it immediately
# Run this BEFORE running windsor up:

# Terminal 1: Watch for the job
watch -n 1 'kubectl get jobs -n system-gitops'

# Terminal 2: When job appears, patch it immediately
kubectl patch job -n system-gitops flux2-flux-check --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations",
    "value": [
      {
        "key": "node-role.kubernetes.io/control-plane",
        "operator": "Exists",
        "effect": "NoSchedule"
      },
      {
        "key": "node.kubernetes.io/disk-pressure",
        "operator": "Exists",
        "effect": "NoSchedule"
      }
    ]
  }
]'
```

## Better Fix: Add Tolerations via Helm Values

The Flux Helm chart supports tolerations. We need to pass them through the Terraform module.

### Step 1: Check if Terraform Module Supports Values

The Windsor core module may support passing Helm values. Check the module's variables or create a `flux.tfvars` file:

```bash
# Create the directory if it doesn't exist
mkdir -p .windsor/contexts/local/terraform/gitops

# Create flux.tfvars (if the module supports it)
cat > .windsor/contexts/local/terraform/gitops/flux.tfvars <<'EOF'
# Add tolerations to all Flux components
values = yamlencode({
  tolerations = [
    {
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Exists"
      effect   = "NoSchedule"
    },
    {
      key      = "node.kubernetes.io/disk-pressure"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
})
EOF
```

### Step 2: Alternative - Check Module Variables

The module might use a different variable name. Check the extracted module:

```bash
# Find the module location
find .windsor -name "gitops" -type d | grep terraform

# Check the module's variables.tf
cat .windsor/contexts/local/.oci_extracted/ghcr.io-windsorcli/core-*/terraform/gitops/flux/variables.tf | grep -i "value\|toleration"
```

### Step 3: Manual Helm Upgrade (If Terraform Doesn't Support It)

If the Terraform module doesn't support passing values, upgrade the Helm release manually:

```bash
# Get current values
helm get values flux2 -n system-gitops -o yaml > /tmp/flux-values.yaml

# Add tolerations
cat >> /tmp/flux-values.yaml <<EOF
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node.kubernetes.io/disk-pressure"
    operator: "Exists"
    effect: "NoSchedule"
EOF

# Upgrade the release
helm upgrade flux2 fluxcd-community/flux2 \
  --namespace system-gitops \
  --version 2.17.1 \
  --values /tmp/flux-values.yaml \
  --reuse-values
```

## Recommended: Fix Disk Space First

The disk-pressure taint indicates a real problem. Fix it:

```bash
# Check what's using disk space
docker system df
df -h

# Clean up Docker
docker system prune -a --volumes

# Check for large files
du -sh /var/lib/docker/* 2>/dev/null | sort -h | tail -10

# For Talos/Docker setups, check container logs
docker ps --format "{{.Names}}" | xargs -I {} docker logs {} 2>&1 | wc -l
```

Once disk space is fixed, the disk-pressure taint will automatically be removed by Kubernetes.

