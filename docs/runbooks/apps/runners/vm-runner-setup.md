---
title: "GitHub Actions Runner on IncusOS VM"
description: "Deploy a GitHub Actions runner on an Ubuntu VM on IncusOS using runner:instantiate"
---
# GitHub Actions Runner on IncusOS VM

Deploy a GitHub Actions runner on an Ubuntu VM on IncusOS using `task runner:instantiate`. The task creates the VM, sets up the runner user, and installs and registers the GitHub Actions runner.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Server](../../bootstrapping/nuc-incusos.md))
- Incus CLI on your machine, remote configured
- Workspace initialized and context set (see [Initialize Workspace](../../workspace/init.md))
- GitHub repo or org access and a runner registration token

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
  VM_INSTANCE_NAME: github-runner
  VM_MEMORY: 4GB
  VM_CPU: 4
  VM_AUTOSTART: true
  VM_NETWORK_NAME: eno1
  VM_DISK_SIZE: 50GB
  VM_INIT_WORKSPACE: false
  DOCKER_HOST: unix:///var/run/docker.sock
  RUNNER_USER: "runner"
  RUNNER_HOME: "/home/runner"
  GITHUB_RUNNER_REPO_URL: "https://github.com/<org-or-user>/<repo>"
  GITHUB_RUNNER_TOKEN: "<runner-token>"
```

Optional: `GITHUB_RUNNER_VERSION`, `GITHUB_RUNNER_ARCH` (default `x64`). For SOPS: put the token in `secrets.yaml`, encrypt with `task sops:encrypt-secrets-file`, and set `GITHUB_RUNNER_TOKEN: sops.GITHUB_RUNNER_TOKEN` in `windsor.yaml`.

## Step 3: Get GitHub Runner Token

1. In GitHub: **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Choose Linux, x64, and copy the registration token.
3. Set `GITHUB_RUNNER_TOKEN` in `windsor.yaml` (or in SOPS secrets as above).

The token is short-lived; use it when you run instantiate.

## Step 4: Verify Remote

```bash
incus remote list
incus list <remote-name>:
windsor env | grep INCUS_REMOTE_NAME
```

## Step 5: Create the Runner VM

```bash
task runner:instantiate -- <remote-name> [<runner-name>] [--keep]
```

- `<remote-name>` (required): Incus remote (e.g. `nuc`)
- `<runner-name>` (optional): VM name (default: `runner`)
- `--keep`: Do not destroy VM after creation (use for real deployments)

Instantiate will: verify remote, create the VM with `vm:instantiate`, set up the runner user, install and configure the GitHub Actions runner, and start the service. On first run you may be prompted for repo URL and token if not in env/secrets.

## Step 6: Verify

- In GitHub: **Settings** → **Actions** → **Runners** — runner should appear with a green status.
- On the VM: `incus exec $INCUS_REMOTE_NAME:<runner-name> -- sudo systemctl status actions.runner.*.service`

Use `runs-on: self-hosted` in workflows to target this runner.

## Managing the Runner

```bash
task runner:status -- <runner-name>
incus start $INCUS_REMOTE_NAME:<runner-name>
incus stop $INCUS_REMOTE_NAME:<runner-name>
```

To access the VM: get IP from `incus list $INCUS_REMOTE_NAME:<runner-name>` and SSH as your user, or use `incus exec $INCUS_REMOTE_NAME:<runner-name> -- bash`.

## Destroying the Runner VM

```bash
task runner:destroy -- <runner-name>
```

This stops the runner service, unregisters it from GitHub, and destroys the VM. Use `runner:destroy` (not only `vm:destroy`) so the runner is removed from GitHub.

## INCUS_TRUST_TOKEN (for runners that run Incus VM tests)

When this runner executes workflows that create VMs and configure Incus remotes (e.g., Incus VM Tests), store the Incus trust token in the runner's environment so the action gets it from the device it's running on.

**Generate the token** on the Incus server (or from a host with Incus access):

```bash
incus config trust add <client-name>
# Copy the token from the output
```

**Set on the runner** (choose one):

- **systemd service**: Add `Environment="INCUS_TRUST_TOKEN=<token>"` to the runner's service file
- **Runner .env**: Add `INCUS_TRUST_TOKEN=<token>` to `.env` in the runner directory (if your runner loads it)
- **GitHub secret**: Add `INCUS_TRUST_TOKEN` as a repo secret; the workflow passes `secrets.INCUS_TRUST_TOKEN` to the action

The script prefers `INCUS_TRUST_TOKEN` from the environment over generating a token at runtime.

## Troubleshooting

- **Runner not in GitHub**: Check token is correct and not expired; check logs: `incus exec $INCUS_REMOTE_NAME:<runner-name> -- sudo journalctl -u actions.runner.*.service -n 50`
- **Service not starting**: `incus exec $INCUS_REMOTE_NAME:<runner-name> -- sudo systemctl status actions.runner.*.service`
- **VM not starting**: `incus list $INCUS_REMOTE_NAME:`, `incus console $INCUS_REMOTE_NAME:<runner-name>`

## Related

- [IncusOS Server](../../bootstrapping/nuc-incusos.md)
- [Ubuntu VMs](../../incusos/vm.md)
- [VM Taskfile](../../../taskfiles/vm/README.md) (includes `--runner` and `instantiate:add-runner-if-requested`)
