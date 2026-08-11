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
require 'try dbContext.save()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'try await AppBootManager.shared.ensureMinimuxerStarted()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'public nonisolated func ensureMinimuxerStarted() async throws' 'SideStore/AppBootManager.swift'
require 'private struct MinimuxerStartup' 'SideStore/AppBootManager.swift'
require 'try await startup.task.value' 'SideStore/AppBootManager.swift'

# Landscape layout fixes must survive upstream rebases as well.
require 'override func viewWillTransition(to size:' 'AltStore/News/NewsViewController.swift'
require 'layout.sectionInsetReference = .fromContentInset' 'AltStore/News/NewsViewController.swift'
require 'let maxHorizontalSafeArea = max(safeArea.left, safeArea.right)' 'AltStore/News/NewsViewController.swift'
require 'override func viewWillTransition(to size:' 'AltStore/Sources/SourcesViewController.swift'
require 'layoutConfiguration.contentInsetsReference = .safeArea' 'AltStore/Sources/SourcesViewController.swift'
require 'layout.sectionInsetReference = .fromContentInset' 'AltStore/My Apps/MyAppsViewController.swift'
require 'let maxHorizontalSafeArea = max(safeArea.left, safeArea.right)' 'AltStore/My Apps/MyAppsViewController.swift'
require 'override func viewWillTransition(to size:' 'AltStore/My Apps/MyAppsViewController.swift'
require 'override func viewSafeAreaInsetsDidChange()' 'AltStore/My Apps/MyAppsViewController.swift'
require 'func configureCardMargins(for cell: UICollectionViewCell)' 'AltStore/My Apps/MyAppsViewController.swift'
require 'func symmetricHorizontalInset(in collectionView: UICollectionView)' 'AltStore/My Apps/MyAppsViewController.swift'
require 'appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]' 'AltStore/Settings/Error Log/ErrorLogViewController.swift'
require 'containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)' 'AltStore/Authentication/InstructionsViewController.swift'
require 'self.title = NSLocalizedString("Refresh Attempts", comment: "")' 'AltStore/Settings/RefreshAttemptsViewController.swift'
require '"My Apps" = "我的应用";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"4gT-9u-k7y.title" = "我的应用";' 'AltStore/zh-Hans.lproj/Main.strings'
require '"SIGN OUT" = "注销";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Connection Config" = "连接配置";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"iie-Nj-lki.text" = "连接配置";' 'AltStore/zh-Hans.lproj/Settings.strings'
require 'self.viewControllers?[tab.rawValue].tabBarItem.title = title' 'AltStore/TabBarController.swift'
require 'override func safeAreaInsetsDidChange()' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'let horizontalInset = max(self.safeAreaInsets.left, self.safeAreaInsets.right) + 16' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'self.navigationItem.largeTitleDisplayMode = .always' 'AltStore/Settings/RefreshAttemptsViewController.swift'
require 'ScrollView(.vertical)' 'SideStore/Views/Settings/Advanced/WirelessPair/WirelessPairView.swift'
require 'UIInterfaceOrientationLandscapeLeft' 'AltStore/Info.plist'
require 'widthSizable="YES" flexibleMaxY="YES"' 'AltStore/Settings/Settings.storyboard'

echo 'LiveContainer SideStore integration checks passed.'
