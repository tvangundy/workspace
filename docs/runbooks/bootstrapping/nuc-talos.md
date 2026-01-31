# Bootstrapping a Talos Cluster on Intel NUC

This guide walks you through bootstrapping a Talos Linux cluster on an Intel NUC device. The bootstrapping process uses a USB memory device to hold the Talos image and perform the initial bootup of the device. Once booted, the device will be ready for cluster configuration.

## Overview

Bootstrapping an Intel NUC with Talos Linux involves:

1. **Setting Windsor context**: Initialize the workspace context with `windsor init` and `windsor context set`
2. **Updating windsor.yaml**: Configuring image, cluster, and disk variables
3. **Downloading the Talos image**: Getting the x86_64 image from the Talos image factory
4. **Preparing the boot media**: Writing the image to a USB memory device
5. **Initial boot**: Booting the Intel NUC from the prepared USB media
6. **Cluster configuration**: Applying the Talos configuration to form or join a cluster
7. **Retrieving access**: Getting the kubeconfig to interact with your cluster

The USB memory device serves as both the boot media and the initial storage for the Talos operating system. After the initial boot, the device will run entirely from this media.

## Prerequisites

Before starting, ensure you have:

- **Intel NUC BIOS updated** (recommended): Follow [Update the Intel NUC BIOS](./nuc-bios.md) before bootstrapping Talos
- **Intel NUC device**: Compatible Intel NUC (x86_64 architecture)
- **USB memory device**: At least 8GB capacity (16GB or larger recommended)
- **Computer with macOS or Linux**: For preparing the boot media
- **Network connectivity**: The Intel NUC must be able to connect to your network
- **talosctl installed**: See the [Installation Guide](../../install.md) for setup instructions
- **Physical access**: To insert the boot media and power on the device
- **Windsor workspace**: Clone or open the workspace repository

## Step 1: Set Windsor context

Initialize and set the `nuc-talos` context:

```bash
windsor init nuc-talos
windsor context set nuc-talos
```

## Step 2: Update windsor.yaml

### Get image info

Visit the [Talos image factory](https://factory.talos.dev) to determine the image information. Select the x86_64 (amd64) architecture for Intel NUC devices.

### Determine the target disk

Use `task device:list-disks` to get a list of disks. Set the `USB_DISK` environment variable accordingly.

### Add variables to windsor.yaml

Add or update the `environment` section in `contexts/nuc-talos/windsor.yaml`:

```yaml
environment:
  RPI_IMAGE_SCHEMATIC_ID: <your-schematic-id>
  RPI_IMAGE_VERSION: v1.11.6
  RPI_IMAGE_ARCH: metal-amd64

  CLUSTER_NAME: "my-cluster"

  CONTROL_PLANE_IP: "192.168.2.101"
  WORKER_0_IP: "192.168.2.102"
  WORKER_1_IP: "192.168.2.103"

  USB_DISK: "/dev/disk4"

  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
```

**Note**: Replace the placeholder values with your actual configuration:

- `<your-schematic-id>`: The schematic ID from the Talos image factory
- Cluster name and IP addresses: Your cluster configuration
- `USB_DISK`: The device identifier for your USB memory device (use `task device:list-disks` to identify it)

## Step 3: Download the Talos image

Download the x86_64 Talos image from the [Talos image factory](https://factory.talos.dev):

```bash
task device:download-talos-image
```

This will download the image to `contexts/nuc-talos/devices/metal-amd64/metal-amd64.raw`.

## Step 4: Prepare the boot media

### Write the Image to Boot Media

Write the decompressed image to your USB memory device. This process will erase all existing data on the device.

```bash
task device:write-talos-disk [-- 3]
```

### Eject the Boot Media

After writing completes, safely eject the device(s):

```bash
task device:eject-disk [-- 3]
```

The `eject-disk` task will automatically unmount the disks before ejecting them.

## Step 5: Boot the Intel NUC

1. **Insert the boot media**: Insert the USB memory device into a USB port on your Intel NUC
2. **Connect network**: Ensure the Intel NUC is connected to your network via Ethernet (recommended)
3. **Power on**: Connect power to the Intel NUC and turn it on
4. **Access BIOS/UEFI**: Press the appropriate key (typically F2, F10, or Delete) during boot to access BIOS/UEFI settings
5. **Configure boot order**: Set the USB device as the first boot option, or use the boot menu (typically F10 or F12) to select the USB device
6. **Save and exit**: Save BIOS/UEFI settings and allow the device to boot from USB
7. **Wait for boot**: The device will boot from the USB memory device. Wait for the boot process to complete
8. **Find the IP address**: The device will display its IP address on the console, or you can find it via your router's DHCP client list

**Note**: If the device doesn't boot from USB, verify that:

- USB boot is enabled in BIOS/UEFI settings
- Secure Boot is disabled (if present)
- The USB device is properly formatted and the image was written correctly

## Step 6: Unmount the ISO

Unplug your installation USB drive or unmount the ISO. This prevents you from accidentally installing to the USB drive and makes it clearer which disk to select for installation.

## Step 7: Learn about your installation disks

When you first boot your machine from the ISO, Talos runs temporarily in memory. This means that your Talos nodes, configurations, and cluster membership won't survive reboots or power cycles.
However, once you apply the machine configuration (which you'll do later in this guide), you'll install Talos, its complete operating system, and your configuration to a specified disk for permanent storage.
Run this command to view all available disks on your control plane:

```bash
task device:get-disks -- $CONTROL_PLANE_IP
```

## Step 8: Generate Talos configuration

Generate the Talos configuration files (`controlplane.yaml` and `worker.yaml`) using the Talos configuration generator. This command creates the necessary configuration files for your cluster.

```bash
task device:generate-talosconfig -- /dev/nvme0n1
```

Replace `/dev/nvme0n1` with the disk device where Talos will be installed (e.g., `/dev/sda` or `/dev/nvme0n1`). You can determine the correct disk by reviewing the output from Step 7 (learn about your installation disks).

This will generate:

- `controlplane.yaml` - Configuration for control plane nodes
- `worker.yaml` - Configuration for worker nodes
- `talosconfig` - Client configuration file (saved to `contexts/nuc-talos/.talos/talosconfig`)

## Step 8: Apply Talos configuration

Apply the generated configuration to your nodes. This installs Talos to the specified disk and configures the cluster.

**Example with 1 control plane and 2 workers:**
```bash
task device:apply-configuration -- $CONTROL_PLANE_IP $WORKER_0_IP $WORKER_1_IP
```

This command will:

1. Apply `controlplane.yaml` to the control plane node
2. Apply `worker.yaml` to each worker node specified

After the configuration is applied, Talos will be installed to the disk and your cluster will be permanently configured. The nodes will reboot and join the cluster.

## Step 9: Set your endpoints

Set your endpoints with this:
```bash
task device:set-endpoints -- $CONTROL_PLANE_IP $WORKER_0_IP $WORKER_1_IP
```

## Step 10: Bootstrap your etcd cluster

Wait for your control plane node to finish booting, then bootstrap your etcd cluster by running:

```bash
task device:bootstrap-etc-cluster -- $CONTROL_PLANE_IP
```

**Note**: Run this command ONCE on a SINGLE control plane node. If you have multiple control plane nodes, you can choose any of them.

## Step 11: Get Kubernetes access

Download your kubeconfig file to start using kubectl.

```bash
task device:retrieve-kubeconfig -- $CONTROL_PLANE_IP
```

## Step 12: Check cluster health

Run the following command to check the health of your nodes:

```bash
task device:cluster-health -- $CONTROL_PLANE_IP
```

## Step 13: Verify node registration

Confirm that your nodes are registered in Kubernetes:

```bash
kubectl get nodes
```

You should see your control plane and worker nodes listed with a Ready status.

## Verification

Verify your cluster is operational:

```bash
# Check node status
kubectl get nodes

# Check cluster components
kubectl get pods -n kube-system

# Check Talos system pods
kubectl get pods -n system
```

Your Intel NUC should appear as a node in the cluster, and all system pods should be running.

## Troubleshooting

### Device Not Booting

- Verify the image was written correctly to the boot media
- Try a different USB memory device
- Check that USB boot is enabled in BIOS/UEFI settings
- Disable Secure Boot if it's preventing boot
- Verify the Intel NUC model is compatible with the x86_64 image
- Ensure the USB device is properly inserted and recognized by the BIOS/UEFI

### Cannot Connect to Node

- Verify the Intel NUC has network connectivity
- Check that the IP address is correct
- Ensure your computer can reach the Intel NUC on the network
- Check firewall settings
- Verify network cable connection (if using Ethernet)

### Configuration Fails

- Verify `talosctl` is installed and up to date
- Check network connectivity between your computer and the Intel NUC
- Review Talos logs: `talosctl logs --follow`
- Ensure the Talos image architecture (x86_64) matches your Intel NUC

## Next Steps

After successfully bootstrapping your Intel NUC:

1. **Add additional nodes**: Follow the same process to add more nodes to your cluster
2. **Configure storage**: Set up persistent storage for your workloads
3. **Deploy applications**: Start deploying your applications to the cluster
4. **Set up monitoring**: Configure monitoring and logging for your cluster

## Additional Resources

- [Talos Linux Documentation](https://www.talos.dev/)
- [Talos Image Factory](https://factory.talos.dev)
- [Installation Guide](../../install.md)
