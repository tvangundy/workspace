# Fixing Flux Cleanup Errors During `windsor down`

## Problem

When running `windsor down`, you may encounter errors like:

```
✗ 🗑️  Uninstalling blueprint resources - Failed
Error: error running blueprint cleanup: failed to delete blueprint: deletion completed with 1 error(s): cleanup kustomization csi-cleanup failed: kustomization csi-cleanup failed: OCIRepository.source.toolkit.fluxcd.io "core" not found
```

**Root Cause:** Cleanup kustomizations (like `csi-cleanup`) reference Flux sources (OCIRepositories, GitRepositories, etc.) that have already been deleted or don't exist. This is a timing/ordering issue during cleanup.

## Impact

This is typically **non-critical** - it's a cleanup error that doesn't affect the actual resource deletion. The resources are usually already deleted, but the cleanup kustomization can't complete because it references a source that no longer exists.

## Solutions

### Solution 0: Use the Wrapper Script (Easiest - Recommended)

A wrapper script is available that automatically suppresses this error:

```bash
# Use the wrapper script instead of `windsor down` directly
./docs/troubleshooting/windsor-down-clean.sh

# Or if you want to pass flags like --clean
./docs/troubleshooting/windsor-down-clean.sh --clean

# Or create an alias for convenience
alias windsor-down='./docs/troubleshooting/windsor-down-clean.sh'
windsor-down
```

The script:
- Runs `windsor down` normally
- Automatically filters out the OCIRepository cleanup error
- Verifies that resources are actually deleted
- Returns success if only cleanup errors occurred
- Still fails if there are other real errors

**To use it permanently**, you can:

1. **Create a shell function** (add to `~/.bashrc` or `~/.zshrc`):
   ```bash
   windsor-down() {
       local script_path
       # Find the script relative to workspace root
       if [ -f "./docs/troubleshooting/windsor-down-clean.sh" ]; then
           script_path="./docs/troubleshooting/windsor-down-clean.sh"
       elif [ -f "$HOME/Developer/tvangundy/private-workspace/docs/troubleshooting/windsor-down-clean.sh" ]; then
           script_path="$HOME/Developer/tvangundy/private-workspace/docs/troubleshooting/windsor-down-clean.sh"
       else
           echo "Error: windsor-down-clean.sh not found"
           return 1
       fi
       "$script_path" "$@"
   }
   ```
   Then reload your shell: `source ~/.bashrc` or `source ~/.zshrc`

2. **Create a symlink**:
   ```bash
   ln -s "$(pwd)/docs/troubleshooting/windsor-down-clean.sh" /usr/local/bin/windsor-down-clean
   windsor-down-clean
   ```

3. **Use inline** (simple filtering - note: exit code won't be perfect):
   ```bash
   windsor down 2>&1 | grep -v "OCIRepository.*not found" | grep -v "cleanup kustomization.*failed.*OCIRepository"; echo "✅ Cleanup completed"
   ```

### Solution 1: Ignore the Error (Manual)

If `windsor down` completes most of the cleanup and only fails on the final cleanup step, you can safely ignore it. The actual resources have been deleted. You can verify:

```bash
# Check if resources are actually gone
kubectl get all -A | grep -i flux || echo "No flux resources found"
helm list -A | grep -i flux || echo "No flux Helm releases found"
kubectl get kustomizations -A | grep -i flux || echo "No flux kustomizations found"
```

If these show no resources, the cleanup was successful despite the error.

### Solution 2: Manually Delete Cleanup Kustomizations

If you want to clean up the error, manually delete the problematic cleanup kustomization:

```bash
# List cleanup kustomizations
kubectl get kustomizations -A | grep cleanup

# Delete the problematic cleanup kustomization
kubectl delete kustomization csi-cleanup -n system-gitops --ignore-not-found

# Or delete all cleanup kustomizations
kubectl get kustomizations -A -o name | grep cleanup | xargs kubectl delete --ignore-not-found
```

### Solution 3: Delete OCIRepository Sources First

If you want to prevent the error, manually delete the sources before running `windsor down`:

```bash
# List all Flux sources
kubectl get ocirepositories -A
kubectl get gitrepositories -A

# Delete them manually
kubectl delete ocirepositories -A --all --ignore-not-found
kubectl delete gitrepositories -A --all --ignore-not-found

# Then run windsor down
windsor down
```

### Solution 4: Force Delete Everything

If you want a complete cleanup and don't mind being aggressive:

```bash
# Delete all Flux resources
kubectl delete kustomizations -A --all --ignore-not-found
kubectl delete ocirepositories -A --all --ignore-not-found
kubectl delete gitrepositories -A --all --ignore-not-found
kubectl delete helmreleases -A --all --ignore-not-found

# Delete the Helm release
helm uninstall flux_system -n system-gitops --ignore-not-found
helm uninstall flux2 -n system-gitops --ignore-not-found

# Delete the namespace (this will delete everything in it)
kubectl delete namespace system-gitops --ignore-not-found

# Then run windsor down
windsor down
```

### Solution 5: Use `--clean` Flag

Some versions of Windsor support a `--clean` flag that may handle cleanup more aggressively:

```bash
windsor down --clean
```

## Prevention

This is a known issue with Flux cleanup ordering. The best prevention is:

1. **Wait for resources to stabilize** before running `windsor down`
2. **Don't interrupt** `windsor down` mid-execution
3. **Run cleanup in order** if doing manual cleanup (sources first, then kustomizations)

## Verification

After cleanup, verify everything is gone:

```bash
# Check all Flux resources
kubectl get kustomizations -A
kubectl get ocirepositories -A
kubectl get gitrepositories -A
kubectl get helmreleases -A

# Check Helm releases
helm list -A | grep -i flux

# Check namespaces
kubectl get namespaces | grep -i flux
kubectl get namespaces | grep -i gitops

# If all are empty/not found, cleanup was successful
```

## Related Issues

- [Flux Pre-install Timeout](./flux-preinstall-timeout.md)
- [Flux Taints Fix](./flux-taints-fix.md)

