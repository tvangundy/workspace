#!/bin/bash
# Quick fix script for Flux pre-install hook timeout
# Run this in your VM after SSH'ing in

set -e

echo "🔍 Checking Flux installation status..."
echo ""

# 1. Check Helm release status
echo "1. Helm release status:"
helm status flux2 -n system-gitops 2>&1 || echo "  Release not found or failed"
echo ""

# 2. Check for stuck jobs
echo "2. Checking for pre-install hook jobs:"
kubectl get jobs -n system-gitops 2>&1 || echo "  No jobs found"
echo ""

# 3. Check CRDs
echo "3. Checking Flux CRDs:"
kubectl get crds | grep -E "flux|source|kustomize|helm|notification|image" || echo "  No Flux CRDs found"
echo ""

# 4. Check events
echo "4. Recent events in system-gitops namespace:"
kubectl get events -n system-gitops --sort-by='.lastTimestamp' | tail -10 || echo "  No events found"
echo ""

# 5. Check pods
echo "5. Pods in system-gitops namespace:"
kubectl get pods -n system-gitops || echo "  No pods found"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Fix Options:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Option 1: Clean up and retry (recommended)"
echo "  helm uninstall flux2 -n system-gitops"
echo "  kubectl delete namespace system-gitops"
echo "  # Then re-run: windsor up"
echo ""
echo "Option 2: Install CRDs from Flux source repository (recommended)"
echo "  FLUX_VERSION=\"v2.5.1\"  # Match your Flux version"
echo "  curl -sL https://github.com/fluxcd/flux2/releases/download/\${FLUX_VERSION}/crds.yaml | kubectl apply --validate=false -f -"
echo "  # Wait for CRDs to be established, then re-run: windsor up"
echo ""
echo "Option 3: Check for specific errors"
echo "  kubectl describe job -n system-gitops <job-name>"
echo "  kubectl logs -n system-gitops -l app.kubernetes.io/name=flux2"
echo ""

