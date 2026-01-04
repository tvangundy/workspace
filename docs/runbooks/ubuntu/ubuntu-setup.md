# Setting Up Ubuntu on Intel NUC

This guide walks you through installing and configuring Ubuntu on an [Intel NUC](https://www.intel.com/content/www/us/en/products/boards-kits/nuc.html) device. Ubuntu is a popular Linux distribution that provides a full-featured operating system suitable for development, server workloads, and general-purpose computing.

## Overview

Installing Ubuntu on an Intel NUC involves:

1. **Preparing the workspace**: Setting up the Windsor workspace and context
2. **Acquiring the Ubuntu ISO**: Downloading the Ubuntu installation image
3. **Setting environment variables**: Configuring workspace variables including the ISO path
4. **Preparing the NUC**: Updating BIOS and configuring boot settings
5. **Creating the boot media**: Writing the Ubuntu ISO to a USB device
6. **Booting and installing**: Booting from USB and installing Ubuntu to the NUC's storage
7. **Post-installation setup**: Configuring the system for your needs

Ubuntu provides a complete, user-friendly Linux distribution with extensive software support, making it ideal for development workstations, servers, and general-purpose computing on Intel NUC devices.

## Prerequisites

Before starting, ensure you have:

- **Intel NUC device**: Compatible Intel NUC (x86_64 architecture)
- **USB memory device**: At least 8GB capacity (16GB or larger recommended) for the boot media
- **Computer with macOS or Linux**: For preparing the boot media
- **Network connectivity**: The Intel NUC must be able to connect to your network via Ethernet (recommended) or Wi-Fi
- **At least 20GB of storage**: On the NUC's internal storage device (50GB or more recommended)
- **Physical access**: To the NUC for BIOS configuration and boot media insertion
- **Workspace initialized**: Follow the [Initialize Workspace](../workspace/init.md) runbook if you haven't already

## Step 1: Initialize Workspace and Context

### Create Workspace (if not already done)

If you haven't already initialized a workspace, follow the [Initialize Workspace](../workspace/init.md) runbook:

```bash
task workspace:initialize -- ubuntu ../ubuntu
cd ../ubuntu
```

### Initialize Windsor Context

Create a new context called "ubuntu":

```bash
windsor init ubuntu
```

## Step 2: Acquire Ubuntu ISO

### Download Ubuntu ISO

Download the Ubuntu installation ISO from the official website:

- **Ubuntu Desktop**: [Ubuntu Desktop Download](https://ubuntu.com/download/desktop) - Full desktop environment with GUI
- **Ubuntu Server**: [Ubuntu Server Download](https://ubuntu.com/download/server) - Minimal server installation without GUI

Choose the version that best fits your needs:

- **Desktop**: If you need a graphical interface, development tools, and desktop applications
- **Server**: If you're setting up a headless server or want a minimal installation

**Note**: After downloading, note the full path to the ISO file. You'll need this path for the environment variable in Step 3.

## Step 3: Set Environment Variables

### Determine the Target Disk for Image Copy

Use the `task device:list-disks` command to get a list of disks. Set the `USB_DISK` environment variable as shown below.

### Add these lines to ./contexts/ubuntu/windsor.yaml

```yaml
environment:
  USB_DISK: "/dev/disk4"
  
  # Path to the downloaded Ubuntu ISO file
  UBUNTU_ISO_FILE: "/Users/$USER/Downloads/ubuntu-24.04-desktop-amd64.iso"
```

**Note**: Replace the placeholder values with your actual configuration:

- `USB_DISK`: The device identifier for your USB memory device (use `task device:list-disks` to identify it)
- `UBUNTU_ISO_FILE`: The path to your downloaded Ubuntu ISO file (from Step 2)

### Prepare ISO in Workspace

Use the taskfile command to copy the downloaded ISO to the workspace devices folder:

```bash
task device:download-ubuntu-iso
```

This will copy the ISO file specified in `UBUNTU_ISO_FILE` to `contexts/<context>/devices/ubuntu/ubuntu.iso`.

## Step 4: Prepare the Intel NUC

### Update the BIOS

Before installing Ubuntu, ensure your NUC's BIOS is up to date. Visit the manufacturer's support page for your specific NUC model to download the latest BIOS:

- **ASUS NUC8i5BEH**: [BIOS Downloads](https://www.asus.com/supportonly/nuc8i5beh/helpdesk_bios/)

Download and install the latest BIOS update following the manufacturer's instructions.

### Configure Boot Settings

Access the NUC's BIOS settings (typically by pressing F2 during boot):

1. Navigate to the **Boot** tab in BIOS settings
2. In the **Boot Priority** section:
   - Select **"Boot USB devices First"** to prioritize USB boot
   - Enable **"USB"** booting if not already enabled
3. **Secure Boot** (optional):
   - Ubuntu supports Secure Boot, but you can disable it if you encounter issues
   - If using Secure Boot, ensure it's set to "Standard" mode (not "Custom")

### Wipe Existing Storage (Optional)

If the NUC previously had another operating system installed and you want a clean installation, you can wipe the storage device. **Warning**: This will destroy all data on the storage device.

```bash
# On the NUC (or from another system via SSH)
# Identify the storage device first
lsblk
# or
sudo fdisk -l

# Wipe the partition table (replace /dev/nvme0n1 with your device)
sudo wipefs -a /dev/nvme0n1

# Alternative: Zero the first few MB to destroy partition table
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M count=10
```

**Note**: You can also wipe the disk during the Ubuntu installation process using the installer's disk partitioning tool.

## Step 5: Prepare USB Boot Device

### Write Ubuntu ISO to USB

Write the Ubuntu ISO to your USB memory device. This process will erase all existing data on the device.

```bash
task device:write-ubuntu-iso [-- 3]
```

### Eject the USB Device

After writing completes, safely eject the device(s):

```bash
task device:eject-disk [-- 3]
```

The `eject-disk` task will automatically unmount the disks before ejecting them.

## Step 6: Boot and Install Ubuntu

1. **Insert the boot media**: Insert the USB memory device into a USB port on your Intel NUC
2. **Connect network**: Ensure the Intel NUC is connected to your network via Ethernet (recommended) or Wi-Fi
3. **Power on**: Connect power to the Intel NUC and turn it on
4. **Access boot menu**: Press F10 (or the appropriate key for your NUC model) during boot to access the boot menu
5. **Select USB device**: Choose the USB device from the boot menu
6. **Ubuntu installer loads**: The Ubuntu installer will load from the USB device
7. **Follow installation wizard**:
   - Select your language and keyboard layout
   - Choose installation type (normal installation or minimal installation)
   - Set up network connection (if not already connected)
   - Configure disk partitioning:
     - **Erase disk and install Ubuntu**: For a clean installation (recommended for new setups)
     - **Something else**: For custom partitioning (advanced users)
   - Create a user account and set a password
   - Wait for installation to complete
8. **Reboot**: When installation completes, remove the USB device and reboot the system

**Note**: The installation process will install Ubuntu to the internal storage device. After installation completes and the system reboots, Ubuntu will boot from the internal storage.

## Step 7: Post-Installation Setup

### Initial System Update

After Ubuntu boots for the first time, update the system:

```bash
sudo apt update
sudo apt upgrade -y
```

### Install Additional Software

Install common development and system tools:

```bash
# Essential build tools
sudo apt install -y build-essential curl wget git

# Additional useful tools
sudo apt install -y vim nano htop net-tools
```

### Configure SSH (for remote access)

If you want to access the NUC remotely:

```bash
# Install SSH server
sudo apt install -y openssh-server

# Enable and start SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Check SSH status
sudo systemctl status ssh
```

### Set Static IP Address (Optional)

If you need a static IP address for your NUC:

```bash
# Edit network configuration
sudo nano /etc/netplan/00-installer-config.yaml
```

Add or modify the configuration:

```yaml
network:
  version: 2
  ethernets:
    eno1:  # Replace with your network interface name
      dhcp4: false
      addresses:
        - 192.168.2.101/24
      routes:
        - to: default
          via: 192.168.2.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply the configuration:

```bash
sudo netplan apply
```

## Verification

Verify your Ubuntu installation is working correctly:

```bash
# Check system information
uname -a
lsb_release -a

# Check network connectivity
ip addr show
ping -c 3 8.8.8.8

# Check disk usage
df -h

# Check system resources
free -h
```

Your Ubuntu system should be fully operational and ready for use.

## Troubleshooting

### NUC Not Booting from USB

- Verify USB boot is enabled in BIOS/UEFI settings
- Check that "Boot USB devices First" is selected in boot priority
- Try a different USB port on the NUC
- Verify the ISO was written correctly to the USB device
- Ensure the USB device is properly formatted and recognized by the BIOS
- Try disabling Secure Boot if it's preventing boot

### Installation Fails

- Verify the storage device has at least 20GB of free space (50GB recommended)
- Check that the storage device is properly recognized
- Ensure the Ubuntu ISO is not corrupted (verify checksum)
- Try a different USB device
- Check BIOS settings for any restrictions

### Network Issues After Installation

- Verify network cable connection (if using Ethernet)
- Check network interface is up: `ip link show`
- Restart network service: `sudo systemctl restart networking`
- Check network configuration: `sudo netplan apply`
- Review network logs: `journalctl -u NetworkManager`

### Boot Issues After Installation

- Verify the boot device is set correctly in BIOS
- Check that Ubuntu was installed to the correct disk
- Ensure the USB device is removed after installation
- Try accessing GRUB boot menu (hold Shift during boot)
- Check boot logs: `journalctl -b`

### Wiping the Boot Disk Using Ubuntu Live USB

If you need to completely wipe the NUC's boot disk to start fresh, you can use an Ubuntu Live USB to boot into a recovery environment and wipe the disk. See the [Incus Setup runbook](../incus/incusos-setup.md) for detailed instructions on creating an Ubuntu Live USB and wiping disks.

## Next Steps

After successfully installing Ubuntu:

1. **Install development tools**: Set up your preferred development environment
2. **Configure services**: Install and configure any services you need (web server, database, etc.)
3. **Set up users**: Create additional user accounts if needed
4. **Configure firewall**: Set up UFW or another firewall solution
5. **Enable automatic updates**: Configure unattended-upgrades for security updates
6. **Set up backups**: Configure backup solutions for your data

## Additional Resources

- [Ubuntu Documentation](https://ubuntu.com/server/docs)
- [Ubuntu Desktop Guide](https://help.ubuntu.com/)
- [Ubuntu Installation Guide](https://ubuntu.com/tutorials/install-ubuntu-desktop)
- [Initialize Workspace Runbook](../workspace/init.md)
