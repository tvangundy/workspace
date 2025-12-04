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

## Docker Compose Command Not Found (Ubuntu)
If you encounter the following error on Ubuntu systems:

```
Error: Error running container runtime Up command: Error executing command  [up --detach --remove-orphans]: command start failed: exec: no command
```

This typically occurs because Windsor is looking for the standalone `docker-compose` command, but only the newer `docker compose` (with a space) is available.

**To fix:**

1. **Install the standalone docker-compose binary:**
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Verify the installation:**
   ```bash
   docker-compose --version
   ```

3. **Ensure the binary is in your PATH:**
   ```bash
   echo $PATH | grep /usr/local/bin
   ```

4. **Retry Windsor commands:**
   ```bash
   windsor up
   ```

**Alternative solution:** If you prefer to use only the newer `docker compose` command, you can create a symlink:
```bash
sudo ln -sf /usr/bin/docker /usr/local/bin/docker-compose
```

This will allow Windsor to find the docker-compose command it expects while using the newer Docker Compose implementation.
