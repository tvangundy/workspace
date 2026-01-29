# Talos Kubernetes Cluster on IncusOS

Create a three-node Talos Kubernetes cluster on a remote IncusOS server using `task tc:instantiate`. The task creates the VMs, applies Talos config, bootstraps etcd, and retrieves kubeconfig.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Server](server.md))
- Incus CLI on your machine, remote configured
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- At least 8GB RAM and 100GB storage on the IncusOS host for 3 VMs
- Network with DHCP for the VMs

## Step 1: Install Tools

Ensure `aqua.yaml` includes:

```yaml
packages:
- name: hashicorp/terraform@v1.10.3
- name: siderolabs/talos@v1.9.1
- name: kubernetes/kubectl@v1.32.0
- name: lxc/incus@v6.20.0
- name: helm/helm@v3.17.3
- name: fluxcd/flux2@v2.5.1
- name: derailed/k9s@v0.50.3
- name: go-task/task@v3.42.1
```

Then run:

```bash
aqua install
```

## Step 2: Configure Environment

Get a schematic ID from [Talos Image Factory](https://factory.talos.dev) (or use an empty schematic for default image).

Add to `contexts/<context>/windsor.yaml`:

```yaml
environment:
  INCUS_REMOTE_NAME: "nuc"
  CLUSTER_NAME: "talos-vm-cluster"
  CONTROL_PLANE_VM: "talos-cp"
  WORKER_0_VM: "talos-worker-0"
  WORKER_1_VM: "talos-worker-1"
  TALOS_IMAGE_SCHEMATIC_ID: "<from-factory.talos.dev>"
  TALOS_IMAGE_VERSION: "v1.12.0"
  TALOS_IMAGE_ARCH: "metal-amd64"
  STORAGE_POOL: "local"
  TALOSCONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.talos/talosconfig
  KUBECONFIG_FILE: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
  KUBECONFIG: $WINDSOR_PROJECT_ROOT/contexts/$WINDSOR_CONTEXT/.kube/config
```

Leave `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP` empty for a new cluster. The instantiate task will create the VMs, get DHCP IPs, update your config, and continue with Talos.

Optional: `PHYSICAL_INTERFACE` (default `eno1`), `CONTROL_PLANE_MEMORY`/`WORKER_MEMORY` (default 2GB), `CONTROL_PLANE_CPU`/`WORKER_CPU` (default 2).

## Step 3: Talos Image

Download and import the Talos image so it exists on the remote:

```bash
task incus:download-talos-image
task incus:import-talos-image -- talos-${TALOS_IMAGE_VERSION}-metal-amd64
```

Instantiate will warn if the image is missing but will not fail.

## Step 4: Verify Remote

```bash
incus remote list
incus list <remote-name>:
windsor env | grep INCUS_REMOTE_NAME
```

## Step 5: Create the Cluster

```bash
task tc:instantiate -- <remote-name> [<cluster-name>] [--keep]
```

- `<remote-name>` (required): Incus remote (e.g. `nuc`)
- `<cluster-name>` (optional): Cluster name (default: `talos-test-cluster`)
- `--keep`: Do not destroy cluster after creation (use for real deployments)

Instantiate will: verify remote, check no existing cluster VMs, ensure image, generate tfvars, create 3 VMs, wait for them, get IPs from Terraform, update `windsor.yaml`, regenerate tfvars, apply Talos config, bootstrap etcd, and retrieve kubeconfig. This takes several minutes.

## Step 6: Verify Cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
task talos:health-controlplane
task talos:health-worker
```

## Managing the Cluster

```bash
task tc:list
incus list $INCUS_REMOTE_NAME:
incus start $INCUS_REMOTE_NAME:<vm-name>
incus stop $INCUS_REMOTE_NAME:<vm-name>
incus restart $INCUS_REMOTE_NAME:<vm-name>
incus console $INCUS_REMOTE_NAME:<vm-name>
```

## Destroying the Cluster

```bash
task tc:destroy
```

This removes all cluster VMs and their data. Talos image and physical network are not deleted.

## Troubleshooting

- **VMs not booting**: Check Talos image alias matches `talos-${TALOS_IMAGE_VERSION}-metal-amd64`; see [IncusOS Server](server.md) for network (Step 8).
- **No IPs**: Ensure physical network has `instances` role; wait 3–5 minutes for DHCP.
- **Bootstrap fails**: Ensure control plane is up; run `talosctl --nodes <control-plane-ip> version`.
- **Resource errors**: Lower `CONTROL_PLANE_MEMORY`/`WORKER_MEMORY` (min 2GB per VM).

## Related

- [IncusOS Server](server.md)
- [Initialize Workspace](../workspace/init.md)
- [TC Taskfile](../../taskfiles/tc/README.md)
