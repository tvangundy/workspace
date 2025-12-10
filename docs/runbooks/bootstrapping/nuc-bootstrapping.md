# Bootstrapping a Talos Cluster on Intel NUC

This guide walks you through bootstrapping a Talos Linux cluster on an Intel NUC device. The bootstrapping process uses a USB memory device to hold the Talos image and perform the initial bootup of the device. Once booted, the device will be ready for cluster configuration.

## Overview

Bootstrapping an Intel NUC with Talos Linux involves:

1. **Downloading the Talos image**: Getting the x86_64 image from the Talos image factory
2. **Preparing the boot media**: Writing the image to a USB memory device
3. **Initial boot**: Booting the Intel NUC from the prepared USB media
4. **Cluster configuration**: Applying the Talos configuration to form or join a cluster
5. **Retrieving access**: Getting the kubeconfig to interact with your cluster

The USB memory device serves as both the boot media and the initial storage for the Talos operating system. After the initial boot, the device will run entirely from this media.

## Prerequisites

Before starting, ensure you have:

- **Intel NUC device**: Compatible Intel NUC (x86_64 architecture)
- **USB memory device**: At least 8GB capacity (16GB or larger recommended)
- **Computer with macOS or Linux**: For preparing the boot media
- **Network connectivity**: The Intel NUC must be able to connect to your network
- **talosctl installed**: See the [Installation Guide](../../install.md) for setup instructions
- **Physical access**: To insert the boot media and power on the device

## Step 1: Download the Talos Image

Download the x86_64 Talos image from the [Talos image factory](https://factory.talos.dev). The image factory generates custom images based on your configuration requirements.

```bash
curl -LO https://factory.talos.dev/image/<image-id>/v1.11.5/metal-amd64.raw.xz
```

**Note**: The URL above is an example. Visit the [image factory](https://factory.talos.dev) to generate an image URL specific to your configuration needs. Select the x86_64 (amd64) architecture for Intel NUC devices.

## Step 2: Decompress the Image

The downloaded image is compressed in XZ format. Decompress it before writing to your boot media:

```bash
xz -d metal-amd64.raw.xz
```

This will create a `metal-amd64.raw` file that you'll write to your USB memory device.

## Step 3: Prepare the Boot Media

### Identify Your USB Memory Device

First, identify the device identifier for your USB memory device:

```bash
# macOS
diskutil list

# Linux
lsblk
# or
fdisk -l
```

Look for your USB memory device in the list. It will typically appear as `/dev/disk4` (macOS) or `/dev/sdX` (Linux). **Be very careful** to identify the correct device, as writing to the wrong device will destroy data.

### Write the Image to Boot Media

Write the decompressed image to your USB memory device. This process will erase all existing data on the device.

```bash
# macOS - Unmount the device first (replace disk4 with your device identifier)
diskutil unmountDisk /dev/disk4

# macOS - Write the image (replace disk4 with your device identifier)
sudo dd if=metal-amd64.raw of=/dev/rdisk4 conv=fsync bs=4M status=progress

# Linux - Unmount the device first (replace sdX with your device identifier)
sudo umount /dev/sdX*

# Linux - Write the image (replace sdX with your device identifier)
sudo dd if=metal-amd64.raw of=/dev/sdX conv=fsync bs=4M status=progress
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

## Step 4: Boot the Intel NUC

1. **Insert the boot media**: Insert the USB memory device into a USB port on your Intel NUC
2. **Connect network**: Ensure the Intel NUC is connected to your network via Ethernet (recommended) or Wi-Fi
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

## Step 5: Configure the Cluster

Once the Intel NUC has booted and you have its IP address, apply the Talos configuration:

```bash
talosctl apply-config --insecure --mode=interactive --nodes <node-ip-address>
```

Replace `<node-ip-address>` with the actual IP address of your Intel NUC.

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
