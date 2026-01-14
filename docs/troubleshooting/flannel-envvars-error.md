# Fixing Flannel Pod CrashLoopBackOff Issues

## Problem

Flannel pods are in `CrashLoopBackOff` state. The pods start briefly but then crash with exit code 1. The error message shows:
```
loadFlannelSubnetEnv failed: /run/flannel/subnet.env is missing FLANNEL_NETWORK, FLANNEL_IPV6_NETWORK, FLANNEL_SUBNET, FLANNEL_IPV6_SUBNET, FLANNEL_MTU, FLANNEL_IPMASQ
```

**Root Cause:** The flannel daemon pod is crashing before it can write the required environment variables to `/run/flannel/subnet.env`. The CNI plugin (which runs on the node) tries to read this file when creating pod sandboxes and fails because it's empty or missing required variables.

## Common Causes

1. **Missing `/run/flannel` directory** - Flannel needs this directory to exist on the host
2. **Hardcoded API server endpoint** - Flannel configured with incorrect API server address (e.g., `127.0.0.1:7445` for Talos, but endpoint not accessible)
3. **Empty `subnet.env` file** - File exists but flannel daemon hasn't written required variables yet
4. **API server connectivity** - Flannel can't connect to the Kubernetes API server
5. **Permissions issues** - Flannel can't write to `/run/flannel/subnet.env`
6. **Timing issues** - API server or cluster components not fully ready when flannel starts

## Diagnosis

### Check Pod Status

```bash
# Check flannel pods
kubectl get pods -n kube-system | grep flannel

# Get detailed pod information
kubectl describe pod -n kube-system <flannel-pod-name>

# Check pod logs
kubectl logs -n kube-system <flannel-pod-name> -c kube-flannel
```

### Check API Server Connectivity

```bash
# Check if API server is accessible
kubectl get nodes

# Check API server status
kubectl get componentstatuses

# Check if services exist
kubectl get svc -A
```

### Check Flannel DaemonSet

```bash
# Find the correct daemonset name
kubectl get daemonset -n kube-system | grep flannel

# Check flannel daemonset (use the actual name from above)
kubectl get daemonset -n kube-system <daemonset-name>

# Check daemonset configuration for environment variables
kubectl get daemonset -n kube-system <daemonset-name> -o yaml | grep -A 30 "env:"

# Check for envFrom (service references)
kubectl get daemonset -n kube-system <daemonset-name> -o yaml | grep -B 5 -A 20 "envFrom"
```

## Solutions

### Solution 1: Wait for API Server to be Ready

This is often a timing issue. Wait a few minutes and check again:

```bash
# Wait for API server to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Check if flannel pods recover
kubectl get pods -n kube-system | grep flannel
```

### Solution 2: Restart Flannel DaemonSet

If the issue persists, restart the flannel daemonset:

```bash
# Check the actual labels on flannel pods
kubectl get pods -n kube-system -l app=flannel --show-labels

# If the label is different, use the correct selector:
kubectl get pods -n kube-system | grep flannel

# Delete flannel pods directly by name (they will be recreated)
kubectl delete pods -n kube-system kube-flannel-7strv kube-flannel-kfrc6

# Or use the daemonset name selector
kubectl delete pods -n kube-system -l app=kube-flannel

# Or restart the daemonset (use actual name from kubectl get daemonset)
kubectl get daemonset -n kube-system | grep flannel
kubectl rollout restart daemonset -n kube-system <daemonset-name>
```

### Solution 3: Check for Service Dependencies

If flannel is referencing services that don't exist:

```bash
# Find the daemonset name first
kubectl get daemonset -n kube-system | grep flannel

# Check what services flannel needs (look for envFrom or service references)
kubectl get daemonset -n kube-system <daemonset-name> -o yaml | grep -A 30 "env:" | grep -i service

# Check the full environment variable configuration
kubectl get daemonset -n kube-system <daemonset-name> -o yaml | grep -A 50 "env:" | head -60

# Check if those services exist
kubectl get svc -A

# Check for kube-dns or coredns service (common dependency)
kubectl get svc -n kube-system | grep -E "kube-dns|coredns"
```

**Common issue:** Flannel might be trying to use `envFrom` with a service that doesn't exist yet. Check the daemonset spec for `envFrom` sections.

### Solution 4: Fix API Server Connectivity

If there are network issues:

```bash
# Check API server endpoint
kubectl config view | grep server

# Test connectivity from worker node
# SSH into the worker node and run:
curl -k https://<api-server-ip>:6443/healthz

# Check kubelet logs on the worker node
sudo journalctl -u kubelet -n 50

# If TLS errors occur (like "tls: internal error"), check kubelet certificates
# On the worker node:
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100 | grep -i tls
```

**Note:** The TLS error when fetching logs (`remote error: tls: internal error`) suggests a certificate issue. This might resolve itself as the cluster stabilizes, or you may need to restart kubelet on the worker node.

### Solution 5: Reinstall Flannel

If nothing else works, reinstall flannel:

```bash
# Delete flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait a moment
sleep 10

# Reinstall flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Solution 6: Check Node Taints

If nodes have taints that prevent flannel from scheduling:

```bash
# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# If disk-pressure taint exists, remove it (after fixing disk space)
kubectl taint nodes <node-name> node.kubernetes.io/disk-pressure:NoSchedule-
```

## Immediate Fix Commands

Run these in order:

```bash
# 1. Check what services exist
kubectl get svc -A

# 2. Find the daemonset name (usually "kube-flannel")
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
echo "Daemonset name: $DAEMONSET_NAME"

# 3. Check flannel daemonset configuration for service references
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -B 5 -A 30 "envFrom\|env:"

# 4. Check current pod status and get pod name
kubectl get pods -n kube-system | grep flannel
CURRENT_POD=$(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}')
echo "Current pod: $CURRENT_POD"

# 5. Check pod configuration and events
kubectl get pod -n kube-system $CURRENT_POD -o yaml | grep -B 5 -A 30 "envFrom\|env:"
kubectl describe pod -n kube-system $CURRENT_POD | tail -30

# 6. Delete flannel pods to force recreation
kubectl get pods -n kube-system | grep flannel | awk '{print $1}' | xargs kubectl delete pod -n kube-system

# 7. Wait longer and check if they recover (give API server time)
sleep 60
kubectl get pods -n kube-system | grep flannel

# 5. If still failing, check if it's a service dependency issue
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.containers[*].envFrom}' | jq .

# 6. If services are missing, wait for them to be created, then restart flannel
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
kubectl rollout restart daemonset -n kube-system $DAEMONSET_NAME
```

## Root Cause Analysis

### Initial Error: "services have not yet been read"

Based on the daemonset configuration, flannel is using:
- Hardcoded `KUBERNETES_SERVICE_HOST: 127.0.0.1` and `KUBERNETES_SERVICE_PORT: "7445"`
- ConfigMap `kube-flannel-cfg`

The error "services have not yet been read at least once, cannot construct envvars" occurs because Kubernetes automatically tries to inject environment variables from the `kubernetes` service in the `default` namespace, even when values are hardcoded. If the API server hasn't read that service yet, this error occurs.

**This error typically resolves itself** once the API server fully initializes (usually within 2-5 minutes of cluster creation).

### Secondary Error: "loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory"

After the initial error resolves, you may see this error. This occurs when:
1. The flannel pod needs to create `/run/flannel/subnet.env` but the directory doesn't exist
2. The flannel pod doesn't have permissions to write to `/run/flannel/`
3. The flannel pod is crashing before it can create the file
4. There's a volume mount issue preventing the file from being created

**This is usually a timing issue** - the flannel pod needs to start successfully first, then it creates the subnet.env file. If one pod is running and another is failing, check which node the failing pod is on.

### Check the kubernetes Service

```bash
# Check if the kubernetes service exists
kubectl get svc -n default kubernetes

# Check if it's ready
kubectl get svc -n default kubernetes -o yaml

# Wait for it to be available
kubectl wait --for=condition=Ready service/kubernetes -n default --timeout=60s
```

### Check the ConfigMap

```bash
# Check the flannel ConfigMap
kubectl get configmap -n kube-system kube-flannel-cfg -o yaml

# Check if it references any services
kubectl get configmap -n kube-system kube-flannel-cfg -o yaml | grep -i service
```

### Solution 7: Fix Missing subnet.env File

If you see `loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory`:

```bash
# 1. Check which pods are running vs failing
kubectl get pods -n kube-system | grep flannel

# 2. Check which nodes the pods are on
kubectl get pods -n kube-system -o wide | grep flannel

# 3. Get the actual error from the container (try different methods)
CURRENT_POD=$(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}')

# Try to get logs (may fail with TLS error, but worth trying)
kubectl logs -n kube-system $CURRENT_POD -c kube-flannel --tail=50 2>&1

# Check the install-config container logs (this runs first)
kubectl logs -n kube-system $CURRENT_POD -c install-config --tail=50 2>&1

# 4. Check the daemonset volume mounts
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -A 30 "volumeMounts"

# 5. Check if /run/flannel directory exists and has proper permissions
# This requires checking on the actual node, but we can check the pod spec
kubectl get pod -n kube-system $CURRENT_POD -o yaml | grep -A 10 "volumeMounts" | grep -i flannel

# 6. If both pods are failing, check if there's a fundamental issue
# Check the daemonset for any init containers or volume issues
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -A 50 "initContainers\|volumes:"
```

**Note:** If both pods are failing, this suggests a configuration issue rather than a timing issue. The `install-config` container only copies the CNI config file - it does NOT create the `/run/flannel/subnet.env` file. The `kube-flannel` container itself must create this file when it starts, but it's crashing before it can do so.

### Solution 8: Check if Flannel Can Connect to API Server

The flannel daemon needs to connect to the Kubernetes API server. Check if it can:

```bash
# 1. Try to exec into the pod (may fail due to crash, but worth trying)
FAILING_POD=$(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}')
kubectl exec -n kube-system $FAILING_POD -c kube-flannel -- ls -la /run/flannel/ 2>&1 || echo "Container not running"

# 2. Check if the API server endpoint is correct
# Flannel is configured with KUBERNETES_SERVICE_HOST=127.0.0.1 and KUBERNETES_SERVICE_PORT=7445
# This is Talos-specific - verify these are correct for your setup

# 3. Check if there are network connectivity issues
kubectl get endpoints -n default kubernetes

# 4. Wait longer - flannel may need more time to initialize
# Sometimes it takes 5-10 minutes for flannel to fully start
echo "Waiting 2 more minutes for flannel to initialize..."
sleep 120
kubectl get pods -n kube-system | grep flannel

# 5. If still failing, check the daemonset for any startup issues
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -A 10 "args:\|command:"
```

**Important:** The `kube-flannel` container must successfully start and connect to the API server to create the `subnet.env` file. If it's crashing immediately, there may be:
- API server connectivity issues
- Configuration issues with the Talos-specific service endpoints (127.0.0.1:7445)
- Permission issues
- Missing dependencies

### Solution 9: Check Container Exit Code and Status

Since logs are blocked by TLS errors, check the container status:

```bash
# 1. Get the container status and exit code (without jq)
FAILING_POD=$(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}')
kubectl get pod -n kube-system $FAILING_POD -o yaml | grep -A 30 "containerStatuses" | grep -A 20 "kube-flannel"

# 2. Check the last termination state for exit code (extract from yaml)
kubectl get pod -n kube-system $FAILING_POD -o yaml | grep -A 10 "lastState:" | head -15

# 3. Check the volume type in the daemonset (look for hostPath)
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -B 5 -A 10 "name: run"

# 4. If it's a hostPath volume, check if the directory exists on the host
# Get the node name
NODE_NAME=$(kubectl get pod -n kube-system $FAILING_POD -o jsonpath='{.spec.nodeName}')
echo "Pod is on node: $NODE_NAME"
# If you have SSH access to the node, check:
# ssh $NODE_NAME "ls -la /run/flannel/ 2>&1 || echo 'Directory does not exist'"
```

### Solution 10: Manual Fix - Create subnet.env File

If flannel keeps crashing, you can manually create the subnet.env file (temporary workaround):

```bash
# 1. Get the node where the pod is running
NODE_NAME=$(kubectl get pod -n kube-system $FAILING_POD -o jsonpath='{.spec.nodeName}')

# 2. SSH to that node (if possible) and create the file manually
# The file should contain something like:
# FLANNEL_NETWORK=10.244.0.0/16
# FLANNEL_SUBNET=10.244.X.0/24
# FLANNEL_MTU=1450
# FLANNEL_IPMASQ=true

# However, this is not recommended as flannel should create it automatically
```

**Note:** The proper fix is for flannel to start successfully. The manual creation is only a temporary workaround and may not work correctly.

### Solution 11: Create Missing /run/flannel Directory on Talos Nodes

If the `/run/flannel` directory doesn't exist on the Talos nodes (which is required for the hostPath volume):

**Important:** The flannel pods run on the Talos nodes (controlplane-1, worker-1), NOT on the VM where you might be SSH'd into. You need to create the directory on the actual Talos nodes.

```bash
# 1. Check which nodes have flannel pods
kubectl get pods -n kube-system -o wide | grep flannel

# 2. Use kubectl debug to create the directory on each node
# For controlplane-1:
kubectl debug node/controlplane-1 -it --image=busybox -- mkdir -p /host/run/flannel && chmod 755 /host/run/flannel

# For worker-1:
kubectl debug node/worker-1 -it --image=busybox -- mkdir -p /host/run/flannel && chmod 755 /host/run/flannel

# 3. Alternative: Use a temporary pod with hostPath access
# Create a debug pod on controlplane-1
kubectl run debug-flannel-cp --image=busybox --restart=Never --overrides='
{
  "spec": {
    "hostNetwork": true,
    "nodeName": "controlplane-1",
    "containers": [{
      "name": "debug",
      "image": "busybox",
      "command": ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && ls -la /run/flannel && sleep 3600"]
    }]
  }
}' --rm -it

# Create a debug pod on worker-1
kubectl run debug-flannel-w1 --image=busybox --restart=Never --overrides='
{
  "spec": {
    "hostNetwork": true,
    "nodeName": "worker-1",
    "containers": [{
      "name": "debug",
      "image": "busybox",
      "command": ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && ls -la /run/flannel && sleep 3600"]
    }]
  }
}' --rm -it

# 4. After creating directories, delete flannel pods to force recreation
kubectl get pods -n kube-system | grep flannel | awk '{print $1}' | xargs kubectl delete pod -n kube-system

# 5. Wait and check status
sleep 45
kubectl get pods -n kube-system | grep flannel
```

**Note:** If `kubectl debug node` doesn't work (may require special permissions), you may need to SSH directly to the Talos nodes or use Talos CLI to access them.

### Solution 12: Patch Flannel DaemonSet with Init Container (Recommended)

If PodSecurity policies prevent creating debug pods, patch the flannel daemonset to add an init container that creates the directory. This works because the daemonset already has the necessary permissions:

```bash
# 1. Get the daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
echo "Daemonset: $DAEMONSET_NAME"

# 2. Patch the daemonset to add an init container that creates /run/flannel
# IMPORTANT: Mount path must match the main container's mount path (/run/flannel)
kubectl patch daemonset -n kube-system $DAEMONSET_NAME --type='json' -p='
[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/-",
    "value": {
      "name": "create-flannel-dir",
      "image": "busybox:1.36",
      "command": ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && ls -la /run/flannel"],
      "securityContext": {
        "privileged": true
      },
      "volumeMounts": [
        {
          "name": "run",
          "mountPath": "/run/flannel"
        }
      ]
    }
  }
]'

# 3. Wait for the daemonset to roll out the new pods
kubectl rollout status daemonset/$DAEMONSET_NAME -n kube-system --timeout=120s

# 4. Check if pods are now running
kubectl get pods -n kube-system | grep flannel

# 5. If pods are still failing, check logs
kubectl get pods -n kube-system | grep flannel | awk '{print $1}' | head -1 | xargs -I {} kubectl logs -n kube-system {} -c kube-flannel --tail=50 2>&1 || echo "Logs unavailable"
```

**Fixing Duplicate Init Container Error:** If you get "Duplicate value" error, remove all init containers first:

```bash
# 1. Get daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')

# 2. Check how many init containers exist
INIT_COUNT=$(kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.initContainers[*].name}' | wc -w)
echo "Found $INIT_COUNT init containers"

# 3. Remove all init containers (remove from the end to avoid index shifting)
for i in $(seq $((INIT_COUNT - 1)) -1 0); do
  echo "Removing init container at index $i"
  kubectl patch daemonset -n kube-system $DAEMONSET_NAME --type='json' -p="[{\"op\": \"remove\", \"path\": \"/spec/template/spec/initContainers/$i\"}]"
done

# 4. Wait a moment
sleep 2

# 5. Add the correct init container
kubectl patch daemonset -n kube-system $DAEMONSET_NAME --type='json' -p='
[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/-",
    "value": {
      "name": "create-flannel-dir",
      "image": "busybox:1.36",
      "command": ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && ls -la /run/flannel"],
      "securityContext": {
        "privileged": true
      },
      "volumeMounts": [
        {
          "name": "run",
          "mountPath": "/run/flannel"
        }
      ]
    }
  }
]'

# 6. Wait for rollout
kubectl rollout status daemonset/$DAEMONSET_NAME -n kube-system --timeout=120s

# 7. Check pods
kubectl get pods -n kube-system | grep flannel
```

**Alternative:** If the JSON patch doesn't work, you can export the daemonset, edit it, and reapply:

```bash
# 1. Get the daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')

# 2. Export the daemonset
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml > /tmp/flannel-ds.yaml

# 3. Edit the file to add the init container (see below for the YAML snippet)
# Then reapply:
# kubectl apply -f /tmp/flannel-ds.yaml

# 4. Delete existing pods to force recreation
kubectl get pods -n kube-system | grep flannel | awk '{print $1}' | xargs kubectl delete pod -n kube-system
```

**YAML snippet to add to the daemonset spec.template.spec.initContainers:**

```yaml
initContainers:
  - name: create-flannel-dir
    image: busybox:1.36
    command: ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && ls -la /run/flannel"]
    securityContext:
      privileged: true
    volumeMounts:
      - name: run
        mountPath: /run/flannel  # Must match main container's mount path
```

**Note:** The init container will run before the main `kube-flannel` container and create the directory. The init container has access to the same hostPath volumes as the main container, so it can create the directory on the host.

### Solution 13: Diagnose Post-Init-Container Errors

If the init container successfully creates the directory but flannel pods still crash, check the actual error:

```bash
# 1. Get a failing pod name
FAILING_POD=$(kubectl get pods -n kube-system | grep flannel | grep -v Running | head -1 | awk '{print $1}')
echo "Checking pod: $FAILING_POD"

# 2. Check init container logs (should show directory creation)
kubectl logs -n kube-system $FAILING_POD -c create-flannel-dir 2>&1

# 3. Check install-config container logs
kubectl logs -n kube-system $FAILING_POD -c install-config 2>&1

# 4. Check main flannel container logs (the actual error)
kubectl logs -n kube-system $FAILING_POD -c kube-flannel --tail=50 2>&1

# 5. Get detailed pod description
kubectl describe pod -n kube-system $FAILING_POD | tail -50

# 6. Check if the directory was actually created on the node
# (This requires node access, but we can check via the init container logs)
kubectl logs -n kube-system $FAILING_POD -c create-flannel-dir 2>&1 | grep -i "flannel\|mkdir\|ls"

# 7. Check pod events for scheduling or volume mount issues
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep -i flannel | tail -20
```

**Common issues after directory creation:**
- Flannel still can't connect to API server (check `KUBERNETES_SERVICE_HOST` and `KUBERNETES_SERVICE_PORT`)
- Flannel can't write to `/run/flannel/subnet.env` (permissions issue)
- Flannel crashes before creating `subnet.env` (startup error)
- Volume mount issues (check if `run` volume is properly mounted)

### Solution 14: Verify Directory Creation and Check Volume Mounts

Since TLS errors prevent log access, verify the directory was created and check volume mount paths:

```bash
# 1. Check the daemonset to see where the main container mounts the 'run' volume
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
echo "=== Main Container Volume Mounts ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.containers[?(@.name=="kube-flannel")].volumeMounts[*]}' | jq -r '.[] | select(.name=="run") | "Mount: \(.mountPath)"'

# 2. Check init container mount path
echo "=== Init Container Volume Mounts ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="create-flannel-dir")].volumeMounts[*]}' | jq -r '.[] | select(.name=="run") | "Mount: \(.mountPath)"'

# 3. Check the HostPath volume configuration
echo "=== HostPath Volume Configuration ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.volumes[?(@.name=="run")]}' | jq -r '.hostPath.path'

# 4. Try to exec into a running pod (if any) to verify directory exists
RUNNING_POD=$(kubectl get pods -n kube-system | grep flannel | grep Running | head -1 | awk '{print $1}')
if [ -n "$RUNNING_POD" ]; then
  echo "=== Checking directory in running pod ==="
  kubectl exec -n kube-system $RUNNING_POD -c kube-flannel -- ls -la /run/flannel 2>&1 || echo "Cannot exec (pod may be crashing)"
fi

# 5. Check if we can verify via a different method - check pod spec
echo "=== Pod Volume Mount Details ==="
kubectl get pod -n kube-system $(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}') -o jsonpath='{.spec.containers[?(@.name=="kube-flannel")].volumeMounts[*]}' | jq -r '.[] | select(.name=="run")'
```

**Important:** The init container mounted the volume at `/run`, so when it created `/run/flannel`, it should have created it on the host. However, if the main flannel container mounts the volume at a different path (e.g., directly at `/run/flannel`), there might be a mismatch. The main container should mount it at `/run/flannel` to match the HostPath.

### Solution 15: Check Pod Events When Logs Are Unavailable

Since TLS errors prevent log access, check pod events for error messages:

```bash
# 1. Get a failing pod
FAILING_POD=$(kubectl get pods -n kube-system | grep flannel | grep -v Running | head -1 | awk '{print $1}')
echo "Checking pod: $FAILING_POD"

# 2. Get detailed events for this pod
echo "=== Pod Events (most recent first) ==="
kubectl get events -n kube-system --field-selector involvedObject.name=$FAILING_POD --sort-by='.lastTimestamp' | tail -30

# 3. Get all flannel-related events
echo "=== All Flannel Events ==="
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep -i flannel | tail -40

# 4. Check if init container completed successfully
echo "=== Init Container Status ==="
kubectl get pod -n kube-system $FAILING_POD -o jsonpath='{.status.initContainerStatuses[*]}' | jq -r '.[] | "\(.name): \(.state)"' 2>/dev/null || \
kubectl get pod -n kube-system $FAILING_POD -o jsonpath='{.status.initContainerStatuses[0].state}' | grep -o '"terminated":{[^}]*}' || echo "Cannot parse init container status"

# 5. Check container exit codes
echo "=== Container Exit Codes ==="
kubectl get pod -n kube-system $FAILING_POD -o jsonpath='{.status.containerStatuses[?(@.name=="kube-flannel")].lastState}' | jq -r '.' 2>/dev/null || \
kubectl get pod -n kube-system $FAILING_POD -o yaml | grep -A 10 "lastState:" | head -20

# 6. Try to catch a pod while it's briefly running
echo "=== Attempting to catch running pod ==="
for i in {1..10}; do
  RUNNING=$(kubectl get pods -n kube-system | grep flannel | grep Running | head -1 | awk '{print $1}')
  if [ -n "$RUNNING" ]; then
    echo "Found running pod: $RUNNING"
    echo "Checking directory..."
    kubectl exec -n kube-system $RUNNING -c kube-flannel -- ls -la /run/flannel 2>&1 || echo "Cannot exec"
    echo "Checking if subnet.env exists..."
    kubectl exec -n kube-system $RUNNING -c kube-flannel -- test -f /run/flannel/subnet.env && echo "subnet.env exists" || echo "subnet.env missing"
    break
  fi
  echo "Waiting for pod to be running (attempt $i/10)..."
  sleep 2
done
```

**Note:** If the directory exists but flannel still crashes, the issue is likely:
- Flannel can't connect to the API server (check `KUBERNETES_SERVICE_HOST` and `KUBERNETES_SERVICE_PORT`)
- Flannel can't write to `/run/flannel/subnet.env` (permissions issue)
- Flannel is crashing due to a configuration error

### Solution 16: Fix Flannel Crashing Before Creating subnet.env

If the init container succeeds (directory created) but flannel crashes with exit code 1 before creating `subnet.env`, check flannel configuration:

```bash
# 1. Check flannel ConfigMap
echo "=== Flannel ConfigMap ==="
kubectl get configmap -n kube-system kube-flannel-cfg -o yaml

# 2. Check flannel daemonset environment variables
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')
echo "=== Flannel Environment Variables ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -A 30 "env:" | head -40

# 3. Check if API server endpoint is correct (Talos uses 127.0.0.1:7445)
echo "=== API Server Configuration ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -E "KUBERNETES_SERVICE|127.0.0.1|7445"

# 4. Check if the kubernetes service exists
echo "=== Kubernetes Service ==="
kubectl get svc -n default kubernetes

# 5. Check if we can manually create subnet.env to test permissions
# First, let's see what the init container actually created
echo "=== Checking what init container created ==="
# We can't exec into the init container (it's terminated), but we can check via a debug pod
# However, PodSecurity blocks this. Instead, let's check the daemonset to ensure permissions are correct

# 6. Check if flannel needs the directory to be writable by a specific user
echo "=== Checking flannel security context ==="
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml | grep -A 10 "securityContext:" | head -15

# 7. The issue might be that flannel needs to create subnet.env but crashes before doing so
# This could be due to API server connectivity. Let's check if we can reach the API server from a test pod
echo "=== Testing API Server Connectivity ==="
kubectl run test-api-connectivity --image=busybox:1.36 --rm -i --restart=Never -- sh -c "wget -qO- --no-check-certificate https://127.0.0.1:7445/api/v1/namespaces 2>&1 | head -5" || echo "Cannot test (PodSecurity may block)"
```

**Common causes:**
- **API server not accessible**: Flannel can't connect to `127.0.0.1:7445` (Talos API endpoint)
- **Configuration error**: Flannel ConfigMap has incorrect settings
- **Permissions**: Flannel can't write to `/run/flannel/subnet.env` (though directory exists)
- **Network timing**: API server isn't ready when flannel starts

**Quick fix attempt**: If the issue is API server connectivity, you may need to wait longer for the cluster to stabilize, or check if the Talos API endpoint is correct.

### Solution 17: Remove Hardcoded API Server Endpoint (Fix for Talos)

If flannel is hardcoded to use `127.0.0.1:7445` (Talos API endpoint) but that's not accessible, remove the hardcoded values and let Kubernetes inject them automatically:

```bash
# 1. Get daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')

# 2. Remove the hardcoded KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT
# This allows Kubernetes to automatically inject the correct service endpoint
kubectl patch daemonset -n kube-system $DAEMONSET_NAME --type='json' -p='
[
  {
    "op": "remove",
    "path": "/spec/template/spec/containers/0/env",
    "value": null
  }
]'

# Wait, that removes all env vars. Let's be more specific - remove only the hardcoded ones:
# First, get the current env vars to see the structure
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o jsonpath='{.spec.template.spec.containers[0].env[*]}' | jq -r '.[] | select(.name != "KUBERNETES_SERVICE_HOST" and .name != "KUBERNETES_SERVICE_PORT")'

# Actually, let's use a more targeted approach - remove specific env vars by index
# First, find the indices of KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT
# Then remove them

# Better approach: Export, edit, and reapply
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o yaml > /tmp/flannel-ds-fix.yaml

# Edit the file to remove KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT env vars
# Then reapply:
# kubectl apply -f /tmp/flannel-ds-fix.yaml

# Or use a JSON patch to remove specific env vars by filtering
```

**Simpler approach using JSON patch to remove specific environment variables:**

```bash
# 1. Get daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')

# 2. Export current daemonset
kubectl get daemonset -n kube-system $DAEMONSET_NAME -o json > /tmp/flannel-ds.json

# 3. Remove KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT from env array
# Using jq to filter them out
jq '.spec.template.spec.containers[0].env |= map(select(.name != "KUBERNETES_SERVICE_HOST" and .name != "KUBERNETES_SERVICE_PORT"))' /tmp/flannel-ds.json > /tmp/flannel-ds-fixed.json

# 4. Apply the fixed daemonset
kubectl apply -f /tmp/flannel-ds-fixed.json

# 5. Wait for rollout
kubectl rollout status daemonset/$DAEMONSET_NAME -n kube-system --timeout=120s

# 6. Check pods
kubectl get pods -n kube-system | grep flannel
```

**Alternative: Use kubectl patch with JSON merge:**

```bash
# This is tricky with JSON patch, so the export/edit/apply method above is more reliable
# But if you want to try, you need to provide the entire env array without those two vars
```

### Solution 18: Create Empty subnet.env File in Init Container

If flannel crashes because it tries to read `/run/flannel/subnet.env` on startup before creating it, create an empty file in the init container:

```bash
# 1. Get daemonset name
DAEMONSET_NAME=$(kubectl get daemonset -n kube-system | grep flannel | awk '{print $1}')

# 2. Update the init container to also create an empty subnet.env file
kubectl patch daemonset -n kube-system $DAEMONSET_NAME --type='json' -p='
[
  {
    "op": "replace",
    "path": "/spec/template/spec/initContainers/0/command",
    "value": ["sh", "-c", "mkdir -p /run/flannel && chmod 755 /run/flannel && touch /run/flannel/subnet.env && chmod 644 /run/flannel/subnet.env && ls -la /run/flannel"]
  }
]'

# 3. Wait for rollout
kubectl rollout status daemonset/$DAEMONSET_NAME -n kube-system --timeout=120s

# 4. Check pods
kubectl get pods -n kube-system | grep flannel
```

**Note:** Flannel should overwrite this file with the correct content once it successfully connects to the API server and gets the subnet information.

### Solution 19: Understanding the Root Cause - Flannel Daemon Must Write subnet.env

**The Real Problem:** The error message shows:
```
loadFlannelSubnetEnv failed: /run/flannel/subnet.env is missing FLANNEL_NETWORK, FLANNEL_IPV6_NETWORK, FLANNEL_SUBNET, FLANNEL_IPV6_SUBNET, FLANNEL_MTU, FLANNEL_IPMASQ
```

This means:
1. The `subnet.env` file exists (we created it)
2. But it's empty - flannel daemon hasn't written the required variables yet
3. The flannel daemon pod is crashing before it can write to the file
4. The CNI plugin (which runs on the node) tries to read this file when creating pod sandboxes and fails

**The flannel daemon must successfully start and write these variables to `/run/flannel/subnet.env`:**
- `FLANNEL_NETWORK` - The pod network CIDR (e.g., `10.244.0.0/16`)
- `FLANNEL_SUBNET` - The subnet for this specific node
- `FLANNEL_MTU` - The MTU for the network
- `FLANNEL_IPMASQ` - Whether to enable IP masquerading
- `FLANNEL_IPV6_NETWORK` and `FLANNEL_IPV6_SUBNET` (optional, for IPv6)

**Why is flannel daemon crashing?** Since we've fixed:
- ✅ API server endpoint (removed hardcoded `127.0.0.1:7445`)
- ✅ Directory creation (`/run/flannel` exists)
- ✅ File creation (`subnet.env` exists with proper permissions)

The remaining issue is likely that flannel daemon is still failing to connect to the API server or authenticate, or there's a configuration issue. Since we can't get logs due to TLS errors, we need to:

1. **Wait longer** - Sometimes flannel needs several minutes to fully initialize
2. **Check if API server is actually accessible** from within the pod
3. **Verify flannel configuration** matches the cluster setup
4. **Check if there are any other errors** in cluster events

**Next Steps:**
- Wait 5-10 minutes and check if flannel pods eventually stabilize
- Check if other pods can be created (if flannel works, CoreDNS should start)
- Consider reinstalling flannel if the issue persists

### Solution 20: Fix Missing br_netfilter Kernel Module (Root Cause Found!)

**The Real Problem:** Flannel is crashing because the `br_netfilter` kernel module is not loaded on the Talos nodes. The error in the logs shows:
```
E0113 21:33:06.416874       1 main.go:278] Failed to check br_netfilter: stat /proc/sys/net/bridge/bridge-nf-call-iptables: no such file or directory
```

**Note for Ubuntu VMs:** If you're running Talos nodes in containers on an Ubuntu VM created via `task vm:create`, the `br_netfilter` module is automatically configured on the Ubuntu host during VM setup. The module is loaded on boot via `/etc/modules-load.d/br_netfilter.conf` and sysctls are configured via `/etc/sysctl.d/99-kubernetes.conf`. Since Talos containers share the host kernel, they should be able to access the module automatically. If you're still seeing this error, verify the module is loaded on the Ubuntu host with `lsmod | grep br_netfilter` and check the sysctls with `cat /proc/sys/net/bridge/bridge-nf-call-iptables`.

**Solution:** Load the `br_netfilter` kernel module on all Talos nodes and configure it to load automatically.

#### For Talos Nodes:

1. **Check if the module is available:**
   ```bash
   # On each Talos node (using talosctl)
   talosctl -n <node-ip> read /proc/modules | grep br_netfilter
   ```

2. **Load the module temporarily (for testing):**
   ```bash
   # This requires modifying Talos machine config
   # The module needs to be loaded via Talos configuration
   ```

3. **Configure Talos to load br_netfilter automatically:**
   
   You need to update the Talos machine configuration to include kernel module loading. This is typically done in the Talos config file:

   ```yaml
   machine:
     kernel:
       modules:
         - name: br_netfilter
     sysctls:
       net.bridge.bridge-nf-call-iptables: "1"
       net.bridge.bridge-nf-call-ip6tables: "1"
   ```
   
   **Important:** You need both:
   - The `kernel.modules` section to load the module
   - The `sysctls` section to enable the bridge netfilter settings

   **To apply this:**
   
   **Important:** The output from `talosctl get mc` is in Kubernetes resource format. You need to extract the actual Talos config from the `spec: |` block:
   
   ```bash
   # 1. Get current machine config (saves in Kubernetes resource format)
   talosctl -n <node-ip> get mc -o yaml > node-config.yaml
   
   # 2. Extract the spec content (the actual Talos config is in the "spec: |" block)
   # Extract from first "spec: |" to first "---" separator
   awk '/^spec: \|$/{flag=1; next} /^---$/ && flag{exit} flag' node-config.yaml | sed 's/^    //' > node-config-clean.yaml
   
   # 3. Verify the format (should start with "version: v1alpha1", NOT "kind: Config")
   head -5 node-config-clean.yaml
   
   # 4. Verify br_netfilter is present
   grep -A 3 "br_netfilter" node-config-clean.yaml
   
   # 5. Apply the clean config
   talosctl -n <node-ip> apply-config --file node-config-clean.yaml
   ```
   
   **Note:** The `apply-config` command expects a pure Talos machine config (starting with `version: v1alpha1`), NOT the Kubernetes resource format (which has `kind: Config` at the top). The extraction step removes the Kubernetes wrapper and gets just the spec content.

6. **Verify the module is loaded:**
   ```bash
   # Check if module is loaded (may take a few minutes or require reboot)
   talosctl -n <node-ip> read /proc/modules | grep br_netfilter
   
   # Check if sysctls are set
   talosctl -n <node-ip> read /proc/sys/net/bridge/bridge-nf-call-iptables
   # Should return: 1
   ```
   
   **If the module is not loaded yet:**
   - Wait a few minutes for Talos to apply the configuration
   - If still not loaded, reboot the node:
     ```bash
     talosctl -n <node-ip> reboot
     ```

7. **If the module still doesn't load after reboot:**
   
   If you've configured `br_netfilter` in the machine config, applied it, and rebooted, but the module still isn't loading (sysctl files don't exist), this typically means:
   
   - **The module is not available in the Talos kernel build** (most common)
   - **The module needs to be built into the kernel** rather than loaded as a module
   - **There's an issue with how Talos applies the machine config**
   
   **Diagnostic steps:**
   ```bash
   # Check if module file exists (may not be accessible via talosctl read)
   # The error "path must be a regular file" when reading /lib/modules suggests
   # the directory structure is different or the module isn't available
   
   # Verify machine config is correct
   talosctl -n <node-ip> get mc -o yaml | grep -A 3 "br_netfilter"
   
   # Check kernel logs for module loading errors
   talosctl -n <node-ip> dmesg | grep -i "br_netfilter\|module"
   ```
   
   **Solutions if module is not available:**
   
   1. **Build a custom Talos image** with `br_netfilter` built into the kernel or as a loadable module
      - See: https://www.talos.dev/v1.9/guides/customizing-talos/
   
   2. **Use a different CNI** that doesn't require `br_netfilter`:
      - **Calico**: Doesn't require `br_netfilter`
      - **Cilium**: Modern CNI with better features
      - **Weave**: Alternative to Flannel
   
   3. **Check for Talos extensions** that might provide the module
      - Some Talos extensions include additional kernel modules
   
   4. **Use a Talos version** that includes the module (if available in newer versions)

4. **Alternative: Load module manually (temporary fix):**
   
   If you can access the node directly or via talosctl, you might be able to load it, but this won't persist across reboots:
   ```bash
   # This typically requires root access on the node
   # For Talos, you need to use machine config
   ```

**Note:** For Talos, kernel modules must be loaded via machine configuration. You'll need to:
1. Get the current machine config for each node
2. Add the `br_netfilter` module to the kernel modules list
3. Apply the updated config

**Quick Check:** After loading the module, verify it's loaded:
```bash
talosctl -n <node-ip> read /proc/sys/net/bridge/bridge-nf-call-iptables
# Should return: 1 (or 0, but the file should exist)
```

Once the module is loaded, flannel should start successfully!

## Prevention

1. **Ensure API server is ready** before installing CNI plugins
2. **Check node readiness** before deploying flannel
3. **Monitor disk space** to prevent taints
4. **Use init containers** if flannel needs service dependencies
5. **Wait for core services** (kube-dns/coredns and kubernetes service) to be ready before CNI installation
6. **Wait for the kubernetes service** in default namespace to be available
7. **Wait 5-10 minutes** after cluster creation for all components to stabilize

## Accessing Logs When TLS Errors Occur

If you're getting TLS errors when trying to access logs:
```
Error from server: Get "https://10.5.0.2:10250/containerLogs/...": remote error: tls: internal error
```

### Solution 20: Access Logs Directly on the Node

Since the pods run on Talos nodes, you can access logs directly on the node:

```bash
# 1. Find which node a pod is running on
kubectl get pods -n kube-system -o wide | grep flannel

# 2. Access the node (if you have SSH/talosctl access)
# For Talos nodes, use talosctl:
talosctl -n <node-ip> containers -k

# 3. Or check logs directly via containerd on the node
# SSH to the node and run:
sudo crictl logs <container-id>

# 4. Get container ID from the pod
POD_NAME=$(kubectl get pods -n kube-system | grep flannel | head -1 | awk '{print $1}')
CONTAINER_ID=$(kubectl get pod -n kube-system $POD_NAME -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's/containerd:\/\///')
echo "Container ID: $CONTAINER_ID"

# 5. If you can SSH to the node, check logs there
# On the node, run:
# sudo crictl logs $CONTAINER_ID
```

### Solution 21: Fix Kubelet TLS Issues

The TLS errors suggest kubelet certificate issues. This might resolve itself, or you may need to:

1. **Restart kubelet on the nodes** (if you have access):
   ```bash
   # On Talos, kubelet is managed by the system
   # You may need to restart the node or wait for certificates to refresh
   ```

2. **Check kubelet certificate expiration**:
   ```bash
   # On the node, check certificate:
   # sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
   ```

3. **Wait for certificate rotation** - Kubernetes automatically rotates certificates, but it may take time

4. **Use kubectl with different options**:
   ```bash
   # Try with previous logs (may work even if current logs fail)
   kubectl logs -n kube-system <pod-name> --previous
   
   # Try with timestamps
   kubectl logs -n kube-system <pod-name> --timestamps
   ```

### Solution 22: Check Logs via Events or Pod Status

Even without direct log access, you can get information:

```bash
# 1. Check pod events (often contains error messages)
kubectl describe pod -n kube-system <pod-name> | grep -A 20 "Events:"

# 2. Check container exit codes
kubectl get pod -n kube-system <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'

# 3. Check container restart reason
kubectl get pod -n kube-system <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# 4. Check all events for the namespace
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep <pod-name>
```

## Related Issues

- Disk pressure taints (see `docker-disk-pressure-fix.md`)
- API server connectivity issues
- Network plugin initialization timing
- Kubelet TLS certificate issues

