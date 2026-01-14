# Fixing Flux Node Taint Issues

## Problem
Flux pods can't be scheduled because nodes have taints that the pods don't tolerate:
```
0/2 nodes are available: 2 node(s) had untolerated taint(s)
```

## Critical: Disk Pressure Taint

If you see `node.kubernetes.io/disk-pressure:NoSchedule`, **your nodes are out of disk space**. This must be fixed first:

```bash
# Check disk usage on nodes
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.conditions[] | select(.type=="DiskPressure") | .status)"'

# Check disk usage in the cluster
kubectl top nodes

# Clean up disk space (run on each node or via kubectl)
# Common cleanup steps:
# 1. Remove unused images
# 2. Clean up old logs
# 3. Remove unused volumes
# 4. Check for large files

# Remove the disk-pressure taint (temporary - will come back if disk is still full)
kubectl taint nodes controlplane-1 node.kubernetes.io/disk-pressure:NoSchedule-
kubectl taint nodes worker-1 node.kubernetes.io/disk-pressure:NoSchedule-
```

**Important**: The disk-pressure taint will return if the disk is still full. You must free up disk space.

## Step 1: Check Node Taints

```bash
# Check what taints are on your nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Or get detailed taint information
kubectl describe nodes | grep -A 5 Taints
```

## Step 2: Add Tolerations to Flux Helm Release

The Flux Helm release is managed by Terraform through the Windsor core module. You can add tolerations via Helm values.

### Option A: Add via Terraform Variables (Recommended)

If the Terraform module supports a `values` or `helm_values` variable, add tolerations there. Check your `terraform/gitops/flux/` directory or `contexts/local/terraform/gitops/flux.tfvars`:

```hcl
# In flux.tfvars or terraform variables
helm_values = <<-EOT
  tolerations:
    - key: "<taint-key>"
      operator: "Equal"
      value: "<taint-value>"
      effect: "NoSchedule"
  # Or if the taint has no value:
  # - key: "<taint-key>"
  #   operator: "Exists"
  #   effect: "NoSchedule"
EOT
```

### Option B: Modify Helm Release Directly (Temporary)

If you need a quick fix, you can patch the Helm release after it's created:

```bash
# Get the current values
helm get values flux2 -n system-gitops -o yaml > /tmp/flux-values.yaml

# Add tolerations to the values
cat >> /tmp/flux-values.yaml <<EOF
tolerations:
  - key: "<taint-key>"
    operator: "Equal"
    value: "<taint-value>"
    effect: "NoSchedule"
EOF

# Upgrade the release
helm upgrade flux2 fluxcd-community/flux2 \
  --namespace system-gitops \
  --version 2.17.1 \
  --values /tmp/flux-values.yaml
```

### Option C: Check Windsor Core Module Configuration

The Flux Terraform module from `windsorcli/core` may have a way to pass additional Helm values. Check:

1. The module's `variables.tf` for a `values` or `helm_values` variable
2. Your `flux.tfvars` file for existing value overrides
3. The module documentation

## Step 3: Common Taint Patterns

### Talos Control Plane Taint
If using Talos, control plane nodes often have:
```bash
node-role.kubernetes.io/control-plane:NoSchedule
```

Toleration:
```yaml
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
```

### Disk Pressure Taint (Critical Issue)
If nodes have disk pressure:
```bash
node.kubernetes.io/disk-pressure:NoSchedule
```

**Warning**: This indicates nodes are out of disk space. Fix the disk space issue first!

Toleration (only if you can't fix disk space immediately):
```yaml
tolerations:
  - key: "node.kubernetes.io/disk-pressure"
    operator: "Exists"
    effect: "NoSchedule"
```

**Recommended**: Free up disk space instead of tolerating this taint.

### Worker Node Taint
Some setups taint worker nodes:
```bash
node-role.kubernetes.io/worker:NoSchedule
```

Toleration:
```yaml
tolerations:
  - key: "node-role.kubernetes.io/worker"
    operator: "Exists"
    effect: "NoSchedule"
```

### Custom Taints
For custom taints, match the exact key, value (if any), and effect.

## Step 4: Apply and Verify

After adding tolerations:

```bash
# If using Terraform
cd terraform/gitops/flux  # or wherever your flux terraform is
terraform apply

# Or if using Windsor
windsor up

# Verify pods can schedule
kubectl get pods -n system-gitops
kubectl get pods -n flux-system
```

## Quick Reference: Finding Your Taints

```bash
# Get all taints in a readable format
kubectl get nodes -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.spec.taints // "[]" | tostring)"'

# Or simpler
for node in $(kubectl get nodes -o name); do
  echo "=== $node ==="
  kubectl describe $node | grep -A 2 Taints
done
```

