#!/bin/bash
set -e

# Determine directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_CONTAINER_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SIDESTORE_DIR="$LIVE_CONTAINER_DIR/../SideStoreBuild"

if [ ! -d "$SIDESTORE_DIR" ]; then
    echo "Error: SideStoreBuild directory not found at $SIDESTORE_DIR"
    exit 1
fi

echo "Using SideStoreBuild directory at: $SIDESTORE_DIR"
cd "$SIDESTORE_DIR"

# 1. Predefined files for UI detail navigation patch
PATCH1_FILES=(
    "AltStore/App Detail/AppViewController.swift"
    "AltStore/Components/AppBannerView.swift"
    "AltStore/Components/AppCardCollectionViewCell.swift"
    "AltStore/Components/HeaderContentViewController.swift"
    "AltStore/Components/PillButton.swift"
    "AltStore/Extensions/UIColor+AltStore.swift"
    "AltStore/My Apps/MyAppsComponents.swift"
    "AltStore/Settings/AnisetteServerList.swift"
    "AltStore/Settings/InsetGroupTableViewCell.swift"
    "AltStore/Sources/SourceDetailViewController.swift"
    "AltStore/TabBarController.swift"
)

# 2. Predefined files for Non-blocking startup patch
PATCH2_FILES=(
    "AltStore/AppBootManager.swift"
    "AltStore/LaunchViewController.swift"
    "AltStore/Managing Apps/AppManager.swift"
    "AltStore/SceneDelegate.swift"
)

# Temporarily register untracked files so they are included in git diff
untracked_files=$(git status --porcelain | grep '??' | awk '{print $2}')
if [ -n "$untracked_files" ]; then
    echo "Temporarily registering untracked files in Git..."
    echo "$untracked_files" | xargs git add -N
fi

# Get all modified files compared to base branch LiveContainerSupport
all_modified=($(git diff --name-only refs/heads/LiveContainerSupport))

# Function to check if an array contains an element
contains_element() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# Determine language selection files dynamically
PATCH3_FILES=()
for file in "${all_modified[@]}"; do
    if ! contains_element "$file" "${PATCH1_FILES[@]}" && ! contains_element "$file" "${PATCH2_FILES[@]}"; then
        PATCH3_FILES+=("$file")
    fi
done

echo "Generating Patch 1: sidestore-source-detail-navigation.patch..."
git diff refs/heads/LiveContainerSupport -- "${PATCH1_FILES[@]}" > "$SCRIPT_DIR/sidestore-source-detail-navigation.patch"

echo "Generating Patch 2: sidestore-nonblocking-startup.patch..."
git diff refs/heads/LiveContainerSupport -- "${PATCH2_FILES[@]}" > "$SCRIPT_DIR/sidestore-nonblocking-startup.patch"

if [ ${#PATCH3_FILES[@]} -gt 0 ]; then
    echo "Generating Patch 3 (dynamic): sidestore-language-selection.patch..."
    git diff refs/heads/LiveContainerSupport -- "${PATCH3_FILES[@]}" > "$SCRIPT_DIR/sidestore-language-selection.patch"
else
    echo "Warning: No files determined for Patch 3. Generating empty patch."
    > "$SCRIPT_DIR/sidestore-language-selection.patch"
fi

# Reset the intent-to-add states
git reset

echo "Success! Patches updated in: $SCRIPT_DIR"
