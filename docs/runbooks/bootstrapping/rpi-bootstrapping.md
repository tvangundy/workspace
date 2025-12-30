# Bootstrapping a Talos Cluster on Raspberry Pi

This guide walks you through bootstrapping a Talos Linux cluster on a Raspberry Pi device. The bootstrapping process uses a USB memory device (or SD card) to hold the Talos image and perform the initial bootup of the device. Once booted, the device will be ready for cluster configuration.

## Overview

Bootstrapping a Raspberry Pi with Talos Linux involves:

1. **Downloading the Talos image**: Getting the ARM64 image from the Talos image factory
2. **Preparing the boot media**: Writing the image to a USB memory device or SD card
3. **Initial boot**: Booting the Raspberry Pi from the prepared media
4. **Cluster configuration**: Applying the Talos configuration to form or join a cluster
5. **Retrieving access**: Getting the kubeconfig to interact with your cluster

The USB memory device (or SD card) serves as both the boot media and the initial storage for the Talos operating system. After the initial boot, the device will run entirely from this media.

## Prerequisites

Before starting, ensure you have:

- **Raspberry Pi device**: Compatible Raspberry Pi (ARM64 architecture)
- **USB memory device or SD card**: At least 8GB capacity (16GB or larger recommended)
- **Computer with macOS or Linux**: For preparing the boot media
- **Network connectivity**: The Raspberry Pi must be able to connect to your network
- **talosctl installed**: See the [Installation Guide](../../install.md) for setup instructions
- **Physical access**: To insert the boot media and power on the device

## Step 1: Set Environment variables

### Get rpi image info

Visit the [Talos image factory](https://factory.talos.dev) to determine the image information and set the environment variables appropriately in the following in the windsor.yaml file

### Determine the target disk for image copy

Use the ```task device:list-disks``` command to get a list of disks.  Set the USB_DISK environment variable as shown below.

### Add these lines to ./contexts/`<context>`/windsor.yaml

```yaml
environment:
  RPI_IMAGE_SCHEMATIC_ID: ee21ef4a5ef808a9b7484cc0dda0f25075021691c8c09a276591eedb638ea1f9
  RPI_IMAGE_VERSION: v1.11.6
  RPI_IMAGE_ARCH: metal-arm64

  CLUSTER_NAME: "home-assistant"

  CONTROL_PLANE_IP: "192.168.2.31"
  WORKER_0_IP: "192.168.2.111"
  WORKER_1_IP: "192.168.2.125"

  USB_DISK: "/dev/disk4"

  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig

```

## Step 2: Download the Talos Image

Download the ARM64 Talos image from the [Talos image factory](https://factory.talos.dev). The image factory generates custom images based on your configuration requirements.

```bash
task device:download-image
```

## Step 3: Prepare the Boot Media

### Write the Image to Boot Media

Write the decompressed image to your USB memory device or SD card. This process will erase all existing data on the device.

```bash
task device:write-disk [-- 3]
```

### Eject the Boot Media

After writing completes, safely eject the device(s):

```bash
task device:eject-disk [-- 3]
```

The `eject-disk` task will automatically unmount the disks before ejecting them.

## Step 4: Boot the Raspberry Pi's 

1. **Insert the boot media**: Insert the USB memory device or SD card into your Raspberry Pi
2. **Connect network**: Ensure the Raspberry Pi is connected to your network via Ethernet (recommended)
3. **Power on**: Connect power to the Raspberry Pi and turn it on
4. **Wait for boot**: The device will boot from the USB memory device/SD card. Wait for the boot process to complete
5. **Find the IP address**: The device will display its IP address on the console, or you can find it via your router's DHCP client list

**Note**: If you have an HDMI display attached and it shows only a rainbow splash screen, try using the other HDMI port (the one closest to the power/USB-C port on Raspberry Pi 4).

## Step 5: Unmount the ISO

Unplug your installation USB drive or unmount the ISO. This prevents you from accidentally installing to the USB drive and makes it clearer which disk to select for installation.

## Step 6: Learn About Your Installation Disks

When you first boot your machine from the ISO, Talos runs temporarily in memory. This means that your Talos nodes, configurations, and cluster membership won’t survive reboots or power cycles.
However, once you apply the machine configuration (which you’ll do later in this guide), you’ll install Talos, its complete operating system, and your configuration to a specified disk for permanent storage.
Run this command to view all the available disks on your control plane:

```bash
task device:get-disks -- $CONTROL_PLANE_IP
```

## Step 7: Generate Talos Configuration

Generate the Talos configuration files (`controlplane.yaml` and `worker.yaml`) using the Talos configuration generator. This command creates the necessary configuration files for your cluster.

```bash
task device:generate-talosconfig -- /dev/sda
```

Replace `/dev/sda` with the disk device where Talos will be installed (e.g., `/dev/sda` or `/dev/nvme0n1`). You can determine the correct disk by reviewing the output from Step 6.

This will generate:
- `controlplane.yaml` - Configuration for control plane nodes
- `worker.yaml` - Configuration for worker nodes
- `talosconfig.yaml` - Client configuration file (saved to `contexts/<context>/.talos/talosconfig`)

## Step 8: Apply Talos Configuration

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
​
## Step 10: Bootstrap Your Etcd Cluster

Wait for your control plane node to finish booting, then bootstrap your etcd cluster by running:

```bash
task device:bootstrap-etc-cluster -- $CONTROL_PLANE_IP
```

Note: Run this command ONCE on a SINGLE control plane node. If you have multiple control plane nodes, you can choose any of them.
​
## Step 11: Get Kubernetes Access

Download your kubeconfig file to start using kubectl.

```bash
task device:retrieve-kubeconfig -- $CONTROL_PLANE_IP
```
​
## Step 12: Check Cluster Health

Run the following command to check the health of your nodes:

```bash
task device:cluster-health -- $CONTROL_PLANE_IP
```
​
## Step 13: Verify Node Registration

Confirm that your nodes are registered in Kubernetes:

```bash
kubectl get nodes
```

You should see your control plane and worker nodes listed with a Ready status.
​
Next Steps

Congratulations! You now have a working Kubernetes cluster on Talos Linux.

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

Your Raspberry Pi should appear as a node in the cluster, and all system pods should be running.

## Troubleshooting

### Device Not Booting

- Verify the image was written correctly to the boot media
- Try a different USB memory device or SD card
- Check that the Raspberry Pi model is compatible with the ARM64 image
- Ensure the boot media is properly inserted

### Cannot Connect to Node

- Verify the Raspberry Pi has network connectivity
- Check that the IP address is correct
- Ensure your computer can reach the Raspberry Pi on the network
- Check firewall settings

### Configuration Fails

- Verify `talosctl` is installed and up to date
- Check network connectivity between your computer and the Raspberry Pi
- Review Talos logs: `talosctl logs --follow`

- [Talos Linux Documentation](https://www.talos.dev/)
- [Talos Image Factory](https://factory.talos.dev)
- [Installation Guide](../../install.md)
