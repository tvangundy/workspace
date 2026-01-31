# Update the Intel NUC BIOS

This runbook walks you through updating the BIOS on an Intel NUC (including ASUS-manufactured NUCs) using a USB drive. A current BIOS is recommended before installing Ubuntu or Talos—follow this runbook **before** [Ubuntu Setup](./nuc-ubuntu.md) or [Intel NUC Talos Bootstrapping](./nuc-talos.md).

## Overview

Updating the Intel NUC BIOS involves:

1. **Downloading the BIOS update** — From the manufacturer support page for your NUC model
2. **Extracting the update files** — Unzip to get the `.bio` file and `IFLASH2.exe`
3. **Setting Windsor context** — Initialize the `nuc-bios` context with `windsor init nuc-bios`
4. **Updating windsor.yaml** — Setting `BIOS_FOLDER` and `USB_DISK` in `windsor.yaml`
5. **Copying files to the devices folder** — Using `task device:prepare-bios`
6. **Writing the BIOS update to USB** — Formatting USB as FAT32 and copying files with `task device:write-bios-disk`
7. **Booting and applying the update** — Boot the NUC from the USB drive (F7) and run the update

## Prerequisites

- **Intel NUC device** — Compatible Intel NUC (x86_64)
- **USB memory device** — At least 1GB, will be formatted (all data erased)
- **Computer with macOS or Linux** — For preparing the USB
- **Physical access** — To the NUC for power and boot media
- **Windsor workspace** — Clone or open the workspace repository

## Step 1: Download the BIOS Update

### Find Your NUC Model

Identify your NUC model (e.g. NUC8i5BEH, NUC8i3BEH). It is usually printed on the device or visible in the current BIOS.

### Download from Manufacturer

Visit the manufacturer support page for your NUC model and download the latest BIOS:

| Model | BIOS Downloads |
|-------|----------------|
| **ASUS NUC8i5BEH** | [ASUS Support](https://www.asus.com/supportonly/nuc8i5beh/helpdesk_bios/) |
| **ASUS NUC8i3BEH** | [ASUS Support](https://www.asus.com/supportonly/nuc8i3beh/helpdesk_bios/) |

For other models, search for "&lt;your-nuc-model&gt; BIOS download" or visit [Intel NUC support](https://www.intel.com/content/www/us/en/support/products/intel-nuc.html).

### Extract the BIOS Update

1. Download the BIOS ZIP file (e.g. `NUC8i5BEHAS003.BI.zip`)
2. Extract the ZIP to a folder (e.g. `~/Downloads/NUC8i5BEHAS003`)
3. Confirm the folder contains:
   - A `.bio` file (e.g. `NUC8i5BEH.003.bio`)
   - `IFLASH2.exe` (ASUS NUC firmware update utility)

**Note:** The exact filenames depend on your model and BIOS version.

## Step 2: Set Windsor context

Initialize and set the `nuc-bios` context:

```bash
windsor init nuc-bios
windsor context set nuc-bios
```

## Step 3: Update windsor.yaml

### Determine the target USB disk

Use `task device:list-disks` to identify your USB device:

```bash
task device:list-disks
```

Note the device identifier (e.g. `/dev/disk4`). **Use the correct disk** — writing to the wrong device can destroy data.

### Add variables to windsor.yaml

Add or update the `environment` section in `contexts/nuc-bios/windsor.yaml`:

```yaml
environment:
  # Path to the extracted BIOS update folder (contains .bio and IFLASH2.exe)
  BIOS_FOLDER: "/Users/$USER/Downloads/BECFL357"

  # USB device for the BIOS update (use task device:list-disks to identify)
  USB_DISK: "/dev/disk4"
```

Replace `BIOS_FOLDER` with the full path to your extracted BIOS folder, and `USB_DISK` with your USB device.

## Step 4: Prepare BIOS Files in the Workspace

Copy the BIOS update files from your downloads folder to the workspace devices directory:

```bash
task device:prepare-bios
```

This copies the contents of `BIOS_FOLDER` to `contexts/nuc-bios/devices/bios/`.

## Step 5: Write the BIOS Update to USB

This task will **erase** the USB device, format it as FAT32, and copy the BIOS files:

```bash
task device:write-bios-disk
```

**Warning:** All data on the USB device will be destroyed. Ensure no important data is on the drive.

## Step 6: Eject the USB Device

Safely eject the USB drive:

```bash
task device:eject-disk
```

## Step 7: Boot the NUC and Apply the BIOS Update

1. **Insert the USB drive** into a USB port on the Intel NUC
2. **Power on** the NUC (or restart if it is already on)
3. **Press F7** during boot to open the boot menu (or the key shown on screen for "Boot Menu")
4. **Select the USB device** from the boot menu
5. **Reboot** when the update finishes

## Step 8: Verify the BIOS Version

1. Reboot the NUC and press **F2** to enter BIOS Setup
2. Check the BIOS version on the main screen
3. Configure boot settings as needed (e.g. USB boot, Secure Boot) for your next installation

## Troubleshooting

### USB Device Not Detected During BIOS Update

- Reformat the USB as **FAT32** and ensure **Quick Format** is **deselected**
- Use a different USB drive
- Try a USB 2.0 port if USB 3.0 fails

### Write Task Fails on macOS

- Ensure the USB disk is not in use (close Finder windows showing the drive)
- Run `diskutil unmountDisk /dev/disk<N>` before retrying
- Verify `USB_DISK` points to the correct device with `task device:list-disks`

### Update Fails or NUC Does Not Boot

- Do not interrupt the update; wait for it to complete
- If the NUC becomes unresponsive, see the manufacturer’s BIOS recovery instructions

## Next Steps

After updating the BIOS:

- **[Ubuntu Setup](./nuc-ubuntu.md)** — Install Ubuntu on the NUC
- **[Intel NUC Talos Bootstrapping](./nuc-talos.md)** — Bootstrap a Talos Kubernetes cluster
