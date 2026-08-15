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

reject() {
    local pattern="$1"
    local file="$2"
    if grep -Fq "$pattern" "$SIDESTORE_DIR/$file"; then
        echo "Unsafe LiveContainer integration: $file -> $pattern" >&2
        exit 1
    fi
}

require_host() {
    local pattern="$1"
    local file="$2"
    grep -Fq "$pattern" "$file" || {
        echo "Missing LiveContainer host integration: $file -> $pattern" >&2
        exit 1
    }
}

reject_host() {
    local pattern="$1"
    local file="$2"
    if grep -Fq "$pattern" "$file"; then
        echo "Unsafe LiveContainer host integration: $file -> $pattern" >&2
        exit 1
    fi
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
require '<barButtonItem title="Item" image="escape" catalog="system" id="XLE-l0-Jf0" userLabel="OpenLC">' 'AltStore/Base.lproj/Main.storyboard'
require 'try dbContext.save()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'try await AppBootManager.shared.ensureMinimuxerStarted()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'public nonisolated func ensureMinimuxerStarted() async throws' 'SideStore/AppBootManager.swift'
require 'private struct MinimuxerStartup' 'SideStore/AppBootManager.swift'
require 'try await startup.task.value' 'SideStore/AppBootManager.swift'
require 'private nonisolated func makeMinimuxerStartup' 'SideStore/AppBootManager.swift'
require 'try await self.ensureMinimuxerStarted()' 'SideStore/AppBootManager.swift'
require 'await self?.validateMinimuxerConnection()' 'SideStore/AppBootManager.swift'
require '@MainActor static func enqueueAppImport(_ url: URL)' 'AltStore/AppDelegate.swift'
require '@MainActor static func dequeueAppImport() -> URL?' 'AltStore/AppDelegate.swift'
require 'AppDelegate.enqueueAppImport(ipa)' 'AltStore/SceneDelegate.swift'
require 'self.presentNextAppImportIfNeeded()' 'AltStore/My Apps/MyAppsViewController.swift'
require 'if AppDelegate.hasPendingAppImports' 'AltStore/TabBarController.swift'
reject 'asyncAfter(deadline: .now() + 1.0)' 'AltStore/SceneDelegate.swift'
reject 'pendingImportIPAURL' 'AltStore/SceneDelegate.swift'
reject 'isMinimuxerStatusCheckEnabled' 'SideStore/AppBootManager.swift'
reject 'isMinimuxerStatusCheckEnabled' 'SideStore/Core/DeviceApi/MinimuxerWrapper.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStore/App IDs/AppIDsViewController.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStoreCore/Extensions/UserDefaults+AltStore.swift'
require 'url = https://github.com/SideStore/minimuxer' '.gitmodules'
require 'label: "com.sidestore.minimuxer.idevice-ffi"' 'Dependencies/minimuxer/Sources/FFIDispatcher.swift'
require 'ffiDispatchQueue.async' 'Dependencies/minimuxer/Sources/FFIDispatcher.swift'
reject 'on queue: DispatchQueue = .global()' 'Dependencies/minimuxer/Sources/FFIDispatcher.swift'
require 'var mountGeneration: UInt = 0' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
require 'await prewarmDDI(docsPath: mountPath)' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
reject 'self.layer.shadowColor' 'AltStore/Components/AppBannerView.swift'
reject 'self.layer.shadowOpacity' 'AltStore/Components/AppBannerView.swift'
reject 'self.layer.shadowPath' 'AltStore/Components/AppBannerView.swift'
require 'Minimuxer.emproxy.setHandshakeClient' 'SideStore/Core/DeviceApi/EMProxyWrapper.swift'
require 'try await Minimuxer.emproxy.start' 'SideStore/Core/DeviceApi/EMProxyWrapper.swift'
reject 'self.viewModel.isSourceAdded = nil' 'AltStore/Sources/SourceDetailViewController.swift'
require 'title = NSLocalizedString("REMOVE", comment: "")' 'AltStore/Sources/SourceDetailViewController.swift'
reject 'setSideStoreLanguage' 'AltStore/AppDelegate.swift'
require_host 'if (!originalMethod || !swizzledMethod) return;' 'LiveContainer/utils.h'
reject_host '@selector(appbundleIdentifier)' 'SideStoreSupport/SideStoreHooks.m'
reject_host '@selector(activeBundle)' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'SideStoreMyAppsViewController_hook_viewDidload' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'swizzle(UITabBarController.class' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'hook_altstoreAppGroup' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'method_setImplementation' 'SideStoreSupport/SideStoreHooks.m'
require '? Bundle.realMainBundle.bundleURL' 'SideStore/Core/Certificates/CertificateManager.swift'
require 'ALTProvisioningProfile(url: bundleURL.appendingPathComponent("embedded.mobileprovision"))' 'SideStore/Core/Certificates/CertificateManager.swift'
require 'appBundle.provisioningProfile?.certificates.first' 'SideStore/Core/Certificates/CertificateManager.swift'

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
require 'appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]' 'AltStore/Settings/SettingsViewController.swift'
if grep -Fq 'appearance.titleTextAttributes = [.foregroundColor: UIColor.white]' "$SIDESTORE_DIR/AltStore/Settings/SettingsViewController.swift" ||
   grep -Fq 'appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]' "$SIDESTORE_DIR/AltStore/Settings/SettingsViewController.swift"; then
    echo 'Invalid settings navigation title color: hard-coded white' >&2
    exit 1
fi
require 'self.tableView.backgroundColor = .systemGroupedBackground' 'AltStore/Settings/SettingsViewController.swift'
require 'return .default' 'AltStore/Settings/SettingsViewController.swift'
reject 'return .lightContent' 'AltStore/Settings/SettingsViewController.swift'
require 'self.configureLanguageDisclosureIndicator()' 'AltStore/Settings/SettingsViewController.swift'
require 'UIImage.SymbolConfiguration(scale: .large)' 'AltStore/Settings/SettingsViewController.swift'
reject 'accessoryType="disclosureIndicator" indentationWidth="10" textLabel="Lng-Ti-tle"' 'AltStore/Settings/Settings.storyboard'
require 'self.insetView.backgroundColor = .secondarySystemGroupedBackground' 'AltStore/Settings/InsetGroupTableViewCell.swift'
require 'static let settingsRowBackground = Color(uiColor: .secondarySystemGroupedBackground)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
require 'static let settingsDivider = Color(uiColor: .separator)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
require '"red" : "1.000"' 'AltStore/Resources/Assets.xcassets/Colors/SettingsBackground.colorset/Contents.json'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Diagnostics/ExperimentalFeaturesView.swift'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Advanced/BackupRestore/BackupAndRestoreView.swift'
require 'self.scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor)' 'AltStore/Authentication/InstructionsViewController.swift'
require 'self.scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor)' 'AltStore/Authentication/InstructionsViewController.swift'
require 'self.contentStackView.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor)' 'AltStore/Authentication/InstructionsViewController.swift'
require 'label.textColor = .secondaryLabel' 'AltStore/Authentication/InstructionsViewController.swift'
require 'return .default' 'AltStore/Authentication/InstructionsViewController.swift'
reject 'return .lightContent' 'AltStore/Authentication/InstructionsViewController.swift'
reject 'cell.overrideUserInterfaceStyle = .dark' 'AltStore/Settings/AltAppIconsViewController.swift'
require 'self.title = NSLocalizedString("Refresh Attempts", comment: "")' 'AltStore/Settings/RefreshAttemptsViewController.swift'
require '"My Apps" = "我的应用";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"4gT-9u-k7y.title" = "我的应用";' 'AltStore/zh-Hans.lproj/Main.strings'
require '"SIGN OUT" = "注销";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Connection Config" = "连接配置";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Developer Options" = "开发者选项";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Experimental Features" = "实验性功能";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Backup & Restore" = "备份与恢复";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"User Customizations" = "用户自定义";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require 'Text(LocalizedStringKey(title))' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
require 'Text(LocalizedStringKey(title))' 'SideStore/Views/Settings/Diagnostics/OperationsLoggingControlView.swift'
require '"iie-Nj-lki.text" = "连接配置";' 'AltStore/zh-Hans.lproj/Settings.strings'
require 'viewControllers[tab.rawValue].tabBarItem.title = title' 'AltStore/TabBarController.swift'
require 'override func safeAreaInsetsDidChange()' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'let horizontalInset = max(self.safeAreaInsets.left, self.safeAreaInsets.right) + 16' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'self.navigationItem.largeTitleDisplayMode = .always' 'AltStore/Settings/RefreshAttemptsViewController.swift'
require 'ScrollView(.vertical)' 'SideStore/Views/Settings/Advanced/WirelessPair/WirelessPairView.swift'
require 'UIInterfaceOrientationLandscapeLeft' 'AltStore/Info.plist'
require 'widthSizable="YES" flexibleMaxY="YES"' 'AltStore/Settings/Settings.storyboard'
require 'viewControllers.indices.contains(Tab.browse.rawValue)' 'AltStore/TabBarController.swift'
require 'private func selectTab(_ tab: Tab)' 'AltStore/TabBarController.swift'
require 'func configureEmbeddedVersionLabel()' 'AltStore/TabBarController.swift'
require 'func configureEmbeddedLiveContainerButton()' 'AltStore/My Apps/MyAppsViewController.swift'
require 'items.count == 2' 'AltStore/My Apps/MyAppsViewController.swift'
require 'items[1].customView = liveContainerButton' 'AltStore/My Apps/MyAppsViewController.swift'
require 'liveContainerButton.tintColor = .label' 'AltStore/My Apps/MyAppsViewController.swift'
require 'items[0].tintColor = .label' 'AltStore/My Apps/MyAppsViewController.swift'
require 'UIImage.SymbolConfiguration(pointSize: 17, weight: .medium, scale: .large)' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'liveContainerButton.transform = CGAffineTransform(rotationAngle: .pi)' 'AltStore/My Apps/MyAppsViewController.swift'
require 'userLabel="OpenLC"' 'AltStore/Base.lproj/Main.storyboard'
reject 'UIStackView(arrangedSubviews: [sideloadButton, liveContainerButton])' 'AltStore/My Apps/MyAppsViewController.swift'
require 'self.tabBarItem.badgeColor = (status == .ready) ? .systemGreen : .systemRed' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'NSStringFromClass(type(of: $0)).contains("LargeTitle")' 'AltStore/My Apps/MyAppsViewController.swift'
require 'guard let destinationVC = destinationViewController else' 'AltStore/LaunchViewController.swift'
reject 'UIStackView.appearance(whenContainedInInstancesOf: [UINavigationBar.self])' 'AltStore/AppDelegate.swift'
reject 'self.viewControllers![' 'AltStore/TabBarController.swift'

echo 'LiveContainer SideStore integration checks passed.'
