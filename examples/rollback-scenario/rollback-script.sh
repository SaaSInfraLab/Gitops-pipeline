#!/bin/bash

# Rollback Script for Flux GitOps
# This script helps rollback a deployment by reverting Git commits

set -e

REPO_PATH="${1:-.}"
NAMESPACE="${2:-sample-saas-app}"
APP_NAME="${3:-sample-app}"

echo "Flux GitOps Rollback Script"
echo "============================"
echo ""

# Check if we're in a git repository
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

cd "$REPO_PATH"

# Show recent commits
echo "Recent commits:"
git log --oneline -10
echo ""

# Prompt for commit to revert
read -p "Enter commit hash to revert (or 'HEAD' for last commit): " COMMIT_HASH

if [ "$COMMIT_HASH" = "HEAD" ] || [ -z "$COMMIT_HASH" ]; then
    COMMIT_HASH="HEAD"
fi

# Confirm rollback
echo ""
echo "This will revert commit: $COMMIT_HASH"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Revert the commit
echo ""
echo "Reverting commit..."
git revert --no-edit "$COMMIT_HASH"

# Show the changes
echo ""
echo "Changes to be applied:"
git show HEAD

# Confirm push
echo ""
read -p "Push changes to remote? (yes/no): " PUSH_CONFIRM

if [ "$PUSH_CONFIRM" = "yes" ]; then
    echo "Pushing changes..."
    git push origin main
    echo ""
    echo "✓ Rollback pushed to Git"
    echo ""
    echo "Flux will automatically sync the changes."
    echo "Monitor with: flux get kustomizations"
else
    echo ""
    echo "Changes are ready but not pushed."
    echo "Review and push manually when ready."
fi

