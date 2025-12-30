# Deploying Talos Cluster on IncusOS VMs

This guide walks you through deploying a Talos Linux Kubernetes cluster using virtual machines on an [IncusOS](https://linuxcontainers.org/incus-os/docs/main/getting-started/) system. You'll create 3 VMs: 1 control plane node and 2 worker nodes, then configure them to form a complete Kubernetes cluster.

## Overview

Deploying a Talos cluster on IncusOS VMs involves:

1. **Preparing the workspace**: Setting up the Windsor workspace and context
2. **Setting environment variables**: Configuring cluster and VM information
3. **Downloading Talos image**: Getting the Talos cloud image for VMs
4. **Creating network bridge**: Setting up network connectivity for VMs
5. **Launching VMs**: Creating 3 virtual machines (1 control plane, 2 workers)
6. **Configuring Talos**: Generating and applying Talos configuration to each VM
7. **Bootstrapping cluster**: Initializing the etcd cluster and retrieving kubeconfig
8. **Verifying cluster**: Confirming all nodes are healthy and operational

This approach allows you to run a complete Kubernetes cluster on a single physical IncusOS host, making it ideal for development, testing, or small production deployments.

## Prerequisites

Before starting, ensure you have:

- **IncusOS system**: An IncusOS host with Incus installed and running (see [IncusOS Setup](../incusos/incusos-setup.md))
- **Incus CLI client**: Installed and configured on your local machine
- **Incus remote configured**: Connected to your IncusOS server (see [IncusOS Setup](../incusos/incusos-setup.md))
- **Network access**: The IncusOS host must be on a network with available IP addresses
- **Sufficient resources**: At least 8GB RAM and 100GB storage on the IncusOS host for 3 VMs
- **talosctl installed**: See the [Installation Guide](../../install.md) for setup instructions
- **Workspace initialized**: Follow the [Initialize Workspace](../workspace/init.md) runbook if you haven't already

## System Requirements

Each VM will require:

- **Control plane VM**: Minimum 2GB RAM, 20GB disk
- **Worker VMs**: Minimum 2GB RAM, 20GB disk each
- **Total**: 6GB RAM and 60GB disk minimum (8GB RAM and 100GB disk recommended)

## Step 1: Initialize Workspace and Context

### Create Workspace (if not already done)

If you haven't already initialized a workspace, follow the [Initialize Workspace](../workspace/init.md) runbook:

```bash
task workspace:initialize -- talos-vm ../talos-vm
cd ../talos-vm
```

### Initialize Windsor Context

Create a new context for your Talos VM cluster:

```bash
windsor init talos-vm
```

Verify the context is set:

```bash
windsor context get
```

## Step 2: Set Environment Variables

### Add these lines to ./contexts/talos-vm/windsor.yaml

```yaml
environment:
  # Incus remote configuration
  INCUS_REMOTE_NAME: "nuc"
  INCUS_REMOTE_IP_0: "192.168.2.101"
  
  # Cluster configuration
  CLUSTER_NAME: "talos-vm-cluster"
  
  # VM IP addresses (must be on the same network as IncusOS host)
  CONTROL_PLANE_IP: "192.168.2.201"
  WORKER_0_IP: "192.168.2.202"
  WORKER_1_IP: "192.168.2.203"
  
  # VM names
  CONTROL_PLANE_VM: "talos-cp"
  WORKER_0_VM: "talos-worker-0"
  WORKER_1_VM: "talos-worker-1"
  
  # Talos image configuration
  TALOS_IMAGE_VERSION: "v1.11.6"
  TALOS_IMAGE_ARCH: "amd64"
  
  # Talos configuration paths
  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
  KUBECONFIG_FILE: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
```

**Note**: Replace the placeholder values with your actual configuration:
- `INCUS_REMOTE_NAME`: The name of your Incus remote (from `incus remote list`)
- `INCUS_REMOTE_IP_0`: The IP address of your IncusOS host
- `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP`: Available IP addresses on your network for the VMs
- `CLUSTER_NAME`: A name for your Kubernetes cluster
- `TALOS_IMAGE_VERSION`: The Talos version to use (check [Talos releases](https://github.com/siderolabs/talos/releases))

## Step 3: Download Talos Cloud Image

Download the Talos cloud image that will be used for the VMs:

```bash
task incus:download-talos-image
```

This will download the Talos cloud image to `contexts/<context>/devices/talos/talos-cloud-amd64.tar.gz`.

## Step 4: Create Network Bridge (if needed)

If you haven't already created a network bridge for your VMs, create one that connects to your physical network:

```bash
task incus:create-network-bridge
```

This creates a bridge network that allows VMs to get IP addresses on your physical network. The bridge will use the network interface and IP range you configure.

**Note**: If you already have a network bridge configured, you can skip this step. Check existing networks with `incus network list <remote-name>:`.

## Step 5: Launch Virtual Machines

Launch the three VMs that will form your Talos cluster:

### Launch Control Plane VM

```bash
task incus:launch-talos-vm -- {{.CONTROL_PLANE_VM}} {{.CONTROL_PLANE_IP}}
```

### Launch Worker VMs

```bash
task incus:launch-talos-vm -- {{.WORKER_0_VM}} {{.WORKER_0_IP}}
task incus:launch-talos-vm -- {{.WORKER_1_VM}} {{.WORKER_1_IP}}
```

**Note**: The VMs will boot and start Talos. Wait a few minutes for them to fully boot before proceeding to the next step.

### Verify VMs are Running

Check that all VMs are running:

```bash
incus list <remote-name>:
```

You should see all three VMs listed with a "Running" status.

## Step 6: Wait for VMs to Boot

Wait for the VMs to fully boot and become accessible. You can check their status:

```bash
# Check VM status
incus list <remote-name>:

# Ping the VMs to verify network connectivity
ping -c 3 {{.CONTROL_PLANE_IP}}
ping -c 3 {{.WORKER_0_IP}}
ping -c 3 {{.WORKER_1_IP}}
```

**Note**: It may take 2-3 minutes for the VMs to fully boot and become accessible.

## Step 7: Generate Talos Configuration

Generate the Talos configuration files for your cluster. For VMs, we'll use the virtual disk device:

```bash
task device:generate-talosconfig -- /dev/vda
```

This generates:
- `controlplane.yaml` - Configuration for the control plane node
- `worker.yaml` - Configuration for worker nodes
- `talosconfig.yaml` - Client configuration file

**Note**: VMs typically use `/dev/vda` as the primary disk. If your VMs use a different disk, adjust accordingly.

## Step 8: Apply Talos Configuration

Apply the Talos configuration to all three VMs:

```bash
task device:apply-configuration -- {{.CONTROL_PLANE_IP}} {{.WORKER_0_IP}} {{.WORKER_1_IP}}
```

This command will:
1. Apply `controlplane.yaml` to the control plane VM
2. Apply `worker.yaml` to both worker VMs

After the configuration is applied, the VMs will reboot and join the cluster.

## Step 9: Set Talos Endpoints

Configure the Talos client to use the correct endpoints:

```bash
task device:set-endpoints -- {{.CONTROL_PLANE_IP}}
```

This sets the control plane IP as the endpoint for Talos API access.

## Step 10: Bootstrap the etcd Cluster

Wait for the control plane VM to finish booting (usually 1-2 minutes after Step 8), then bootstrap the etcd cluster:

```bash
task device:bootstrap-etc-cluster -- {{.CONTROL_PLANE_IP}}
```

**Important**: Run this command ONCE on a SINGLE control plane node. This initializes the etcd cluster that stores Kubernetes cluster state.

## Step 11: Retrieve Kubernetes Access

Download the kubeconfig file to access your Kubernetes cluster:

```bash
task device:retrieve-kubeconfig -- {{.CONTROL_PLANE_IP}}
```

This downloads the kubeconfig to `contexts/<context>/.kube/config`.

## Step 12: Verify Cluster Health

Check that all nodes are healthy:

```bash
task device:cluster-health -- {{.CONTROL_PLANE_IP}}
```

This will show the health status of all nodes in your cluster.

## Step 13: Verify Node Registration

Confirm that all nodes are registered in Kubernetes:

```bash
kubectl get nodes
```

You should see all three nodes listed:
- 1 control plane node (with `control-plane` role)
- 2 worker nodes

All nodes should show a "Ready" status.

## Verification

Verify your Talos cluster is fully operational:

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

Your Talos cluster should now be fully operational and ready for workloads.

## Managing VMs

### View VM Status

```bash
incus list <remote-name>:
```

### Stop a VM

```bash
incus stop <remote-name>:<vm-name>
```

### Start a VM

```bash
incus start <remote-name>:<vm-name>
```

### Delete a VM

```bash
# Stop the VM first
incus stop <remote-name>:<vm-name>

# Delete the VM
incus delete <remote-name>:<vm-name>
```

**Warning**: Deleting a VM will destroy all data on that VM. Ensure you have backups or can recreate the cluster if needed.

### Access VM Console

```bash
incus console <remote-name>:<vm-name>
```

## Troubleshooting

### VMs Not Booting

- Verify the Talos image was downloaded correctly
- Check VM resources (RAM, disk) are sufficient
- Review VM logs: `incus info <remote-name>:<vm-name>`
- Check network bridge is configured correctly

### Cannot Connect to VMs

- Verify network bridge is created and configured
- Check IP addresses are on the correct network subnet
- Ensure firewall rules allow access to VM IPs
- Verify VMs have network connectivity: `incus exec <remote-name>:<vm-name> -- ping 8.8.8.8`

### Talos Configuration Fails

- Verify VMs are fully booted before applying configuration
- Check that IP addresses are correct and reachable
- Ensure talosctl can connect: `talosctl --nodes {{.CONTROL_PLANE_IP}} version`
- Review Talos logs: `incus exec <remote-name>:<vm-name> -- journalctl -u talos`

### Cluster Bootstrap Fails

- Ensure control plane VM is fully booted and accessible
- Verify etcd is not already bootstrapped (only bootstrap once)
- Check Talos API is accessible: `talosctl --nodes {{.CONTROL_PLANE_IP}} version`
- Review control plane logs for errors

### Nodes Not Joining Cluster

- Verify worker VMs are fully booted
- Check that worker configuration was applied correctly
- Ensure control plane is bootstrapped before workers join
- Verify network connectivity between all VMs

### Insufficient Resources

If VMs fail to start due to resource constraints:

- Reduce VM memory allocation (minimum 2GB per VM)
- Check available disk space on IncusOS host
- Verify CPU resources are available
- Consider reducing the number of VMs or upgrading hardware

## Next Steps

After successfully deploying your Talos cluster:

1. **Deploy workloads**: Start deploying applications to your cluster
2. **Configure storage**: Set up persistent storage for your workloads
3. **Set up networking**: Configure CNI and ingress controllers
4. **Enable monitoring**: Deploy monitoring and logging solutions
5. **Configure backups**: Set up etcd backups for disaster recovery
6. **Scale the cluster**: Add more worker nodes as needed

## Additional Resources

- [Talos Documentation](https://www.talos.dev/)
- [IncusOS Setup](../incusos/incusos-setup.md) - Setting up IncusOS
- [Bootstrapping Nodes](../bootstrapping/README.md) - Physical node bootstrapping
- [Initialize Workspace](../workspace/init.md) - Workspace setup
