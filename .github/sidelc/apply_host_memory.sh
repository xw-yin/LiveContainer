#!/bin/bash
set -euo pipefail

SIDESTORE_DIR="$(cd "${1:?usage: apply_host_memory.sh <SideStore directory>}" && pwd)"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
SIGNER_DIR="$SIDESTORE_DIR/Dependencies/SideSign"

# Check both pinned sources before changing either repository. A dependency bump
# must fail visibly if its signing behavior no longer matches these patches.
git -C "$SIDESTORE_DIR" apply --check "$PATCH_DIR/host-memory-sidestore.patch"
git -C "$SIGNER_DIR" apply --check "$PATCH_DIR/host-memory-sidesign.patch"
git -C "$SIDESTORE_DIR" apply "$PATCH_DIR/host-memory-sidestore.patch"
git -C "$SIGNER_DIR" apply "$PATCH_DIR/host-memory-sidesign.patch"
git -C "$SIDESTORE_DIR" apply --check "$PATCH_DIR/apple-auth-sidestore.patch"
git -C "$SIGNER_DIR" apply --check "$PATCH_DIR/apple-auth-sidesign.patch"
git -C "$SIDESTORE_DIR" apply "$PATCH_DIR/apple-auth-sidestore.patch"
git -C "$SIGNER_DIR" apply "$PATCH_DIR/apple-auth-sidesign.patch"
echo 'Applied profile-backed host and standalone app memory setup.'
