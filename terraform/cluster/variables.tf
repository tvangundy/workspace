variable "incus_remote_name" {
  description = "Name of the Incus remote to use"
  type        = string
  default     = "local"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "control_plane_vm_name" {
  description = "Name of the control plane VM"
  type        = string
  default     = "talos-cp"
}

variable "worker_0_vm_name" {
  description = "Name of the first worker VM"
  type        = string
  default     = "talos-worker-0"
}

variable "worker_1_vm_name" {
  description = "Name of the second worker VM"
  type        = string
  default     = "talos-worker-1"
}

variable "control_plane_ip" {
  description = "IP address for the control plane node"
  type        = string
}

variable "worker_0_ip" {
  description = "IP address for the first worker node"
  type        = string
}

variable "worker_1_ip" {
  description = "IP address for the second worker node"
  type        = string
}

variable "control_plane_memory" {
  description = "Memory allocation for control plane VM (e.g., '2GB')"
  type        = string
  default     = "2GB"
}

variable "control_plane_cpu" {
  description = "CPU count for control plane VM"
  type        = string
  default     = "2"
}

variable "worker_memory" {
  description = "Memory allocation for worker VMs (e.g., '2GB')"
  type        = string
  default     = "2GB"
}

variable "worker_cpu" {
  description = "CPU count for worker VMs"
  type        = string
  default     = "2"
}

variable "talos_image_alias" {
  description = "Alias of the Talos image in Incus (must be imported first)"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version (e.g., 'v1.12.0')"
  type        = string
}

variable "physical_network_name" {
  description = "Name of the physical network interface (e.g., 'eno1')"
  type        = string
  default     = "eno1"
}

variable "common_config_patches" {
  description = "Common configuration patches to apply to all nodes (YAML string)"
  type        = string
  default     = ""
}

variable "storage_pool" {
  description = "Name of the Incus storage pool to use for VMs"
  type        = string
  default     = "local"
}

variable "talosconfig_path" {
  description = "Path to the Talos configuration file (from TALOSCONFIG environment variable)"
  type        = string
}

variable "kubeconfig_file" {
  description = "Path to the kubeconfig file (from KUBECONFIG_FILE environment variable)"
  type        = string
}

