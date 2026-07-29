#!/bin/bash
set -euo pipefail

SIDESTORE_DIR="${1:?usage: verify_integration.sh <SideStore directory>}"

require() {
    local pattern="$1"
    local file="$2"
    grep -Fq "$pattern" "$SIDESTORE_DIR/$file" || {
        echo "Missing LiveContainer integration: $file -> $pattern" >&2
        exit 1
    }
}

# Keep the runtime bundle, registration identity, source, and icon behavior aligned.
require 'static let isBundledWithLiveContainer' 'Shared/Extensions/Bundle+AltStore.swift'
require 'static var realMainBundle' 'Shared/Extensions/Bundle+AltStore.swift'
require 'embeddedLiveContainerApplication' 'AltStoreCore/Model/DatabaseManager/DatabaseManager.swift'
require 'configureForEmbeddedLiveContainer' 'AltStoreCore/Model/DatabaseManager/DatabaseManager.swift'
require 'liveContainerSourceURL' 'AltStoreCore/Model/Source.swift'
require 'configureForEmbeddedLiveContainer' 'AltStoreCore/Model/StoreApp.swift'
require 'let hostApplication = ALTApplication(fileURL: Bundle.realMainBundle.bundleURL)' 'AltStoreCore/Model/InstalledApp.swift'
require 'func openLC' 'AltStore/My Apps/MyAppsViewController.swift'

echo 'LiveContainer SideStore integration checks passed.'
