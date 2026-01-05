# Talos Cluster on IncusOS VMs using Terraform

This guide walks you through deploying a Talos Linux Kubernetes cluster using Terraform with the Incus provider. You'll create 3 VMs: 1 control plane node and 2 worker nodes, then configure them to form a complete Kubernetes cluster using Infrastructure as Code.

## Overview

Deploying a Talos cluster on IncusOS VMs using Terraform involves:

1. **Installing tools**: Setting up Terraform, Talos providers, and required dependencies
2. **Setting environment variables**: Configuring your cluster settings in `windsor.yaml`
3. **Generating Terraform variables**: Creating `terraform.tfvars` from environment variables
4. **Downloading and importing Talos image**: Getting the Talos Linux image and importing it into Incus
5. **Creating network bridge**: Setting up network connectivity for VMs
6. **Initializing and applying Terraform**: Using Terraform to create VMs and configure the cluster
7. **Viewing IP addresses**: Finding actual DHCP-assigned IPs from Terraform outputs
8. **Retrieving kubeconfig**: Getting Kubernetes access credentials
9. **Verifying cluster**: Confirming all nodes are healthy and operational

This approach uses Infrastructure as Code (Terraform) to manage your cluster, making it easy to version control, reproduce, and manage your infrastructure declaratively.

## Prerequisites

- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- Incus client installed on your local machine
- IncusOS server set up and accessible (see [IncusOS Setup](setup.md))
- Incus remote configured (see [IncusOS Setup - Step 7](setup.md#step-7-connect-to-incus-server))
- Terraform installed (see the [Installation Guide](../../install.md) for setup instructions)
- talosctl installed (see the [Installation Guide](../../install.md) for setup instructions)
- Sufficient resources: At least 8GB RAM and 100GB storage on the IncusOS host for 3 VMs
- Network access: The IncusOS host must be on a network with available IP addresses

## System Requirements

Each VM will require:

- **Control plane VM**: Minimum 2GB RAM, 20GB disk
- **Worker VMs**: Minimum 2GB RAM, 20GB disk each
- **Total**: 6GB RAM and 60GB disk minimum (8GB RAM and 100GB disk recommended)

## Step 1: Install Tools Dependencies

To deploy the Talos cluster using Terraform, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/). For your convenience, we have provided a sample setup file for aqua. Place this file in the root of your project.

Create an `aqua.yaml` file in your project's root directory with the following content:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/aquaproj/aqua/main/json-schema/aqua-yaml.json
# aqua - Declarative CLI Version Manager
# https://aquaproj.github.io/
# checksum:
#   enabled: true
#   require_checksum: true
#   supported_envs:
#   - all
registries:
  - type: standard
    ref: v4.285.0
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

## Step 2: Set Environment Variables

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
  INCUS_REMOTE_IP_0: "192.168.2.101"
  
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
  TALOS_IMAGE_SCHEMATIC_ID: "<your-schematic-id>"
  TALOS_IMAGE_VERSION: "v1.12.0"
  TALOS_IMAGE_ARCH: "metal-amd64"
  
  # Physical network interface (optional, defaults to eno1)
  # PHYSICAL_INTERFACE: "eno1"
  
  # Storage pool (optional, defaults to default)
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
  
  # Talos configuration paths
  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
  KUBECONFIG_FILE: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
```

**Note**: Replace the placeholder values with your actual configuration:

- `INCUS_REMOTE_NAME`: The name of your Incus remote (from `incus remote list`)
- `INCUS_REMOTE_IP_0`: The IP address of your IncusOS host
- `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP`: Expected IP addresses on your network for the VMs (leave empty for new installations - Terraform will prompt you to fill them in after VMs are created)
- `CLUSTER_NAME`: A name for your Kubernetes cluster
- `TALOS_IMAGE_SCHEMATIC_ID`: The schematic ID you obtained from the Talos Image Factory (replace `<your-schematic-id>` with the actual ID)
- `TALOS_IMAGE_VERSION`: The Talos version to use (check [Talos releases](https://github.com/siderolabs/talos/releases))
- `TALOS_IMAGE_ARCH`: The architecture (typically `metal-amd64` for Intel NUC)
- `PHYSICAL_INTERFACE`: (Optional) Your physical network interface name (defaults to `eno1` if not set)
- `STORAGE_POOL`: (Optional) Name of the Incus storage pool (defaults to `default`)
- `CONTROL_PLANE_MEMORY`, `CONTROL_PLANE_CPU`, `WORKER_MEMORY`, `WORKER_CPU`: (Optional) VM resource allocations (defaults: 2GB memory, 2 CPUs)
- `COMMON_CONFIG_PATCHES`: (Optional) YAML string with common configuration patches for all nodes

## Step 3: Generate Terraform Variables File

Generate the `terraform.tfvars` file from your environment variables:

```bash
task talos:generate-tfvars
```

This will create `terraform/cluster/terraform.tfvars` based on the environment variables you set in Step 2. The file is automatically generated, so you don't need to edit it manually. If you need to change any values, update the environment variables in your `windsor.yaml` file and regenerate the file.

**Note**: The generated file includes a comment at the top indicating it's auto-generated. Do not edit this file manually - always update environment variables and regenerate.

## Step 4: Download and Import Talos Linux Image

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

For example, if `TALOS_IMAGE_VERSION=v1.12.0`:

```bash
task incus:import-talos-image -- talos-v1.12.0-metal-amd64
```

**Note**: If you don't provide an alias, the task will use `talos-${TALOS_IMAGE_VERSION}-metal-amd64` as the default alias (requires `TALOS_IMAGE_VERSION` to be set).

Verify the image was imported:

```bash
incus image list ${INCUS_REMOTE_NAME}:
```

You should see your Talos image listed with the alias you specified.

## Step 5: Configure Direct Network Attachment

To allow VMs to get IP addresses directly on your physical network, you need to configure a physical network interface for direct attachment. This creates a network that bypasses NAT and connects VMs directly to your physical network.

### Step 5a: View Current Network Configuration

First, check the current network configuration:

```bash
incus admin os system network show
```

This shows your network interfaces and their current roles.

### Step 5b: Add Instances Role to Physical Interface

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

### Step 5c: Create Physical Network

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

## Step 6: Initialize and Apply Terraform

Navigate to the Terraform directory and initialize Terraform:

```bash
cd terraform/cluster
terraform init
```

This will download the required providers (Incus and Talos).

Review the Terraform plan to see what will be created:

```bash
terraform plan
```

The plan should show:

- 3 Incus virtual machines (1 control plane, 2 workers)
- Talos machine configurations (control plane and worker)
- Configuration files (talosconfig, controlplane.yaml, worker.yaml)

Apply the Terraform configuration:

```bash
terraform apply
```

Terraform will:

1. Create the control plane VM
2. Create the worker VMs
3. Generate Talos machine configurations
4. Apply configurations to the VMs (using `talosctl apply-config`)
5. Bootstrap the etcd cluster (using `talosctl bootstrap`)

This process may take several minutes as VMs boot and configurations are applied.

**Note**: The Terraform configuration uses `null_resource` with `local-exec` provisioners to apply Talos configurations and bootstrap the cluster. These provisioners run `talosctl` commands after the VMs are created.

**Important**: Since VMs get IP addresses via DHCP, Terraform will automatically:
1. Wait for VMs to boot and get their DHCP-assigned IP addresses
2. Retrieve the actual IP addresses from inside each VM
3. Use those actual IPs when applying Talos configurations
4. Output the actual IP addresses so you can see them (see Step 7)

The IP addresses you configure in `terraform.tfvars` are used as placeholders for initial Talos configuration generation, but the actual DHCP-assigned IPs will be used for all operations.

## Step 7: View Actual IP Addresses

Terraform automatically retrieves the actual DHCP-assigned IP addresses from the VMs after they boot. You can view these IP addresses using Terraform outputs:

```bash
cd terraform/cluster
terraform output
```

This will show all outputs, including:

- `control_plane_ip`: The actual IP address of the control plane node
- `worker_ips`: A map with the actual IP addresses of worker nodes
- `all_node_ips`: All node IP addresses in one convenient map

To get just the IP addresses:

```bash
# Control plane IP
terraform output -raw control_plane_ip

# Worker IPs
terraform output -json worker_ips

# All IPs
terraform output -json all_node_ips
```

### Optional: Update terraform.tfvars with Actual IPs

If you want to use the actual IPs in future Terraform applies (for example, if you need to regenerate Talos configurations), you can update `terraform.tfvars` with the actual IPs:

```bash
# Get the actual IPs
CONTROL_PLANE_IP=$(terraform output -raw control_plane_ip)
WORKER_0_IP=$(terraform output -raw -json worker_ips | jq -r '.worker_0')
WORKER_1_IP=$(terraform output -raw -json worker_ips | jq -r '.worker_1')

# Update terraform.tfvars (example - adjust for your editor)
sed -i '' "s/control_plane_ip = .*/control_plane_ip = \"${CONTROL_PLANE_IP}\"/" terraform.tfvars
sed -i '' "s/worker_0_ip = .*/worker_0_ip = \"${WORKER_0_IP}\"/" terraform.tfvars
sed -i '' "s/worker_1_ip = .*/worker_1_ip = \"${WORKER_1_IP}\"/" terraform.tfvars
```

**Note**: This is optional. Terraform will automatically use the actual IPs even if `terraform.tfvars` has different values, because it retrieves the IPs dynamically from the VMs.

**Alternative: Use DHCP Reservations** (Recommended for Production)

To ensure VMs always get the same IPs, configure DHCP reservations in your router. Reserve specific IPs for each VM's MAC address. This way, the IPs will match your configuration consistently.

## Step 8: Retrieve kubeconfig

After Terraform completes successfully, retrieve the kubeconfig to access your Kubernetes cluster. The Talos configuration files are saved in the `terraform/cluster` directory.

Retrieve the kubeconfig and save it to the location specified in your `KUBECONFIG_FILE` environment variable:

```bash
cd terraform/cluster
talosctl kubeconfig "${KUBECONFIG_FILE}" \
  --talosconfig talosconfig \
  --nodes $(terraform output -raw control_plane_ip)
```

This will:
1. Download the kubeconfig from the control plane node
2. Save it to `contexts/${WINDSOR_CONTEXT}/.kube/config` (as defined in your `KUBECONFIG_FILE` environment variable)
3. Make it immediately available for `kubectl` commands (since `KUBECONFIG_FILE` is set in your Windsor environment)

**Note**: The `KUBECONFIG_FILE` environment variable is automatically set when you source your Windsor environment (`eval "$(windsor env)"` or through Windsor's automatic environment loading). If you need to verify the path, you can check it with:

```bash
echo "${KUBECONFIG_FILE}"
```

## Step 9: Verify Cluster Health

Check that all nodes are healthy and registered:

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

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
talosctl --talosconfig terraform/cluster/talosconfig \
  --nodes $(terraform output -raw control_plane_ip) \
  health
```

Your Talos cluster should now be fully operational and ready for workloads.

## Destroying the Cluster

To completely destroy the Talos cluster and remove all resources, use Terraform:

```bash
cd terraform/cluster
terraform destroy
```

This will:

1. **Destroy Virtual Machines**: Stops and deletes all cluster VMs (control plane and workers)
2. **Warning**: This permanently destroys all data on these VMs, including:

   - Kubernetes cluster state (etcd data)
   - All workloads and pods
   - Persistent volumes
   - Any data stored on the VMs

3. **Configuration Files**: Terraform-generated configuration files in `terraform/cluster/` (talosconfig, controlplane.yaml, worker.yaml) are not automatically deleted. You can manually remove them if needed.

4. **Talos Image**: The Talos image imported into Incus is **not** deleted. You can keep it to reuse for future clusters, or manually remove it:

   ```bash
   incus image delete ${INCUS_REMOTE_NAME}:<talos-image-alias>
   ```

5. **Physical Network**: The physical network created for the cluster is **not** deleted. The network can be shared across multiple clusters and VMs. If you want to remove it, you must do so manually with `incus network delete ${INCUS_REMOTE_NAME}:${PHYSICAL_INTERFACE:-eno1}` (only if no other VMs are using it)

### Verification

After destruction, verify that all cluster VMs have been removed:

```bash
incus list ${INCUS_REMOTE_NAME}:
```

The cluster VMs should no longer appear in the list.

### Important Notes

- **Data Loss**: Destroying the cluster will permanently delete all Kubernetes data, workloads, and persistent volumes. Ensure you have backups if needed.
- **Network**: The physical network can be reused for other clusters, so it's not deleted automatically.
- **Images**: The Talos image can be reused, so it's not deleted automatically.
- **Recreation**: To recreate the cluster, simply run `terraform apply` again.

## Managing the Cluster

### View VM Status

```bash
incus list <remote-name>:
```

Or use Terraform to see what's deployed:

```bash
cd terraform/cluster
terraform state list
terraform show
```

### Update Cluster Configuration

To update the cluster configuration:

1. Update environment variables in `contexts/${WINDSOR_CONTEXT}/windsor.yaml`
2. Regenerate `terraform.tfvars`: `task talos:generate-tfvars`
3. Run `terraform plan` to preview changes
4. Run `terraform apply` to apply changes

**Note**: Some changes (like IP addresses) may require manual intervention or may not be supported by Terraform.

### Stop/Start VMs

You can stop and start VMs manually:

```bash
incus stop <remote-name>:<vm-name>
incus start <remote-name>:<vm-name>
```

Or restart all cluster VMs:

```bash
incus restart <remote-name>:talos-cp <remote-name>:talos-worker-0 <remote-name>:talos-worker-1
```

**Note**: Terraform will detect if VMs are stopped and may attempt to start them on the next `terraform apply`.

### Access VM Console

```bash
incus console <remote-name>:<vm-name>
```

## Troubleshooting

### Terraform Apply Fails

- **VMs not booting**: Verify the Talos image was imported correctly and the alias matches your `TALOS_IMAGE_VERSION` (should be `talos-${TALOS_IMAGE_VERSION}-metal-amd64`)
- **Network issues**: Ensure the physical network is configured correctly (Step 5)
- **IP address conflicts**: Verify the IP addresses in your environment variables are available and not in use
- **Provider errors**: Check that the Incus provider can connect to your remote: `incus list ${INCUS_REMOTE_NAME}:`

### VMs Not Getting IP Addresses

- Verify the physical network exists: `incus network list ${INCUS_REMOTE_NAME}:`
- Check if the `instances` role was added to the network interface (Step 4b)
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
- Review control plane logs: `incus console <remote-name>:talos-cp`

### Nodes Not Joining Cluster

- Verify worker VMs are fully booted
- Check that worker configuration was applied correctly
- Ensure control plane is bootstrapped before workers join
- Verify network connectivity between all VMs

### Insufficient Resources

If VMs fail to start due to resource constraints:

- Reduce VM memory allocation by setting `CONTROL_PLANE_MEMORY` and `WORKER_MEMORY` environment variables (minimum 2GB per VM), then regenerate: `task talos:generate-tfvars`
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
- [Talos Cluster on IncusOS VMs (Manual)](talos-incus-vm.md) - Alternative manual deployment approach
- [Bootstrapping Nodes](../bootstrapping/README.md) - Physical node bootstrapping
- [Initialize Workspace](../workspace/init.md) - Workspace setup
- [Terraform Incus Provider Documentation](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [Terraform Talos Provider Documentation](https://registry.terraform.io/providers/siderolabs/talos/latest/docs)
