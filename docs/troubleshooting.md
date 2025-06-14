# Troubleshooting

## Docker Certificate or Connectivity Issues (macOS)
If you encounter persistent certificate errors or connectivity issues with containers or Talos, you may need to reset Docker to factory defaults. This is especially relevant if you see errors related to TLS, x509, or Ed25519 verification failures.

**To reset Docker Desktop on Mac:**

1. Open Docker Desktop.
2. Go to **Settings** (gear icon) > **Troubleshoot**.
3. Click **Reset to factory defaults** and confirm.
4. Wait for Docker to restart. All containers, images, and settings will be removed.

This can resolve issues where Docker's internal certificates or networking are in a bad state.

## Time Synchronization (Talos)
Talos and its clients require synchronized clocks for TLS certificates to be valid. If the system time on your Mac and the Talos nodes are not in sync, you may see errors like:

```
rpc error: code = Unavailable desc = connection error: desc = "transport: authentication handshake failed: tls: 
failed to verify certificate: x509: certificate signed by unknown authority (possibly because of 'x509: Ed25519 
verification failure' while trying to verify candidate authority certificate 'talos')"
```

**To fix:**

- Ensure your Mac's clock is set automatically (System Settings > General > Date & Time).
- Ensure Talos nodes are configured to use NTP (see the `machine.time.servers` patch in your configuration).
- If running Talos in a VM, make sure the VM host's clock is also correct.

After correcting time, retry your Talos commands. 
