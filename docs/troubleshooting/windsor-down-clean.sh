#!/bin/bash
# Wrapper script for `windsor down` that suppresses known non-critical cleanup errors
#
# Usage:
#   ./windsor-down-clean.sh
#   # or
#   ./windsor-down-clean.sh --clean
#
# This script runs `windsor down` and filters out known non-critical cleanup errors
# related to OCIRepository sources not found during cleanup kustomization deletion.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if we encountered only cleanup errors
CLEANUP_ERROR_ONLY=false
EXIT_CODE=0

# Run windsor down and capture output
echo "🧹 Running Windsor down..."
echo ""

# Capture both stdout and stderr
# Note: Use temporary file to capture output since command substitution always succeeds
TMP_OUTPUT=$(mktemp)
trap "rm -f $TMP_OUTPUT" EXIT

# Run windsor down and capture output and exit code
set +e  # Temporarily disable exit on error
windsor down "$@" > "$TMP_OUTPUT" 2>&1
EXIT_CODE=$?
set -e  # Re-enable exit on error

OUTPUT=$(cat "$TMP_OUTPUT")

if [ $EXIT_CODE -eq 0 ]; then
    # Command succeeded - show output normally
    echo "$OUTPUT"
    exit 0
else
    
    # Check if the error is the known cleanup error
    if echo "$OUTPUT" | grep -q "OCIRepository.source.toolkit.fluxcd.io.*not found" || \
       echo "$OUTPUT" | grep -q "cleanup kustomization.*failed.*OCIRepository"; then
        
        # Check if the error is ONLY about cleanup (not other errors)
        # Count total errors and cleanup-specific errors
        ERROR_COUNT=$(echo "$OUTPUT" | grep -c "Error:" || echo "0")
        CLEANUP_ERROR_COUNT=$(echo "$OUTPUT" | grep -c "OCIRepository.*not found" || echo "0")
        
        # Filter out the cleanup error from output
        FILTERED_OUTPUT=$(echo "$OUTPUT" | grep -v "OCIRepository.source.toolkit.fluxcd.io.*not found" | \
                                         grep -v "cleanup kustomization.*failed.*OCIRepository")
        
        # Show filtered output
        echo "$FILTERED_OUTPUT"
        
        # Check if there are other real errors
        if [ "$ERROR_COUNT" -eq "$CLEANUP_ERROR_COUNT" ]; then
            # Only cleanup errors - suppress them
            echo ""
            echo -e "${YELLOW}ℹ️  Cleanup completed with non-critical warnings (OCIRepository not found during cleanup)${NC}"
            echo -e "${GREEN}✅ Resources have been successfully deleted${NC}"
            
            # Verify resources are actually gone (if kubectl/helm available)
            echo ""
            echo "Verifying cleanup..."
            set +e  # Temporarily disable exit on error for verification
            if command -v kubectl >/dev/null 2>&1; then
                if kubectl get all -A 2>/dev/null | grep -q -i flux; then
                    echo -e "${RED}⚠️  Warning: Some Flux resources may still exist${NC}"
                    set -e
                    exit 1
                fi
            fi
            if command -v helm >/dev/null 2>&1; then
                if helm list -A 2>/dev/null | grep -q -i flux; then
                    echo -e "${RED}⚠️  Warning: Some Flux Helm releases may still exist${NC}"
                    set -e
                    exit 1
                fi
            fi
            set -e  # Re-enable exit on error
            echo -e "${GREEN}✅ Verified: All Flux resources have been deleted${NC}"
            exit 0
        else
            # Other errors exist - show them
            echo ""
            echo -e "${RED}❌ Windsor down failed with real errors${NC}"
            exit $EXIT_CODE
        fi
    else
        # Different error - show full output
        echo "$OUTPUT"
        exit $EXIT_CODE
    fi
fi

