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

## Step 1: Determine Talos Image and set environment variables

Visit the [Talos image factory](https://factory.talos.dev) to determine the image and set the following in the windsor.yaml file

```yaml
environment:
  RPI_IMAGE_SCHEMATIC_ID: ee21ef4a5ef808a9b7484cc0dda0f25075021691c8c09a276591eedb638ea1f9
  RPI_IMAGE_VERSION: v1.11.6
  RPI_IMAGE_ARCH: metal-arm64
  USB_DISK: nothing
```

## Step 1: Download the Talos Image

Download the ARM64 Talos image from the [Talos image factory](https://factory.talos.dev). The image factory generates custom images based on your configuration requirements.

```bash
task device:download-image
```

**Note**: The URL above is an example. Visit the [image factory](https://factory.talos.dev) to generate an image URL specific to your configuration needs.


## Step 2: Prepare the Boot Media

### Identify Your USB Memory Device or SD Card

First, identify the device identifier for your USB memory device or SD card:

```bash
# macOS
diskutil list

# Linux
lsblk
# or
fdisk -l
```

Look for your USB memory device or SD card in the list. It will typically appear as `/dev/disk4` (macOS) or `/dev/sdX` (Linux). **Be very careful** to identify the correct device, as writing to the wrong device will destroy data.

### Write the Image to Boot Media

Write the decompressed image to your USB memory device or SD card. This process will erase all existing data on the device.

```bash
# macOS - Unmount the device first (replace disk4 with your device identifier)
diskutil unmountDisk /dev/disk4

# macOS - Write the image (replace disk4 with your device identifier)
sudo dd if=metal-arm64.raw of=/dev/rdisk4 conv=fsync bs=4M status=progress

# Linux - Unmount the device first (replace sdX with your device identifier)
sudo umount /dev/sdX*

# Linux - Write the image (replace sdX with your device identifier)
sudo dd if=metal-arm64.raw of=/dev/sdX conv=fsync bs=4M status=progress
```

**Important Notes:**
- Use `/dev/rdisk4` on macOS (raw disk) for faster writes
- The `status=progress` flag shows write progress (may not be available on all systems)
- This process can take several minutes depending on the size of your media
- Do not remove the device during the write process

### Eject the Boot Media

After writing completes, safely eject the device:

```bash
# macOS
diskutil eject /dev/disk4

# Linux
sudo eject /dev/sdX
```

## Step 3: Boot the Raspberry Pi

1. **Insert the boot media**: Insert the USB memory device or SD card into your Raspberry Pi
2. **Connect network**: Ensure the Raspberry Pi is connected to your network via Ethernet (recommended) or Wi-Fi
3. **Power on**: Connect power to the Raspberry Pi and turn it on
4. **Wait for boot**: The device will boot from the USB memory device/SD card. Wait for the boot process to complete
5. **Find the IP address**: The device will display its IP address on the console, or you can find it via your router's DHCP client list

**Note**: If you have an HDMI display attached and it shows only a rainbow splash screen, try using the other HDMI port (the one closest to the power/USB-C port on Raspberry Pi 4).

## Step 4: Configure the Cluster

Once the Raspberry Pi has booted and you have its IP address, apply the Talos configuration:

```bash
talosctl apply-config --insecure --mode=interactive --nodes <node-ip-address>
```

Replace `<node-ip-address>` with the actual IP address of your Raspberry Pi.

The interactive mode will guide you through:
- Setting up the cluster (for the first node) or joining an existing cluster
- Configuring network settings
- Setting up authentication

Once the configuration is applied, Talos will form the cluster (if this is the first node) or join the existing cluster.

## Step 6: Retrieve the Kubeconfig

After the cluster is configured and running, retrieve the admin kubeconfig to interact with your cluster:

```bash
talosctl kubeconfig
```

This command will download the kubeconfig and merge it with your default kubeconfig file (typically `~/.kube/config`). You can now use `kubectl` to interact with your cluster:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

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

## Next Steps

After successfully bootstrapping your Raspberry Pi:

1. **Add additional nodes**: Follow the same process to add more nodes to your cluster
2. **Configure storage**: Set up persistent storage for your workloads
3. **Deploy applications**: Start deploying your applications to the cluster
4. **Set up monitoring**: Configure monitoring and logging for your cluster

## Additional Resources

- [Talos Linux Documentation](https://www.talos.dev/)
- [Talos Image Factory](https://factory.talos.dev)
- [Installation Guide](../../install.md)
