# Windsor env audit (rely on hook, avoid manual env)

Audit of private-workspace scripts and tasks from the perspective: **rely on the Windsor CLI hook for environment variables; avoid manually setting env vars that Windsor provides.**

## Changes made

### 1. Standardized on `windsor env --hook`

Replaced `windsor env` with `windsor env --hook` (and kept `--decrypt` where needed) so the current shell and child processes get the same env from Windsor.

**Updated files:**

- **bin/lib/windsor.sh** — `load_windsor_env_for_shell()` and `load_windsor_env()` now use `windsor env --hook`.
- **tasks/vm/Taskfile.yaml** — generate terraform.tfvars step uses `windsor env --hook`.
- **bin/vm/scripts/** — All scripts that load Windsor env now use `--hook`: set-timezone, validate-vm, setup-ssh, set-incus-remote-env, install-tools, init-workspace, expand-root-disk, create-vm, cleanup-if-needed, check-vm-image; setup-service-user and runner scripts use `--hook --decrypt`.
- **bin/vm/scripts/runner/** — unregister-from-github, setup-runner-user, install-github-runner use `windsor env --hook --decrypt`.
- **bin/device/lib/device-common.sh** — Windsor load uses `windsor env --hook`.
- **tasks/test/Taskfile.yaml** — generate-tfvars-step now runs `windsor context set` + `eval "$(windsor env --hook)"` at the start and then `task tc:generate-tfvars` without an `env VAR=...` wrapper, so the child task inherits from the hook.

### 2. Cursor rule added

- **.cursor/rules/windsor-env.mdc** — “Rely on Windsor CLI hook for environment; avoid manual env vars Windsor provides.” Documents the principle and session/pipeline exceptions.

## Left as-is (intentional)

- **parse-args.sh** — Exports and writes `.vm-instantiate.env` from CLI args. This is the **input** to the instantiate flow; Windsor doesn’t own these until a context exists. Comment already says context config comes from windsor env in each script/task.
- **initialize-context.sh** — Sources `.vm-instantiate.env`, builds/writes `windsor.yaml`, then exports VM_* and INCUS_REMOTE_NAME for the **next** step in the pipeline. That next step could in theory run the hook after the context is written; for now the “pass along” exports are kept so the pipeline doesn’t require refactoring.
- **tasks/vm/Taskfile.yaml** (runner status) — Reads `VM_INSTANCE_NAME` from `.vm-instantiate.env` and exports it for the status script. Same “session bridge” pattern when a new shell doesn’t have the instantiate session.
- **setup-incus.sh** (on VM) — Exports INCUS_REMOTE_* from session/env; these are for the VM side and come from the instantiate flow, not from Windsor on the host.
- **setup-ssh.sh** — `export VM_NETWORK_NAME="${iface}"` is a **discovered** value (interface name), not a Windsor var.

## Future improvements

- **initialize-context.sh** — After writing `windsor.yaml`, the next step could run `windsor context set <name>` and `eval $(windsor env --hook)` and drop the long export list if the context is already registered and the following scripts only need Windsor-provided vars.
- **tasks/test/Taskfile.yaml** (initialize-context step) — The block that exports `WINDSOR_CONTEXT`, `WINDSOR_PROJECT_ROOT`, etc. for “subsequent tasks” could be replaced by having each subsequent step run the hook with the right context, if Task’s multi-cmd behavior allows it.
