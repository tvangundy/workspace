# Talos Kubernetes Cluster on IncusOS

This runbook guides you through deploying a three-node Talos Linux Kubernetes cluster on a remote IncusOS server using Terraform. You'll create 3 VMs (1 control plane node and 2 worker nodes) and configure them to form a complete Kubernetes cluster using Infrastructure as Code.

## Overview

Talos clusters on IncusOS provide:

- Complete Kubernetes cluster with control plane and worker nodes
- Infrastructure as Code using Terraform for declarative management
- Talos Linux - a secure, minimal, immutable Linux distribution designed for Kubernetes
- Direct network access for cluster nodes
- Persistent storage and configurations
- Easy cluster lifecycle management (create, update, destroy)

## Prerequisites

- IncusOS server installed and running (see [IncusOS Setup](setup.md))
- Incus CLI client installed on your local machine
- Remote connection to your IncusOS server configured
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- Sufficient resources: At least 8GB RAM and 100GB storage on the IncusOS host for 3 VMs
- Network access: The IncusOS host must be on a network with available IP addresses

## Step 1: Install Tools Dependencies

To deploy the Talos cluster using Terraform, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/).

Ensure your `aqua.yaml` includes the following packages required for this runbook. Add any missing packages to your existing `aqua.yaml`:

```yaml
packages:
- name: hashicorp/terraform@v1.10.3
- name: siderolabs/talos@v1.9.1
- name: kubernetes/kubectl@v1.32.0
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
- name: lxc/incus@v6.20.0
- name: helm/helm@v3.17.3
- name: fluxcd/flux2@v2.5.1
- name: derailed/k9s@v0.50.3
- name: go-task/task@v3.42.1
```

Install the tools, run in the workspace root folder:

```bash
aqua install
```

## Step 2: Configure Environment Variables

### Get Talos Image Schematic ID

Before setting the environment variables, you need to get a schematic ID from the [Talos Image Factory](https://factory.talos.dev):

1. Visit [https://factory.talos.dev](https://factory.talos.dev)
2. Create a schematic (or use the default/empty schematic)
3. Copy the schematic ID

**Note**: For a basic/default Talos image, you can use an empty schematic or create a minimal schematic with default settings.

### Add these lines to `contexts/${WINDSOR_CONTEXT}/windsor.yaml`

```yaml
environment:
  # Incus remote configuration
  INCUS_REMOTE_NAME: "nuc"
  
  # Cluster configuration
  CLUSTER_NAME: "talos-vm-cluster"
  
  # VM IP addresses (must be on the same network as IncusOS host)
  # Leave empty for new installations - Terraform will prompt you to fill them in after VMs are created
  CONTROL_PLANE_IP: ""
  WORKER_0_IP: ""
  WORKER_1_IP: ""
  
  # VM names (optional, defaults shown)
  CONTROL_PLANE_VM: "talos-cp"
  WORKER_0_VM: "talos-worker-0"
  WORKER_1_VM: "talos-worker-1"
  
  # Talos image configuration
  # Get schematic ID from https://factory.talos.dev
  TALOS_IMAGE_SCHEMATIC_ID: "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
  TALOS_IMAGE_VERSION: "v1.12.0"
  TALOS_IMAGE_ARCH: "metal-amd64"
  
  # Physical network interface (optional, defaults to eno1)
  # PHYSICAL_INTERFACE: "eno1"
  
  # Storage pool (optional, defaults to local)
  STORAGE_POOL: "local"
  
  # VM resources (optional, defaults shown)
  # CONTROL_PLANE_MEMORY: "2GB"
  # CONTROL_PLANE_CPU: "2"
  # WORKER_MEMORY: "2GB"
  # WORKER_CPU: "2"
  
  # Common configuration patches (optional)
  # Example for br_netfilter kernel module:
  # COMMON_CONFIG_PATCHES: |
  #   "machine":
  #     "kernel":
  #       "modules":
  #       - "name": "br_netfilter"
  #     "sysctls":
  #       "net.bridge.bridge-nf-call-iptables": "1"
  #       "net.bridge.bridge-nf-call-ip6tables": "1"
  
  # Talos configuration paths (REQUIRED - must be set)
  # These paths are used by Terraform and talosctl commands throughout the deployment
  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
  KUBECONFIG_FILE: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
```

**Important**: The `TALOSCONFIG` and `KUBECONFIG_FILE` environment variables are **required** and must be set. These paths are used by:
- Terraform to save the Talos configuration file
- `talosctl` commands to locate the configuration
- `kubectl` commands to access the Kubernetes cluster

The paths shown above are the standard locations. Do not change them unless you have a specific reason to do so.

**Note**: Replace the placeholder values with your actual configuration:
- `INCUS_REMOTE_NAME`: The name of your Incus remote (from `incus remote list`)
- `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP`: Expected IP addresses on your network for the VMs (leave empty for new installations - Terraform will prompt you to fill them in after VMs are created)
- `CLUSTER_NAME`: A name for your Kubernetes cluster
- `TALOS_IMAGE_SCHEMATIC_ID`: The schematic ID you obtained from the Talos Image Factory (replace with the actual ID)
- `TALOS_IMAGE_VERSION`: The Talos version to use (check [Talos releases](https://github.com/siderolabs/talos/releases))
- `TALOS_IMAGE_ARCH`: The architecture (typically `metal-amd64` for Intel NUC)
- `PHYSICAL_INTERFACE`: (Optional) Your physical network interface name (defaults to `eno1` if not set)
- `STORAGE_POOL`: (Optional) Name of the Incus storage pool (defaults to `local`)
- `CONTROL_PLANE_MEMORY`, `CONTROL_PLANE_CPU`, `WORKER_MEMORY`, `WORKER_CPU`: (Optional) VM resource allocations (defaults: 2GB memory, 2 CPUs)
- `COMMON_CONFIG_PATCHES`: (Optional) YAML string with common configuration patches for all nodes
- `TALOSCONFIG`: **Required** - Path to the Talos configuration file (typically `$WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig`)
- `KUBECONFIG_FILE`: **Required** - Path to the kubeconfig file (typically `$WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config`)

## Step 3: Verify Remote Connection

Before creating the cluster, verify you can connect to your IncusOS server:

```bash
# List configured remotes
incus remote list

# Verify you can connect to your remote
incus list <remote-name>:

# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
```

**Expected output:**

- Your remote should appear in `incus remote list` with the name you configured
- `incus list <remote-name>:` should show existing instances (may be empty)
- `INCUS_REMOTE_NAME` should be set to your remote name

## Step 4: Generate Terraform Variables File

Generate the `terraform.tfvars` file from your environment variables:

```bash
task tc:generate-tfvars
```

This will create `terraform/cluster/terraform.tfvars` based on the environment variables you set in Step 2. The file is automatically generated, so you don't need to edit it manually. If you need to change any values, update the environment variables in your `windsor.yaml` file and regenerate the file.

**Note**: The generated file includes a comment at the top indicating it's auto-generated. Do not edit this file manually - always update environment variables and regenerate.

## Step 5: Download and Import Talos Linux Image

Download the Talos Linux image that will be used for the VMs. You can use the existing task to download the image:

```bash
task incus:download-talos-image
```

This will download and convert the Talos Linux image to QCOW2 format. The final image will be at `contexts/${WINDSOR_CONTEXT}/devices/talos/talos-metal-amd64.qcow2`.

**Note**: This task requires `zstd` and `qemu-img` to be installed:

- **macOS**: `brew install zstd qemu`
- **Linux**: `apt-get install zstd qemu-utils` (or equivalent for your distribution)

After downloading, import the image into Incus. The image alias will be automatically generated from `TALOS_IMAGE_VERSION` (format: `talos-${TALOS_IMAGE_VERSION}-metal-amd64`):

```bash
task incus:import-talos-image -- talos-${TALOS_IMAGE_VERSION}-metal-amd64
```

Verify the image was imported:

```bash
incus image list ${INCUS_REMOTE_NAME}:
```

You should see your Talos image listed with the alias you specified.

## Step 6: Configure Direct Network Attachment

To allow VMs to get IP addresses directly on your physical network, you need to configure a physical network interface for direct attachment. This creates a network that bypasses NAT and connects VMs directly to your physical network.

### Step 6a: View Current Network Configuration

First, check the current network configuration:

```bash
incus admin os system network show
```

This shows your network interfaces and their current roles.

### Step 6b: Add Instances Role to Physical Interface

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

### Step 6c: Create Physical Network

After the configuration is applied, create a managed physical network:

```bash
task incus:create-physical-network
```

This creates a physical network that directly attaches to your host's network interface, allowing VMs to get IP addresses directly from your physical network's DHCP server.

**Note**: 

- If the physical network already exists, the task will verify it's correctly configured and skip creation. If you need to recreate it, delete it first with `incus network delete <remote-name>:<interface-name>`.
- Replace `eno1` with your actual physical network interface name if different. Common interface names include `eno1`, `eth0`, `enp5s0`, etc.
- You can override the interface name by setting the `PHYSICAL_INTERFACE` environment variable in your `windsor.yaml` file.
- After this step, VMs launched with this network will get IP addresses directly from your physical network's DHCP server, bypassing NAT.

## Step 7: Initialize and Apply Terraform

Initialize Terraform:

```bash
task tc:terraform:init
```

This will download the required providers (Incus and Talos).

Review the Terraform plan to see what will be created:

```bash
task tc:terraform:plan
```

The plan should show:

- 3 Incus virtual machines (1 control plane, 2 workers)
- Talos machine configurations (control plane and worker)
- Configuration files (talosconfig will be saved to `TALOSCONFIG` path, controlplane.yaml and worker.yaml in `terraform/cluster/`)

Apply the Terraform configuration:

```bash
task tc:terraform:apply
```

Or use the combined create task which handles everything:

```bash
task tc:create
```

This will:

1. Generate `terraform.tfvars` from environment variables
2. Initialize Terraform
3. Apply the Terraform configuration to create the VMs
4. Generate Talos machine configurations
5. Apply configurations to the VMs (using `talosctl apply-config`)
6. Bootstrap the etcd cluster (using `talosctl bootstrap`)

**For new installations** (when IP addresses are empty in `windsor.yaml`):

Terraform will:
1. Create the control plane VM
2. Create the worker VMs
3. Generate Talos machine configurations
4. Display instructions to get the actual DHCP-assigned IP addresses

After the VMs are created, Terraform will pause and display instructions. You'll need to complete **Step 8** to configure the IP addresses before Terraform can continue with Talos configuration.

**For existing installations** (when IP addresses are already set in `windsor.yaml`):

Terraform will:
1. Create the control plane VM (if not exists)
2. Create the worker VMs (if not exists)
3. Generate Talos machine configurations
4. Apply configurations to the VMs (using `talosctl apply-config`)
5. Bootstrap the etcd cluster (using `talosctl bootstrap`)

This process may take several minutes as VMs boot and configurations are applied.

**Note**: The Terraform configuration uses `null_resource` with `local-exec` provisioners to apply Talos configurations and bootstrap the cluster. These provisioners run `talosctl` commands after the VMs are created.

**Important**: Since VMs get IP addresses via DHCP, for new installations you must:
1. Wait for VMs to boot and get their DHCP-assigned IP addresses
2. Get the actual IP addresses from Terraform outputs (see Step 8)
3. Update `windsor.yaml` with the actual IPs
4. Regenerate `terraform.tfvars` and run `terraform apply` again

The IP addresses you configure in `windsor.yaml` are used for Talos configuration generation. For the first deployment, these will be empty, and you'll set them in Step 8 after the VMs receive their DHCP-assigned IPs.

## Step 8: Configure IP Addresses for Talos Deployment

After the VMs are created and have received their DHCP-assigned IP addresses, you need to update your configuration with the actual IPs before Terraform can proceed with Talos configuration.

### Step 8a: Get Actual IP Addresses

Terraform automatically retrieves the actual DHCP-assigned IP addresses from the VMs after they boot. View these IP addresses using Terraform outputs:

```bash
cd terraform/cluster
terraform output
```

This will show all outputs, including:

- `control_plane_ip`: The actual IP address of the control plane node
- `worker_ips`: A map with the actual IP addresses of worker nodes
- `all_node_ips`: All node IP addresses in one convenient map

To get just the IP addresses for easier copying:

```bash
# Control plane IP
terraform output -raw control_plane_ip

# Worker IPs
terraform output -json worker_ips

# All IPs
terraform output -json all_node_ips
```

### Step 8b: Update windsor.yaml with Actual IPs

Update your `windsor.yaml` file with the actual DHCP-assigned IP addresses. Edit `contexts/${WINDSOR_CONTEXT}/windsor.yaml` and update the IP address values:

```yaml
environment:
  # ... other configuration ...
  
  # VM IP addresses - update with actual DHCP-assigned IPs
  CONTROL_PLANE_IP: "192.168.2.146"  # Replace with actual control plane IP
  WORKER_0_IP:      "192.168.2.128"  # Replace with actual worker 0 IP
  WORKER_1_IP:      "192.168.2.102"  # Replace with actual worker 1 IP
```

**Note**: Replace the placeholder IPs with the actual values you obtained from `terraform output`.

### Step 8c: Regenerate terraform.tfvars

After updating `windsor.yaml`, regenerate the `terraform.tfvars` file from your updated environment variables:

```bash
task tc:generate-tfvars
```

This will update `terraform/cluster/terraform.tfvars` with the actual IP addresses from your `windsor.yaml` file.

### Step 8d: Continue Terraform Deployment

Now that the IP addresses are configured, run Terraform apply again to continue with Talos configuration:

```bash
task tc:terraform:apply
```

Or use the create task:

```bash
task tc:create
```

Terraform will now proceed with:
1. Applying Talos configurations to all nodes
2. Bootstrapping the etcd cluster
3. Completing the cluster setup

**Alternative: Use DHCP Reservations** (Recommended for Production)

To avoid this step in the future, configure DHCP reservations in your router. Reserve specific IPs for each VM's MAC address. This way, the VMs will always get the same IPs, matching your configuration from the start. You can find the MAC addresses using:

```bash
incus list ${INCUS_REMOTE_NAME}: --format json | jq '.[] | {name: .name, mac: .state.network.eth0.hwaddr}'
```

## Step 9: Retrieve kubeconfig

After Terraform completes successfully, retrieve the kubeconfig to access your Kubernetes cluster. The `TALOSCONFIG` and `KUBECONFIG_FILE` environment variables must be set (they are configured in Step 2).

Retrieve the kubeconfig and save it to the location specified in your `KUBECONFIG_FILE` environment variable:

```bash
cd terraform/cluster
talosctl kubeconfig "${KUBECONFIG_FILE}" \
  --talosconfig "${TALOSCONFIG}" \
  --nodes $(terraform output -raw control_plane_ip)
```

This will:
1. Download the kubeconfig from the control plane node
2. Save it to the path specified in `KUBECONFIG_FILE` (typically `contexts/${WINDSOR_CONTEXT}/.kube/config`)
3. Make it immediately available for `kubectl` commands (since `KUBECONFIG_FILE` is set in your Windsor environment)

**Note**: Both `TALOSCONFIG` and `KUBECONFIG_FILE` environment variables are automatically set when you source your Windsor environment (`eval "$(windsor env)"` or through Windsor's automatic environment loading). If you need to verify the paths, you can check them with:

```bash
echo "TALOSCONFIG: ${TALOSCONFIG}"
echo "KUBECONFIG_FILE: ${KUBECONFIG_FILE}"
```

## Step 10: Verify Cluster Health

Check that all nodes are healthy and registered:

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A -o wide

# Check cluster info
kubectl cluster-info
```

You should see all three nodes listed:

- 1 control plane node (with `control-plane` role)
- 2 worker nodes (showing `<none>` in the ROLES column - this is normal)

All nodes should show a "Ready" status.

**Note**: In Kubernetes, worker nodes don't have a role label by default. Only control plane nodes get the `node-role.kubernetes.io/control-plane` label automatically. Worker nodes will show `<none>` in the ROLES column, which is expected behavior.

You can also verify the cluster using Talos commands:

```bash
task tc:health-controlplane
task tc:health-worker
```

Your Talos cluster should now be fully operational and ready for workloads.

## Managing the Cluster

### View Cluster Status

```bash
# List all cluster VMs
task tc:list

# Get detailed information about cluster nodes
task tc:info

# Check cluster health
task tc:health-controlplane
task tc:health-worker
```

### Stop/Start Cluster VMs

You can stop and start VMs manually:

```bash
task tc:stop
task tc:start
task tc:restart
```

**Note**: Terraform will detect if VMs are stopped and may attempt to start them on the next `terraform apply`.

### Access VM Console

```bash
task tc:console -- <vm-name>
```

## Destroying the Cluster

To completely destroy the Talos cluster and remove all resources, use Terraform:

```bash
task tc:destroy
```

This will:

1. **Destroy Virtual Machines**: Stops and deletes all cluster VMs (control plane and workers)
2. **Warning**: This permanently destroys all data on these VMs, including:

   - Kubernetes cluster state (etcd data)
   - All workloads and pods
   - Persistent volumes
   - Any data stored on the VMs

3. **Configuration Files**: The Talos configuration file (`talosconfig`) is saved to the path specified in `TALOSCONFIG` (typically `contexts/${WINDSOR_CONTEXT}/.talos/talosconfig`). Terraform-generated machine configuration files in `terraform/cluster/` (controlplane.yaml, worker.yaml) are not automatically deleted. You can manually remove them if needed.

4. **Talos Image**: The Talos image imported into Incus is **not** deleted. You can keep it to reuse for future clusters, or manually remove it:

   ```bash
   incus image delete ${INCUS_REMOTE_NAME}:<talos-image-alias>
   ```

5. **Physical Network**: The physical network created for the cluster is **not** deleted. The network can be shared across multiple clusters and VMs. If you want to remove it, you must do so manually with `incus network delete ${INCUS_REMOTE_NAME}:${PHYSICAL_INTERFACE:-eno1}` (only if no other VMs are using it)

### Verification

After destruction, verify that all cluster VMs have been removed:

```bash
task tc:list
```

The cluster VMs should no longer appear in the list.

### Important Notes

- **Data Loss**: Destroying the cluster will permanently delete all Kubernetes data, workloads, and persistent volumes. Ensure you have backups if needed.
- **Network**: The physical network can be reused for other clusters, so it's not deleted automatically.
- **Images**: The Talos image can be reused, so it's not deleted automatically.
- **Recreation**: To recreate the cluster, simply run `task tc:create` again.

## Troubleshooting

### Terraform Apply Fails

- **VMs not booting**: Verify the Talos image was imported correctly and the alias matches your `TALOS_IMAGE_VERSION` (should be `talos-${TALOS_IMAGE_VERSION}-metal-amd64`)
- **Network issues**: Ensure the physical network is configured correctly (Step 6)
- **IP address conflicts**: Verify the IP addresses in your environment variables are available and not in use
- **Provider errors**: Check that the Incus provider can connect to your remote: `incus list ${INCUS_REMOTE_NAME}:`

### VMs Not Getting IP Addresses

- Verify the physical network exists: `incus network list ${INCUS_REMOTE_NAME}:`
- Check if the `instances` role was added to the network interface (Step 6b)
- Wait longer for DHCP assignment (sometimes VMs need 3-5 minutes)
- Check your router's DHCP server is running

### Talos Configuration Application Fails

- Verify VMs are fully booted before Terraform applies configurations
- Check that IP addresses are correct and reachable: `ping <control-plane-ip>`
- Ensure talosctl can connect: `talosctl --nodes <control-plane-ip> version`
- Review Terraform logs for specific error messages

### Cluster Bootstrap Fails

- Ensure control plane VM is fully booted and accessible
- Verify etcd is not already bootstrapped (only bootstrap once)
- Check Talos API is accessible: `talosctl --nodes <control-plane-ip> version`
- Review control plane logs: `task tc:console -- talos-cp`

### Nodes Not Joining Cluster

- Verify worker VMs are fully booted
- Check that worker configuration was applied correctly
- Ensure control plane is bootstrapped before workers join
- Verify network connectivity between all VMs

### Insufficient Resources

If VMs fail to start due to resource constraints:

- Reduce VM memory allocation by setting `CONTROL_PLANE_MEMORY` and `WORKER_MEMORY` environment variables (minimum 2GB per VM), then regenerate: `task tc:generate-tfvars`
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
6. **Scale the cluster**: Add more worker nodes by updating `terraform.tfvars` and adding additional worker resources

## Additional Resources

- [Talos Documentation](https://www.talos.dev/)
- [IncusOS Setup](setup.md) - Setting up IncusOS
- [Bootstrapping Nodes](../bootstrapping/README.md) - Physical node bootstrapping
- [Initialize Workspace](../workspace/init.md) - Workspace setup
- [Terraform Incus Provider Documentation](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [Terraform Talos Provider Documentation](https://registry.terraform.io/providers/siderolabs/talos/latest/docs)

