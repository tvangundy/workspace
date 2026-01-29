# Ubuntu Virtual Machines on IncusOS

Create and manage Ubuntu VMs on a remote IncusOS server using `task vm:instantiate`. The VM gets developer tools, Docker, your user, SSH keys, and optional workspace setup automatically.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Server](server.md))
- Incus CLI on your machine, remote configured (`incus remote add`)
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))

## Step 1: Install Tools

Ensure `aqua.yaml` includes:

```yaml
packages:
- name: hashicorp/terraform@v1.10.3
- name: lxc/incus@v6.20.0
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
```

Then run:

```bash
aqua install
```

## Step 2: Configure Environment

Add to `contexts/<context>/windsor.yaml`:

```yaml
environment:
  INCUS_REMOTE_NAME: your-remote-name
  VM_INSTANCE_NAME: vm
  VM_IMAGE: ubuntu/24.04
  VM_MEMORY: 8GB
  VM_CPU: 4
  VM_NETWORK_NAME: enp5s0   # Physical interface for direct network; leave empty for default
  VM_STORAGE_POOL: local
  VM_AUTOSTART: false
  VM_INIT_WORKSPACE: true   # Set false to skip workspace copy
  DOCKER_HOST: unix:///var/run/docker.sock
```

## Step 3: Verify Remote

```bash
incus remote list
incus list <remote-name>:
windsor env | grep INCUS_REMOTE_NAME
```

## Step 4: Create the VM

```bash
task vm:instantiate -- <remote-name> [<vm-name>] [--keep] [--no-workspace] [--windsor-up]
```

- `<remote-name>` (required): Incus remote (e.g. `nuc`)
- `<vm-name>` (optional): VM name (default: `vm`)
- `--keep`: Do not destroy VM after creation (use for real deployments)
- `--no-workspace`: Skip workspace initialization
- `--windsor-up`: Run `windsor init` and `windsor up` after workspace setup

Instantiate will: verify remote, ensure image, generate tfvars, run Terraform, set up SSH, install tools (Git, Docker, etc.), create your user and copy SSH keys, and optionally initialize workspace. Allow a few minutes for the VM to boot and get a DHCP address.

## Step 5: Verify and Access

```bash
task vm:list
incus list $INCUS_REMOTE_NAME:
incus info $INCUS_REMOTE_NAME:$VM_INSTANCE_NAME
```

Get the VM IP from `incus list` (IPv4 column). SSH as your username: `ssh <username>@<vm-ip>`. For a shell without SSH: `incus exec $INCUS_REMOTE_NAME:$VM_INSTANCE_NAME -- bash`.

The VM has your username, SSH keys, Git config, and Docker.

## Managing the VM

```bash
incus start $INCUS_REMOTE_NAME:$VM_INSTANCE_NAME
incus stop $INCUS_REMOTE_NAME:$VM_INSTANCE_NAME
incus restart $INCUS_REMOTE_NAME:$VM_INSTANCE_NAME
task vm:destroy -- <vm-name>
```

## Troubleshooting

- **VM won't start**: `incus list <remote>:`, `incus start <remote>:<vm>`
- **No SSH**: Get IP from `incus list <remote>:<vm>`; check SSH in VM: `incus exec <remote>:<vm> -- systemctl status ssh`
- **Docker**: `incus exec <remote>:<vm> -- systemctl status docker`

## Related

- [IncusOS Server](server.md)
- [Initialize Workspace](../workspace/init.md)
- [VM Taskfile](../../taskfiles/vm/README.md)
