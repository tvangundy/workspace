# Windsor Local: Talos TLS First-Apply Failure

## Problem

When running `windsor up` for a local cluster (Docker + Talos), the first Terraform apply fails with:

```
tls: failed to verify certificate: x509: certificate signed by unknown authority
(possibly because of "x509: Ed25519 verification failure" while trying to verify candidate authority certificate "talos")
```

## Cause

On first boot, Talos nodes use **self-signed TLS certificates**. The Terraform Talos provider's `talos_machine_configuration_apply` resource connects to the node over TLS but cannot verify the node's ephemeral cert, since it's not yet in the talosconfig (machine secrets).

## Solution

Apply the control plane configuration once with `talosctl apply-config --insecure` (which skips server cert verification), then run `windsor up` again. After the first apply, the node reboots with the proper certs and subsequent Terraform applies succeed.

### Automated (CI)

The Incus Local Test action uses a bootstrap script that:

1. Runs `windsor up` (expects it to fail on first apply)
2. On TLS error, extracts the control plane config from Terraform state
3. Runs `talosctl apply-config --insecure --nodes <endpoint> --file <config>`
4. Retries `windsor up`

Enable with `windsor_talos_bootstrap: true` (default). See `test/bin/windsor-local-talos-bootstrap.sh`.

### Manual

1. Run `windsor up` and let it fail at the Terraform Talos apply step.
2. Ensure Docker containers (control plane, workers) are running.
3. Find the control plane endpoint (Windsor local Docker typically uses `127.0.0.1:50000`).
4. Get the control plane config from Terraform (output or state).
5. Apply with insecure:

   ```bash
   talosctl apply-config --insecure --nodes 127.0.0.1:50000 --file controlplane.yaml
   ```

6. Wait for the node to reboot (~60s).
7. Run `windsor up` again.

## References

- [Talos: The insecure flag](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/system-configuration/insecure)
- Terraform Talos provider does not support an `--insecure` equivalent for `talos_machine_configuration_apply`
