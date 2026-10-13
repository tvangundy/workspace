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

## Step 1: Create or Set the Context

First, navigate to your workspace directory. Then either create a new context or switch to an existing one:

**To create a new context** (e.g., for a new environment or project):

```bash
cd /path/to/your/workspace
windsor init <context>
```

**To use an existing context** (if you already have a context defined):

```bash
cd /path/to/your/workspace
windsor context set <context>
```

Runner configuration will be read from `contexts/<context>/windsor.yaml` for whichever context is active.

## Step 2: Configure Environment

Add to `contexts/<context>/windsor.yaml`:

```yaml
environment:
  VM_INSTANCE_NAME: github-runner
  VM_MEMORY: 4GB
  VM_CPU: 4
  VM_AUTOSTART: true
  VM_NETWORK_NAME: eno1
  VM_DISK_SIZE: 50GB
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

## SOPS PGP key (bake into runner for Windsor decrypt in CI)

So the runner can decrypt context `secrets.enc.yaml` files in CI (e.g. for test-mailu), bake the **same PGP private key** used to encrypt those secrets into the runner at instantiation. Then every job on that runner can run `windsor env --hook --decrypt` and SOPS will decrypt the secrets; no workflow secret is required.

**test-runner (recommended):** The test-runner context already sets `SOPS_PGP_PRIVATE_KEY_FILE` in `contexts/test-runner/windsor.yaml`. Before running `task test-runner:instantiate`, you need **your** armored PGP private key (the one that encrypts your context secrets) at **`contexts/test-runner/sops-pgp.asc`** (relative to the forest-shadows project root; already in `.gitignore`).

**To export your key:** From the forest-shadows project root, run:

```bash
task test-runner:export-sops-key
```

The task will list your GPG secret keys and prompt you to choose which one to export. Pick the same key you use to encrypt `contexts/test-mailu/secrets.enc.yaml` (and any other context secrets the runner needs). It will write that key to `contexts/test-runner/sops-pgp.asc`. Then run `task test-runner:instantiate`; it will copy the key to the VM and import it into the runner user’s GPG keyring so CI jobs can run `windsor env --hook --decrypt` with your credentials.

**The key must be passphrase-less for CI.** In CI there is no TTY; if the key has a passphrase, gpg will fail with "Inappropriate ioctl for device". Either export a key that has no passphrase, or remove the passphrase before exporting: `gpg --edit-key <keyid>`, then `passwd`, enter the current passphrase, then leave the new passphrase empty (press Enter twice). Re-export with `task test-runner:export-sops-key` and re-run instantiate.

**Other runner contexts:** Export your key with `task vm:runner:export-sops-key -- <context-name>` (e.g. `task vm:runner:export-sops-key -- dev-runner`), which writes your chosen key to `contexts/<context-name>/sops-pgp.asc`. Or set one of these at instantiation time (env or `.workspace/.vm-instantiate.env`):

- **`SOPS_PGP_PRIVATE_KEY_FILE`** — Path on the host to the armored PGP private key file (absolute or relative to project root). Example: `contexts/dev-runner/sops-pgp.asc`.
- **`SOPS_PGP_PRIVATE_KEY`** — The armored key content (e.g. `export SOPS_PGP_PRIVATE_KEY="$(cat path/to/key.asc)"` before instantiate).

The key is copied to the VM and imported into the **runner user’s** GPG keyring in `setup-runner-user.sh` (same step that copies SSH keys). After import, a legacy `pubring.gpg` is created so SOPS’s Go library (which expects the old format) can find the keyring; GnuPG 2.1+ normally uses `pubring.kbx`. `gnupg` is installed on the VM if needed. Do not commit the key file; use `contexts/**/sops-pgp.asc` and `contexts/**/sops-pgp.key` in `.gitignore`. If `SOPS_PGP_PRIVATE_KEY_FILE` is set but the file is missing, instantiate fails with a clear error.

**Runner must run jobs on the host.** The key lives in `/home/runner/.gnupg` on the VM. If the runner is configured to run jobs **in a container**, the container’s `/home/runner` is not the host’s, so the keyring is empty and SOPS decrypt will fail with “No secret key”. Fix: either run jobs on the host (disable the default container in the runner’s config, e.g. `.runner` or the runner’s run script) or mount the host’s `/home/runner/.gnupg` into the job (e.g. via runner container volume mapping).

## Troubleshooting

- **SOPS decrypt fails in CI ("Inappropriate ioctl for device")**: The key has a passphrase and CI has no TTY to prompt. Use a passphrase-less key for the runner (see "The key must be passphrase-less for CI" above).
- **Runner not in GitHub**: Check token is correct and not expired; check logs: `incus exec $INCUS_REMOTE_NAME:<runner-name> -- sudo journalctl -u actions.runner.*.service -n 50`
- **Service not starting**: `incus exec $INCUS_REMOTE_NAME:<runner-name> -- sudo systemctl status actions.runner.*.service`
- **VM not starting**: `incus list $INCUS_REMOTE_NAME:`, `incus console $INCUS_REMOTE_NAME:<runner-name>`
- **SOPS decrypt fails in CI (GNUPGHOME exists=no, “No secret key”)**: The job is not seeing the keyring where instantiate put it. **Verify on the VM:** `ssh runner@<vm-ip> 'ls -la /home/runner/.gnupg'`. If the directory exists and contains key files (e.g. `pubring.kbx`, `private-keys.d`), the job is likely running in a container or an isolated environment where the host’s `/home/runner` is not visible—run jobs on the host (no `container:` in the workflow and no default container in the runner’s config) or mount the host’s `/home/runner/.gnupg` into the job. If the directory is missing or empty on the VM, re-run instantiate and ensure the “Install SOPS PGP key on runner” step completes successfully (and that `SOPS_PGP_PRIVATE_KEY_FILE` or `SOPS_PGP_PRIVATE_KEY` is set). See “Runner must run jobs on the host” above.

## Related

- [IncusOS Server](../../bootstrapping/nuc-incusos.md)
- [Ubuntu VMs](../../incusos/vm.md)
- [VM Taskfile](../../../taskfiles/vm/README.md) (includes `--runner` and `instantiate:add-runner-if-requested`)
