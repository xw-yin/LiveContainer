#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_CONTAINER_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SIDESTORE_DIR="${SIDESTORE_DIR:-$LIVE_CONTAINER_DIR/../SideStoreBuild}"
UPSTREAM_URL="${SIDESTORE_UPSTREAM_URL:-https://github.com/SideStore/SideStore.git}"
UPSTREAM_BRANCH="${SIDESTORE_UPSTREAM_BRANCH:-develop}"
INTEGRATION_BRANCH="${SIDESTORE_INTEGRATION_BRANCH:-LiveContainerSupport-v2}"

cd "$SIDESTORE_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo 'SideStore worktree is not clean; commit or stash changes before syncing.' >&2
    exit 1
fi

if git remote get-url upstream >/dev/null 2>&1; then
    git remote set-url upstream "$UPSTREAM_URL"
else
    git remote add upstream "$UPSTREAM_URL"
fi

git fetch upstream "$UPSTREAM_BRANCH"
git switch "$INTEGRATION_BRANCH"
git branch "backup/${INTEGRATION_BRANCH}-$(date +%Y%m%d%H%M%S)"
git rebase "upstream/$UPSTREAM_BRANCH"

"$SCRIPT_DIR/verify_integration.sh" "$SIDESTORE_DIR"
echo "Synced $INTEGRATION_BRANCH onto upstream/$UPSTREAM_BRANCH. Push it after reviewing the rebase."
