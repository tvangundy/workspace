terraform {
  required_version = ">= 1.0"
  
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0"
    }
  }
}

# Configure the Incus Provider
provider "incus" {
  # Configuration is read from environment or ~/.config/incus/config.yml
  # Use INCUS_REMOTE_NAME environment variable to specify remote
}

# Local values for common configuration
locals {
  remote_name = var.incus_remote_name != "" ? var.incus_remote_name : "local"

  # Base root disk properties (pool, path, optional size)
  base_root_disk = length(var.vm_disk_size) > 0 ? {
    pool            = var.storage_pool
    path            = "/"
    "boot.priority" = "1"
    size            = var.vm_disk_size
  } : {
    pool            = var.storage_pool
    path            = "/"
    "boot.priority" = "1"
  }

  # Optional disk performance options (see docs/runbooks/debug/incus-vm-disk-performance.md)
  optional_disk_opts = merge(
    var.vm_disk_zfs_block_mode ? { "initial.zfs.block_mode" = "true" } : {},
    var.vm_disk_io_bus != "" ? { "io.bus" = var.vm_disk_io_bus } : {},
    var.vm_disk_io_cache != "" ? { "io.cache" = var.vm_disk_io_cache } : {}
  )
  root_disk_properties = merge(local.base_root_disk, local.optional_disk_opts)
}

# Ubuntu VM
resource "incus_instance" "vm" {
  remote = local.remote_name
  name   = var.vm_name
  image  = var.vm_image
  type   = "virtual-machine"
  
  config = {
    "limits.memory"        = var.vm_memory
    "limits.cpu"           = var.vm_cpu
    "boot.autostart"       = var.vm_autostart ? "true" : "false"
    "security.secureboot"  = "false"
  }
  
  device {
    name = "root"
    type = "disk"
    properties = local.root_disk_properties
  }
  
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.physical_network_name != "" ? var.physical_network_name : "incusbr0"
    }
  }
}

