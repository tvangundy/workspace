#!/bin/bash
# Script to patch the Flux pre-install hook job with tolerations
# Run this in a separate terminal BEFORE running windsor up

set -e

NAMESPACE="system-gitops"
JOB_NAME="flux2-flux-check"

echo "Waiting for job ${JOB_NAME} to be created..."
echo "Press Ctrl+C to stop"

# Wait for job to be created
while ! kubectl get job -n ${NAMESPACE} ${JOB_NAME} >/dev/null 2>&1; do
  sleep 1
done

echo "Job found! Patching with tolerations..."

# Patch the job to add tolerations
kubectl patch job -n ${NAMESPACE} ${JOB_NAME} --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations",
    "value": [
      {
        "key": "node-role.kubernetes.io/control-plane",
        "operator": "Exists",
        "effect": "NoSchedule"
      },
      {
        "key": "node.kubernetes.io/disk-pressure",
        "operator": "Exists",
        "effect": "NoSchedule"
      }
    ]
  }
]'

if [ $? -eq 0 ]; then
  echo "✅ Job patched successfully!"
  echo "The pod should now be able to schedule."
else
  echo "❌ Failed to patch job"
  exit 1
fi

# Watch the job
echo "Watching job status..."
kubectl get job -n ${NAMESPACE} ${JOB_NAME} -w

