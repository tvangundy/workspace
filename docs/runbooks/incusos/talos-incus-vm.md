# Talos Cluster on IncusOS VMs

This guide walks you through deploying a Talos Linux Kubernetes cluster using virtual machines on an [IncusOS](https://linuxcontainers.org/incus-os/docs/main/getting-started/) system. You'll create 3 VMs: 1 control plane node and 2 worker nodes, then configure them to form a complete Kubernetes cluster.

## Overview

Deploying a Talos cluster on IncusOS VMs involves:

1. **Preparing the workspace**: Setting up the Windsor workspace and context
2. **Setting environment variables**: Configuring cluster and VM information, including getting the Talos Image Factory schematic ID
3. **Downloading Talos image**: Getting the Talos Linux image for VMs
4. **Creating network bridge**: Setting up network connectivity for VMs
5. **Launching VMs**: Creating 3 virtual machines (1 control plane, 2 workers)
6. **Waiting for VMs to boot**: Ensuring Talos has fully booted on all nodes
7. **Updating IP addresses**: Finding actual DHCP-assigned IPs and updating configuration
8. **Configuring Talos**: Generating and applying Talos configuration to each VM
9. **Bootstrapping cluster**: Initializing the etcd cluster and retrieving kubeconfig
10. **Verifying cluster**: Confirming all nodes are healthy and operational

This approach allows you to run a complete Kubernetes cluster on a single physical IncusOS host, making it ideal for development, testing, or small production deployments.

## Prerequisites

- Incus client installed on your local machine
- IncusOS server set up and accessible (see [IncusOS Setup](setup.md))
- Incus remote configured (see [IncusOS Setup - Step 7](setup.md#step-7-connect-to-incus-server))
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- talosctl installed (see the [Installation Guide](../../install.md) for setup instructions)
- Sufficient resources: At least 8GB RAM and 100GB storage on the IncusOS host for 3 VMs
- Network access: The IncusOS host must be on a network with available IP addresses

## System Requirements

Each VM will require:

- **Control plane VM**: Minimum 2GB RAM, 20GB disk
- **Worker VMs**: Minimum 2GB RAM, 20GB disk each
- **Total**: 6GB RAM and 60GB disk minimum (8GB RAM and 100GB disk recommended)

## Step 1: Set Environment Variables

### Get Talos Image Schematic ID

Before setting the environment variables, you need to get a schematic ID from the [Talos Image Factory](https://factory.talos.dev):

1. Visit [https://factory.talos.dev](https://factory.talos.dev)
2. Create a schematic (or use the default/empty schematic)
3. Copy the schematic ID

**Note**: For a basic/default Talos image, you can use an empty schematic or create a minimal schematic with default settings.

### Add these lines to ./contexts/talos-vm/windsor.yaml

```yaml
environment:
  # Incus remote configuration
  INCUS_REMOTE_NAME: "nuc"
  INCUS_REMOTE_IP_0: "192.168.2.101"
  
  # Cluster configuration
  CLUSTER_NAME: "talos-vm-cluster"
  
  # VM IP addresses (must be on the same network as IncusOS host)
  CONTROL_PLANE_IP: "192.168.2.84"
  WORKER_0_IP: "192.168.2.25"
  WORKER_1_IP: "192.168.2.74"
  
  # VM names
  CONTROL_PLANE_VM: "talos-cp"
  WORKER_0_VM: "talos-worker-0"
  WORKER_1_VM: "talos-worker-1"
  
  # Talos image configuration
  # Get schematic ID from https://factory.talos.dev
  TALOS_IMAGE_SCHEMATIC_ID: "<your-schematic-id>"
  TALOS_IMAGE_VERSION: "v1.12.0"
  TALOS_IMAGE_ARCH: "metal-amd64"
  
  # Physical network interface (optional, defaults to eno1)
  # PHYSICAL_INTERFACE: "eno1"
  
  # Talos configuration paths
  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
  KUBECONFIG_FILE: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
```

**Note**: Replace the placeholder values with your actual configuration:

- `INCUS_REMOTE_NAME`: The name of your Incus remote (from `incus remote list`)
- `INCUS_REMOTE_IP_0`: The IP address of your IncusOS host
- `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP`: Available IP addresses on your network for the VMs (these will be assigned by DHCP)
- `CLUSTER_NAME`: A name for your Kubernetes cluster
- `TALOS_IMAGE_SCHEMATIC_ID`: The schematic ID you obtained from the Talos Image Factory (replace `<your-schematic-id>` with the actual ID)
- `TALOS_IMAGE_VERSION`: The Talos version to use (check [Talos releases](https://github.com/siderolabs/talos/releases))
- `TALOS_IMAGE_ARCH`: The architecture (typically `metal-amd64` for Intel NUC)
- `PHYSICAL_INTERFACE`: (Optional) Your physical network interface name (defaults to `eno1` if not set)

## Step 2: Download Talos Linux Image

Download the Talos Linux image that will be used for the VMs:

```bash
task incus:download-talos-image
```

This will:

1. Download the Talos Linux raw disk image from the Image Factory (`.raw.zst` format, compressed with zstd)
2. Extract the compressed image using `zstd`
3. Convert it to QCOW2 format (required for Incus VMs)

The final image will be at `contexts/talos-vm/devices/talos/talos-metal-amd64.qcow2`.

**Note**: This task requires `zstd` and `qemu-img` to be installed:

- **macOS**: `brew install zstd qemu`
- **Linux**: `apt-get install zstd qemu-utils` (or equivalent for your distribution)

## Step 3: Configure Direct Network Attachment

To allow VMs to get IP addresses directly on your physical network, you need to configure a physical network interface for direct attachment. This creates a network that bypasses NAT and connects VMs directly to your physical network.

### Step 3a: View Current Network Configuration

First, check the current network configuration:

```bash
incus admin os system network show
```

This shows your network interfaces and their current roles.

### Step 3b: Add Instances Role to Physical Interface

Edit the network configuration to add the `instances` role to your physical network interface (typically `eno1` or `eth0`):

```bash
incus admin os system network edit
```

In the editor, find your physical interface (e.g., `eno1`) in the `config.interfaces` section. **Add a `roles` field** if it doesn't exist, and include `instances` in the list:

```yaml
config:
  interfaces:
  - addresses:
    - dhcp4
    - slaac
    hwaddr: 88:ae:dd:03:f9:f4
    name: eno1
    required_for_online: "no"
    roles:          # Add this field if it doesn't exist
    - management
    - cluster
    - instances     # Add this line
```

**Important**: 

- The `roles` field must be added to the `config.interfaces` section (not just the `state` section)
- Make sure the YAML indentation is correct (2 spaces)
- Save the file (in vim: press `Esc`, then type `:wq` and press Enter; in nano: press `Ctrl+X`, then `Y`, then Enter)

After saving, the configuration will be applied automatically. Verify the change:

```bash
incus admin os system network show
```

You should see `instances` in the `state.interfaces.eno1.roles` list.

### Step 3c: Create Physical Network

After the configuration is applied, create a managed physical network:

```bash
task incus:create-physical-network
```

This creates a physical network that directly attaches to your host's network interface, allowing VMs to get IP addresses directly from your physical network's DHCP server.

**Note**: 
   If the physical network already exists, the task will verify it's correctly configured and skip creation. If you need to recreate it, delete it first with `incus network delete <remote-name>:<interface-name>`.

**Note**: 

- Replace `eno1` with your actual physical network interface name if different. Common interface names include `eno1`, `eth0`, `enp5s0`, etc.
- You can override the interface name by setting the `PHYSICAL_INTERFACE` environment variable in your `windsor.yaml` file.
- After this step, VMs launched with this network will get IP addresses directly from your physical network's DHCP server, bypassing NAT.

## Step 4: Launch Virtual Machines

Launch the three VMs that will form your Talos cluster:

### Launch Control Plane VM

```bash
task incus:launch-talos-vm -- $CONTROL_PLANE_VM $CONTROL_PLANE_IP
```

### Launch Worker VMs

```bash
task incus:launch-talos-vm -- $WORKER_0_VM $WORKER_0_IP
task incus:launch-talos-vm -- $WORKER_1_VM $WORKER_1_IP
```

**Note**: 

- The VMs will boot and start Talos. Wait a few minutes for them to fully boot before proceeding to the next step.
- Secure Boot is automatically disabled for Talos Linux VMs (Talos doesn't support Secure Boot).

### Verify VMs are Running

Check that all VMs are running:

```bash
incus list <remote-name>:
```

You should see all three VMs listed with a "Running" status.

## Step 5: Wait for VMs to Boot

Wait for the VMs to fully boot and become accessible. You can check their status:

```bash
# Check VM status
incus list <remote-name>:

# Check detailed VM information including network interfaces
incus info <remote-name>:<vm-name>

# Check network configuration for a specific VM
incus config show <remote-name>:<vm-name> | grep -A 10 "devices:"
```

**Note**: It may take 2-3 minutes for the VMs to fully boot and become accessible.

**Important Note About IP Addresses**: With direct network attachment (physical network), `incus list` may not show IP addresses even though the VMs have them. This is because the VMs get IP addresses directly from your DHCP server, not through Incus's network management. To find the actual IP addresses:

1. **Check the Talos console** (via web UI or `incus console`) - Talos displays its IP address during boot
2. **Check your router's DHCP lease table** - Look for devices with MAC addresses matching your VMs
3. **Ping from the network** - If you know the expected IP range, you can ping to find active hosts

The IP addresses assigned by DHCP may differ from the ones you specified in your environment variables (`CONTROL_PLANE_IP`, etc.). For production use, it's recommended to configure static IP addresses either:

- **Via DHCP reservations in your router** (recommended for home networks) - Reserve specific IPs for each VM's MAC address
- **In Talos configuration** - Set static IPs in the Talos machine configuration (see Step 7: Generate Talos Configuration)

**Important**: If you added the `instances` role to the network interface after creating the VMs, you may need to restart the VMs for them to get IP addresses:

```bash
# Restart all VMs
incus restart <remote-name>:talos-cp
incus restart <remote-name>:talos-worker-0
incus restart <remote-name>:talos-worker-1

# Or restart all at once
incus restart <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
```

After restarting, wait a minute or two for the VMs to boot and get IP addresses from DHCP, then check again:

```bash
incus list <remote-name>:
```

## Step 6: Update IP Addresses in Configuration

After the VMs have booted and Talos is running, you need to update the IP addresses in your `windsor.yaml` file to match the actual DHCP-assigned IPs. The IPs shown in the Talos console may differ from what you initially configured.

### Find the Actual IP Addresses

1. **Check the Incus Web UI console** for each VM:

   - Open `https://<incus-host-ip>:8443` in your browser
   - Navigate to each VM (talos-cp, talos-worker-0, talos-worker-1)
   - Open the console view
   - Look for the IP address displayed during Talos boot (it will be shown in the console output)

2. **Alternative: Check your router's DHCP lease table**:

   - Log into your router's admin interface
   - Find the DHCP lease table or connected devices
   - Look for devices with MAC addresses matching your VMs
   - Note the IP addresses assigned to each VM

### Update windsor.yaml

Edit `contexts/talos-vm/windsor.yaml` and update the IP addresses:

```yaml
environment:
  # ... other configuration ...
  
  # Update these with the actual DHCP-assigned IPs from the console
  CONTROL_PLANE_IP: "192.168.2.XXX"  # Replace with actual IP from talos-cp console
  WORKER_0_IP: "192.168.2.XXX"        # Replace with actual IP from talos-worker-0 console
  WORKER_1_IP: "192.168.2.XXX"       # Replace with actual IP from talos-worker-1 console
```

**Important**: These IP addresses are used in subsequent steps for:

- Generating Talos configuration
- Applying configuration to nodes
- Setting Talos endpoints
- Bootstrapping the etcd cluster
- Retrieving kubeconfig
- Health checks

After updating the file, confirm the environment IP Addresses using:

```bash
windsor env
```

**Note**: If you prefer static IPs, you can configure DHCP reservations in your router to ensure the VMs always get the same IPs, or configure static IPs in the Talos machine configuration (see Step 7: Generate Talos Configuration).

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

### Troubleshooting: Boot Menu / No Bootable Device

If the VM shows a boot menu asking to select a boot device, the root disk may not be configured as bootable. Fix this on existing VMs:

```bash
# Override the root device to set boot priority (since it comes from profile)
incus config device override <remote-name>:talos-cp root boot.priority=1
incus config device override <remote-name>:talos-worker-0 root boot.priority=1
incus config device override <remote-name>:talos-worker-1 root boot.priority=1

# Stop and start the VMs (stop/start is more reliable than restart for boot changes)
incus stop <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
incus start <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
```

**Note**: If the VMs are stuck in the boot menu, you may need to force stop them first:
```bash
incus stop --force <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
incus start <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
```

**Note**: New VMs launched with `task incus:launch-talos-vm` will automatically have the root disk configured with boot priority.

### Troubleshooting: Secure Boot Error

If you see a Secure Boot error in the VM console (e.g., "Access Denied -- rejected probably by Secure Boot"), Talos Linux doesn't support Secure Boot. Disable it on the VMs:

```bash
# Disable Secure Boot on existing VMs
incus config set <remote-name>:talos-cp security.secureboot=false
incus config set <remote-name>:talos-worker-0 security.secureboot=false
incus config set <remote-name>:talos-worker-1 security.secureboot=false

# Restart the VMs
incus restart <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
```

**Note**: New VMs launched with `task incus:launch-talos-vm` will automatically have Secure Boot disabled.

### Troubleshooting: IP Addresses Not Showing in `incus list`

**Note**: With direct network attachment, `incus list` may not display IP addresses even though the VMs have them. This is normal behavior - the VMs get IPs directly from DHCP, not through Incus.

To verify the VMs have IP addresses:

1. **Check the Talos console** - The IP address is displayed during boot
2. **Check your router's DHCP lease table** - Look for the VM MAC addresses
3. **Ping the expected IP addresses** - `ping $CONTROL_PLANE_IP` (adjust if DHCP assigned different IPs)

If the VMs truly don't have IP addresses, check the following:

1. **Verify the physical network exists:**
   ```bash
   incus network list <remote-name>:
   incus network show <remote-name>:eno1
   ```

2. **Check if the `instances` role was added to eno1:**
   ```bash
   incus admin os system network show
   ```
   Look for `eno1` in the output and verify it has `instances` in the `roles` list.

3. **Check VM network device configuration:**
   ```bash
   incus config device show <remote-name>:<vm-name>
   ```
   The VM should have a `nic0` device attached to the physical network.

4. **Check if DHCP is working on your network:**
   - Verify other devices on the same network can get IP addresses
   - Check your router's DHCP server is running

5. **Wait longer for DHCP assignment:**
   - Sometimes VMs need 3-5 minutes to fully boot and get IP addresses
   - Check again after a few minutes: `incus list <remote-name>:`

6. **Manually check VM network status:**
   ```bash
   # Get console access to check network inside the VM
   incus console <remote-name>:<vm-name>
   # Then inside the VM, check: ip addr show
   ```

## Step 8: Apply Talos Configuration

Apply the Talos configuration to all three VMs:

```bash
task device:apply-configuration -- $CONTROL_PLANE_IP $WORKER_0_IP $WORKER_1_IP
```

This command will:

1. Apply `controlplane.yaml` to the control plane VM
2. Apply `worker.yaml` to both worker VMs

After the configuration is applied, the VMs will reboot and join the cluster.

## Step 9: Set Talos Endpoints

Configure the Talos client to use the correct endpoints:

```bash
task device:set-endpoints -- $CONTROL_PLANE_IP
```

This sets the control plane IP as the endpoint for Talos API access.

## Step 10: Bootstrap the etcd Cluster

Wait for the control plane VM to finish booting (usually 1-2 minutes after Step 8: Apply Talos Configuration), then bootstrap the etcd cluster:

```bash
task device:bootstrap-etc-cluster -- $CONTROL_PLANE_IP
```

**Important**: Run this command ONCE on a SINGLE control plane node. This initializes the etcd cluster that stores Kubernetes cluster state.

## Step 11: Retrieve Kubernetes Access

Download the kubeconfig file to access your Kubernetes cluster:

```bash
task device:retrieve-kubeconfig -- $CONTROL_PLANE_IP
```

This downloads the kubeconfig to `contexts/talos-vm/.kube/config`.

## Step 12: Verify Cluster Health

Check that all nodes are healthy:

```bash
task device:cluster-health -- $CONTROL_PLANE_IP
```

This will show the health status of all nodes in your cluster.

## Step 13: Verify Node Registration

Confirm that all nodes are registered in Kubernetes:

```bash
kubectl get nodes
```

You should see all three nodes listed:

- 1 control plane node (with `control-plane` role)
- 2 worker nodes (showing `<none>` in the ROLES column - this is normal)

All nodes should show a "Ready" status.

**Note**: In Kubernetes, worker nodes don't have a role label by default. Only control plane nodes get the `node-role.kubernetes.io/control-plane` label automatically. Worker nodes will show `<none>` in the ROLES column, which is expected behavior. You can verify they are worker nodes by checking that they don't have the control-plane label:

```bash
kubectl get nodes --show-labels | grep -v control-plane
```

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

## Destroying the Cluster

To completely destroy the Talos cluster and remove all resources, use the cleanup task:

```bash
task talos:cleanup
```

This task will:

### What Gets Cleaned Up

1. **Virtual Machines** (Required):
   - Stops and deletes the control plane VM (`${CONTROL_PLANE_VM}`)
   - Stops and deletes worker-0 VM (`${WORKER_0_VM}`)
   - Stops and deletes worker-1 VM (`${WORKER_1_VM}`)
   - **Warning**: This permanently destroys all data on these VMs, including:
     - Kubernetes cluster state (etcd data)
     - All workloads and pods
     - Persistent volumes
     - Any data stored on the VMs

2. **Configuration Files** (Optional - manual cleanup):
   - Talos cluster configuration: `contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}/`
   - Talos client config: `contexts/${WINDSOR_CONTEXT}/.talos/talosconfig`
   - Kubernetes kubeconfig: `contexts/${WINDSOR_CONTEXT}/.kube/config`
   - **Note**: These are not automatically deleted. You can keep them for future reference or manually remove them if needed.

3. **Talos Image** (Optional - manual cleanup):
   - Downloaded Talos image: `contexts/${WINDSOR_CONTEXT}/devices/talos/talos-metal-amd64.qcow2`
   - **Note**: The image is not automatically deleted. You can keep it to reuse for future clusters, or manually remove it to free up disk space.

4. **Physical Network** (Not cleaned up):
   - The physical network created for the cluster is **not** deleted
   - **Reason**: The network can be shared across multiple clusters and VMs
   - **Note**: If you want to remove it, you must do so manually with `incus network delete ${INCUS_REMOTE_NAME}:${PHYSICAL_INTERFACE:-eno1}` (only if no other VMs are using it)

### Manual Cleanup (Optional)

After running `task talos:cleanup`, you can optionally clean up configuration files and images:

```bash
# Remove Talos configuration files (optional)
rm -rf contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}
rm -f contexts/${WINDSOR_CONTEXT}/.talos/talosconfig
rm -f contexts/${WINDSOR_CONTEXT}/.kube/config

# Remove Talos image to free up disk space (optional)
rm -f contexts/${WINDSOR_CONTEXT}/devices/talos/talos-metal-amd64.qcow2
```

**Note**: Only remove these if you're sure you won't need them again. Keeping them allows you to recreate the cluster with the same settings or reuse the image.

### Verification

After cleanup, verify that all cluster VMs have been removed:

```bash
incus list ${INCUS_REMOTE_NAME}:
```

The cluster VMs should no longer appear in the list.

### Important Notes

- **Data Loss**: Destroying the cluster will permanently delete all Kubernetes data, workloads, and persistent volumes. Ensure you have backups if needed.
- **Network**: The physical network can be reused for other clusters, so it's not deleted automatically.
- **Images**: The Talos image can be reused, so it's not deleted automatically.
- **Recreation**: To recreate the cluster, simply follow this runbook again from the beginning.

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
- Ensure talosctl can connect: `talosctl --nodes $CONTROL_PLANE_IP version`
- Review Talos logs: `incus exec <remote-name>:<vm-name> -- journalctl -u talos`

### Cluster Bootstrap Fails

- Ensure control plane VM is fully booted and accessible
- Verify etcd is not already bootstrapped (only bootstrap once)
- Check Talos API is accessible: `talosctl --nodes $CONTROL_PLANE_IP version`
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
- [IncusOS Setup](setup.md) - Setting up IncusOS
- [Bootstrapping Nodes](../bootstrapping/README.md) - Physical node bootstrapping
- [Initialize Workspace](../workspace/init.md) - Workspace setup

