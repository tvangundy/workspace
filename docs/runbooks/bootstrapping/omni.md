# Raspberry Pi Cluster Device Setup

This guide covers the setup of Raspberry Pi devices for use in Talos Kubernetes clusters managed by Sidero Omni.


## Prerequisites

- Raspberry Pi hardware
- USB drive for boot media
- [Sidero Omni](https://www.siderolabs.com/platform/saas-for-kubernetes/) account
- Physical access to the device

## Setup Steps

### 1. Prepare Boot Media

**Using Device Tasks:**
```bash
# List available disks
task device:list-disks

# Write Raspberry Pi Talos image to USB
task rpi:write-disk
```

**Manual Steps:**
1. Download Talos image for Omni from the [Omni documentation](https://omni.siderolabs.com/docs/how-to-guides/how-to-register-a-bare-metal-machine-iso/)
2. Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or `task rpi:write-disk`
3. Write image to USB drive (boots from `/dev/sda`)

### 2. Boot Device

1. Insert the boot USB drive into the top USB port
2. Power on the Raspberry Pi
3. Device will boot into Talos and connect to Omni

### 3. Verify in Omni Console

- Wait for device to appear in the [Omni console](https://windsor.omni.siderolabs.io/omni/)
- Device should show in the machines list

### 4. Configure in Omni

1. Create config patch with:

   - Install disk: `/dev/sda`
   - Hostname configuration
   - Network settings
2. Assign config patch to the machine

### 5. Cluster Bootstrap

```bash
# Set context
windsor context set home-cluster

# Bootstrap cluster
task bootstrap

# Verify
kubectl get nodes
```

