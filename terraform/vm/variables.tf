variable "incus_remote_name" {
  description = "Name of the Incus remote to use"
  type        = string
  default     = "local"
}

variable "vm_name" {
  description = "Name of the Ubuntu VM instance"
  type        = string
}

variable "vm_image" {
  description = "Ubuntu image to use (e.g., 'ubuntu/24.04')"
  type        = string
  default     = "ubuntu/24.04"
}

variable "vm_memory" {
  description = "Memory allocation for the VM (e.g., '8GB')"
  type        = string
  default     = "8GB"
}

variable "vm_cpu" {
  description = "CPU count for the VM"
  type        = string
  default     = "4"
}

variable "vm_autostart" {
  description = "Whether to start the VM automatically on host boot"
  type        = bool
  default     = false
}

variable "physical_network_name" {
  description = "Name of the physical network interface for direct network access (e.g., 'eno1', 'enp5s0'). Leave empty to use default Incus network."
  type        = string
  default     = ""
}

variable "storage_pool" {
  description = "Name of the Incus storage pool to use for VMs"
  type        = string
  default     = "local"
}

variable "vm_disk_size" {
  description = "Disk size for the VM root filesystem (e.g., '50GB', '100GB'). Leave empty for unlimited (uses storage pool default)."
  type        = string
  default     = ""
}

