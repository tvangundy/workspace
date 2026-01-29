# Fixing Docker Disk Pressure in Ubuntu VM

## Problem
When running an Ubuntu VM in IncusOS with Docker, disk pressure occurs when:
- The VM's disk allocation is too small
- Docker images, containers, and volumes consume too much space
- The VM's root filesystem is running low on disk

This manifests as Kubernetes node taints: `node.kubernetes.io/disk-pressure:NoSchedule`

## Immediate Fix: Clean Up Docker

```bash
# Check Docker disk usage
docker system df

# Clean up everything (aggressive)
docker system prune -a --volumes --force

# Remove unused images
docker image prune -a --force

# Remove unused volumes
docker volume prune --force

# Remove build cache
docker builder prune --all --force
```

## Root Cause: VM Disk Size Configuration

### For Ubuntu VM in IncusOS

The VM's disk size is configured when the VM is created. To fix:

1. **Delete the existing VM** (if it exists)
2. **Recreate with larger disk size** using the `test` task with increased memory and disk

The VM configuration is controlled by:
- `VM_MEMORY` (default: 16GB for test task)
- `VM_DISK_SIZE` (default: 100GB for test task)

### Immediate Fix: Clean Up Docker Inside the VM

SSH into the VM and clean up Docker:

```bash
# Check host disk usage
df -h

# Check Docker's disk usage
docker system df -v

# Find large Docker files
sudo du -sh /var/lib/docker/* | sort -h | tail -10

# Clean up Docker
sudo docker system prune -a --volumes --force
```

## Solution: Delete and Recreate VM with More Resources

### Step 1: Delete Current VM

```bash
# Set Windsor context to test (if using test context)
windsor context set test

# Destroy the VM
task vm:destroy
```

### Step 2: Recreate with More Memory and Disk

The `test` task now defaults to:
- **Memory**: 16GB (increased from 8GB)
- **Disk**: 100GB (new, was unlimited before)

Run the test task:

```bash
# Run test with default settings (16GB RAM, 100GB disk)
task vm:test -- nuc

# Or customize memory and disk via environment variables
VM_MEMORY=32GB VM_DISK_SIZE=200GB task vm:test -- nuc
```

### Step 3: Clean Up Docker Inside the VM (After Recreation)

Once the new VM is created, SSH into it and clean up Docker:

```bash
# SSH into the VM
task vm:ssh

# Inside the VM, check disk usage
df -h

# Clean up Docker
sudo docker system prune -a --volumes --force

# Check Docker disk usage
sudo docker system df -v

# Remove unused images
sudo docker image prune -a --force

# Remove unused volumes
sudo docker volume prune --force
```

## Configure Docker Storage Driver (Inside VM)

If you need to limit Docker's storage usage within the VM:

```bash
# Edit Docker daemon config
sudo nano /etc/docker/daemon.json

# Add storage driver configuration (optional - usually not needed with 100GB+ disk)
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.size=50G"
  ]
}

# Restart Docker
sudo systemctl restart docker
```

Windsor may not expose direct disk size configuration. The containers use Docker's default allocation.

## Long-term Solution: Configure Windsor Cluster

### Option 1: Increase Docker Desktop Disk (Recommended for Docker Desktop)

This is the easiest fix if using Docker Desktop.

### Option 2: Add Disk Cleanup to Cluster Configuration

Add a cleanup job or configure log rotation in your Windsor setup. However, Windsor manages the Talos cluster, so this would need to be done at the Kubernetes level after the cluster is running.

### Option 3: Use Larger Base Disk

If the issue persists, you may need to:
1. Increase the host system's disk space
2. Move Docker's data directory to a larger disk
3. Use Docker volumes with size limits

## Check Current Disk Usage

```bash
# SSH into the VM
task vm:ssh

# Inside the VM, check disk usage
df -h

# Check what's using space
sudo du -sh /* 2>/dev/null | sort -h | tail -10

# Docker-specific usage
sudo docker system df -v

# Check individual container sizes
sudo docker ps --size

# Check volume sizes
sudo docker volume ls
sudo docker system df -v | grep -A 10 "Local Volumes"
```

## Prevent Future Issues

1. **Use larger disk size** when creating VMs (100GB+ recommended for Docker workloads)
2. **Set up log rotation** in Kubernetes
3. **Monitor disk usage** with alerts
4. **Regular cleanup** - add a cron job to clean up Docker periodically:

```bash
# Add to crontab (inside VM)
sudo crontab -e

# Add weekly Docker cleanup
0 2 * * 0 docker system prune -a --volumes --force
```

## Quick Diagnostic Commands

```bash
# Check what's using space
docker system df

# Check host disk
df -h /

# Check Docker directory size
sudo du -sh /var/lib/docker 2>/dev/null || du -sh ~/Library/Containers/com.docker.docker 2>/dev/null

# Check largest containers
docker ps -a --format "table {{.Names}}\t{{.Size}}" | sort -k2 -h
```

