output "control_plane_vm_name" {
  description = "Name of the control plane VM"
  value       = incus_instance.control_plane.name
}

output "worker_vm_names" {
  description = "Names of the worker VMs"
  value       = [for vm in incus_instance.workers : vm.name]
}

output "control_plane_ip" {
  description = "IP address of the control plane node (from terraform.tfvars)"
  value       = var.control_plane_ip
}

output "worker_ips" {
  description = "IP addresses of the worker nodes (from terraform.tfvars)"
  value = {
    worker_0 = var.worker_0_ip
    worker_1 = var.worker_1_ip
  }
}

output "all_node_ips" {
  description = "All node IP addresses (for easy reference)"
  value = {
    control_plane = var.control_plane_ip
    worker_0      = var.worker_0_ip
    worker_1      = var.worker_1_ip
  }
}

output "talosconfig_path" {
  description = "Path to the generated talosconfig file"
  value       = "${path.module}/talosconfig"
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "kubeconfig_instructions" {
  description = "Instructions for retrieving kubeconfig"
  value       = "Run: talosctl kubeconfig <output-path> --talosconfig ${path.module}/talosconfig --nodes $(terraform output -raw control_plane_ip)"
}

output "ip_address_note" {
  description = "Note about IP addresses"
  value       = "IP addresses are configured in terraform.tfvars. Make sure they match the actual DHCP-assigned IPs from your VMs."
}
