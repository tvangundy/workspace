output "vm_name" {
  description = "Name of the Ubuntu VM instance"
  value       = incus_instance.vm.name
}

output "vm_remote" {
  description = "Incus remote where the VM is located"
  value       = incus_instance.vm.remote
}

output "vm_info" {
  description = "Instructions for getting VM information"
  value       = "Use 'incus list ${incus_instance.vm.remote}:${incus_instance.vm.name}' to view VM details and IP address"
}

