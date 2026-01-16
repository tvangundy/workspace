terraform {
  required_version = ">= 1.0"
  
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
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
  
  # Use a placeholder endpoint if IP is not set (to avoid validation errors in data sources)
  # The check_ip_addresses resource will fail before any resources are created if IPs are empty
  cluster_endpoint = var.control_plane_ip != "" ? "https://${var.control_plane_ip}:6443" : "https://127.0.0.1:6443"
  
  # Control plane VM configuration
  control_plane_vm = {
    name     = var.control_plane_vm_name
    image    = var.talos_image_alias
    ip       = var.control_plane_ip
    memory   = var.control_plane_memory
    cpu      = var.control_plane_cpu
  }
  
  # Worker VMs configuration
  worker_vms = [
    {
      name   = var.worker_0_vm_name
      ip     = var.worker_0_ip
      memory = var.worker_memory
      cpu    = var.worker_cpu
    },
    {
      name   = var.worker_1_vm_name
      ip     = var.worker_1_ip
      memory = var.worker_memory
      cpu    = var.worker_cpu
    }
  ]
}

# Generate Talos machine secrets
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Generate Talos client configuration
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [var.control_plane_ip]
  nodes                = concat([var.control_plane_ip], [var.worker_0_ip, var.worker_1_ip])
}

# Generate control plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = local.cluster_endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  
  config_patches = var.common_config_patches != "" ? [var.common_config_patches] : []
}

# Generate worker machine configuration
data "talos_machine_configuration" "worker" {
  cluster_name    = var.cluster_name
  machine_type    = "worker"
  cluster_endpoint = local.cluster_endpoint
  machine_secrets = talos_machine_secrets.cluster.machine_secrets
  
  config_patches = var.common_config_patches != "" ? [var.common_config_patches] : []
}

# Save Talos configurations to files
# Note: TALOSCONFIG environment variable must be set (typically in windsor.yaml)
resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.cluster.talos_config
  filename = var.talosconfig_path
}

resource "local_file" "controlplane_config" {
  content  = data.talos_machine_configuration.controlplane.machine_configuration
  filename = "${path.module}/controlplane.yaml"
}

resource "local_file" "worker_config" {
  content  = data.talos_machine_configuration.worker.machine_configuration
  filename = "${path.module}/worker.yaml"
}

# Control Plane VM
resource "incus_instance" "control_plane" {
  remote = local.remote_name
  name   = local.control_plane_vm.name
  image  = local.control_plane_vm.image
  type   = "virtual-machine"
  
  config = {
    "limits.memory"        = local.control_plane_vm.memory
    "limits.cpu"           = local.control_plane_vm.cpu
    "boot.autostart"       = "true"
    "security.secureboot"  = "false"
    "raw.qemu"             = "-cpu host"
  }
  
  device {
    name = "root"
    type = "disk"
    properties = {
      pool            = var.storage_pool
      path            = "/"
      "boot.priority" = "1"
    }
  }
  
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.physical_network_name
    }
  }
  
  depends_on = [
    local_file.controlplane_config
  ]
}

# Worker VMs
resource "incus_instance" "workers" {
  for_each = {
    for idx, vm in local.worker_vms : vm.name => vm
  }
  
  remote = local.remote_name
  name   = each.value.name
  image  = var.talos_image_alias
  type   = "virtual-machine"
  
  config = {
    "limits.memory"        = each.value.memory
    "limits.cpu"           = each.value.cpu
    "boot.autostart"       = "true"
    "security.secureboot"  = "false"
    "raw.qemu"             = "-cpu host"
  }
  
  device {
    name = "root"
    type = "disk"
    properties = {
      pool            = var.storage_pool
      path            = "/"
      "boot.priority" = "1"
    }
  }
  
  device {
    name = "eth0"
    type = "nic"
    properties = merge(
      {
        network = var.physical_network_name
      },
      each.value.name == var.worker_0_vm_name && var.worker_0_mac != "" ? { hwaddr = var.worker_0_mac } : {},
      each.value.name == var.worker_1_vm_name && var.worker_1_mac != "" ? { hwaddr = var.worker_1_mac } : {}
    )
  }
  
  depends_on = [
    local_file.worker_config,
    incus_instance.control_plane
  ]
}

# Check that IP addresses are configured before applying Talos configurations
# This runs after VMs are created, so the user can look up DHCP-assigned IPs
resource "null_resource" "check_ip_addresses" {
  depends_on = [
    incus_instance.control_plane,
    incus_instance.workers
  ]

  triggers = {
    control_plane_ip   = var.control_plane_ip
    worker_0_ip        = var.worker_0_ip
    worker_1_ip        = var.worker_1_ip
    control_plane_name = incus_instance.control_plane.name
    worker_names       = join(",", [for vm in incus_instance.workers : vm.name])
  }

  provisioner "local-exec" {
    command = <<-EOT
      MISSING_IPS=""
      
      if [ -z "${var.control_plane_ip}" ] || [ "${var.control_plane_ip}" = "" ]; then
        MISSING_IPS="$${MISSING_IPS}control_plane_ip "
      fi
      
      if [ -z "${var.worker_0_ip}" ] || [ "${var.worker_0_ip}" = "" ]; then
        MISSING_IPS="$${MISSING_IPS}worker_0_ip "
      fi
      
      if [ -z "${var.worker_1_ip}" ] || [ "${var.worker_1_ip}" = "" ]; then
        MISSING_IPS="$${MISSING_IPS}worker_1_ip "
      fi
      
      if [ -n "$${MISSING_IPS}" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "New installation detected - Nodes have been created"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "The VMs have been created and are booting. Once the nodes have completed"
        echo "booting to Talos (you can check the console in the Incus Web UI), please:"
        echo ""
        echo "  1. Wait for the nodes to complete booting to Talos (check the console in the Incus Web UI)"
        echo "  2. Get the DHCP-assigned IP addresses using Terraform output:"
        echo ""
        echo "     cd terraform/cluster"
        echo "     terraform output"
        echo ""
        echo "     Or get individual IPs:"
        echo "     terraform output -raw control_plane_ip"
        echo "     terraform output -json worker_ips"
        echo ""
        echo "     Note: IP addresses are also available in the Incus Web UI"
        echo "           (https://<incus-host-ip>:8443) under each VM's network details."
        echo ""
        echo "  3. Update your windsor.yaml file (contexts/<context>/windsor.yaml) with the IP addresses:"
        echo ""
        echo "     CONTROL_PLANE_IP: \"<ip-address>\""
        echo "     WORKER_0_IP:      \"<ip-address>\""
        echo "     WORKER_1_IP:      \"<ip-address>\""
        echo ""
        echo "  4. Regenerate terraform.tfvars from environment variables:"
        echo ""
        echo "     task talos:generate-tfvars"
        echo ""
        echo "  5. Run 'terraform apply' again to continue with Talos configuration."
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Note: This is expected behavior for new installations. VMs are created successfully."
        echo "      Update windsor.yaml, regenerate terraform.tfvars, then re-run 'terraform apply'."
        exit 0
      fi
      
      echo "✓ All IP addresses are configured"
      echo "  Control plane: ${var.control_plane_ip}"
      echo "  Worker 0:      ${var.worker_0_ip}"
      echo "  Worker 1:      ${var.worker_1_ip}"
    EOT
  }
}

# Apply Talos configuration to control plane (using null_resource with local-exec)
# Note: This will only run if IP addresses are configured (check_ip_addresses passes)
resource "null_resource" "apply_controlplane_config" {
  depends_on = [
    null_resource.check_ip_addresses,
    incus_instance.control_plane,
    local_file.controlplane_config,
    local_file.talosconfig
  ]
  
  # Only create this resource if IPs are configured
  count = (var.control_plane_ip != "" && var.worker_0_ip != "" && var.worker_1_ip != "") ? 1 : 0
  
  triggers = {
    config_content = data.talos_machine_configuration.controlplane.machine_configuration
    instance_name  = incus_instance.control_plane.name
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Using control plane IP: ${var.control_plane_ip}"
      echo "Waiting for Talos API port to be accessible on ${var.control_plane_ip}..."
      MAX_RETRIES=30
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if nc -z ${var.control_plane_ip} 50000 2>/dev/null; then
          echo "Talos API port is accessible"
          break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for Talos API port... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 10
      done
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: Talos API port did not become accessible after $MAX_RETRIES attempts"
        exit 1
      fi
      echo "Applying Talos configuration to control plane..."
      # Remove unsupported fields (grubUseUKICmdline) and HostnameConfig document
      TEMP_CONFIG=$(mktemp)
      awk '/^---$/ {exit} {print}' ${path.module}/controlplane.yaml | sed '/grubUseUKICmdline/d' > "$TEMP_CONFIG"
      talosctl apply-config \
        --insecure \
        --talosconfig "${var.talosconfig_path}" \
        --nodes ${var.control_plane_ip} \
        --file "$TEMP_CONFIG"
      rm -f "$TEMP_CONFIG"
    EOT
  }
}

# Apply Talos configuration to workers (using null_resource with local-exec)
# Note: This will only run if IP addresses are configured
resource "null_resource" "apply_worker_configs" {
  for_each = (var.control_plane_ip != "" && var.worker_0_ip != "" && var.worker_1_ip != "") ? {
    for idx, vm in local.worker_vms : vm.name => vm
  } : {}
  
  depends_on = [
    incus_instance.workers,
    local_file.worker_config,
    local_file.talosconfig,
    null_resource.apply_controlplane_config[0]
  ]
  
  triggers = {
    config_content = data.talos_machine_configuration.worker.machine_configuration
    instance_name  = each.value.name
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Get the IP for this worker from the variables
      if [ "${each.value.name}" = "${var.worker_0_vm_name}" ]; then
        WORKER_IP="${var.worker_0_ip}"
      elif [ "${each.value.name}" = "${var.worker_1_vm_name}" ]; then
        WORKER_IP="${var.worker_1_ip}"
      else
        echo "Error: Unknown worker VM name: ${each.value.name}"
        exit 1
      fi
      echo "Using worker ${each.value.name} IP: $WORKER_IP"
      echo "Waiting for Talos API port to be accessible on $WORKER_IP..."
      MAX_RETRIES=30
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if nc -z $WORKER_IP 50000 2>/dev/null; then
          echo "Talos API port is accessible"
          break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for Talos API port... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 10
      done
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: Talos API port did not become accessible after $MAX_RETRIES attempts"
        exit 1
      fi
      echo "Applying Talos configuration to worker ${each.value.name}..."
      # Remove unsupported fields (grubUseUKICmdline) and HostnameConfig document
      TEMP_CONFIG=$(mktemp)
      awk '/^---$/ {exit} {print}' ${path.module}/worker.yaml | sed '/grubUseUKICmdline/d' > "$TEMP_CONFIG"
      talosctl apply-config \
        --insecure \
        --talosconfig "${var.talosconfig_path}" \
        --nodes $WORKER_IP \
        --file "$TEMP_CONFIG"
      rm -f "$TEMP_CONFIG"
    EOT
  }
}

# Bootstrap etcd cluster
# Note: This will only run if IP addresses are configured
resource "null_resource" "bootstrap_cluster" {
  count = (var.control_plane_ip != "" && var.worker_0_ip != "" && var.worker_1_ip != "") ? 1 : 0
  
  depends_on = [
    null_resource.apply_controlplane_config[0]
  ]
  
  triggers = {
    instance_name = incus_instance.control_plane.name
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Bootstraping etcd cluster on control plane..."
      MAX_RETRIES=30
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if talosctl --talosconfig "${var.talosconfig_path}" --nodes ${var.control_plane_ip} version 2>/dev/null; then
          echo "Control plane API is ready"
          break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for control plane API... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 10
      done
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: Control plane API did not become ready after $MAX_RETRIES attempts"
        exit 1
      fi
      echo "Bootstrapping etcd cluster..."
      talosctl bootstrap \
        --talosconfig "${var.talosconfig_path}" \
        --nodes ${var.control_plane_ip}
    EOT
  }
}
