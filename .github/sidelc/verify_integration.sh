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
require 'embeddedLiveContainerApplication' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
require 'configureForEmbeddedLiveContainer' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
require '@objc dynamic static let altStoreSourceURL' 'AltStore/Core/Model/Source.swift'
require 'configureForEmbeddedLiveContainer' 'AltStore/Core/Model/StoreApp.swift'
require 'let hostApplication = ALTApplication(fileURL: Bundle.realMainBundle.bundleURL)' 'AltStore/Core/Model/InstalledApp.swift'
reject 'func openLC' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'userLabel="OpenLC"' 'AltStore/iOS/Main.storyboard'
require 'try dbContext.save()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'try await AppBootManager.shared.ensureMinimuxerStarted()' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'public nonisolated func ensureMinimuxerStarted() async throws' 'SideStore/AppBootManager.swift'
require 'private struct MinimuxerStartup' 'SideStore/AppBootManager.swift'
require 'let generation: UInt' 'SideStore/AppBootManager.swift'
require 'try await startup.task.value' 'SideStore/AppBootManager.swift'
require 'private nonisolated func makeMinimuxerStartup' 'SideStore/AppBootManager.swift'
require 'minimuxerStartup?.generation == startup.generation' 'SideStore/AppBootManager.swift'
require 'Task.detached(priority: .userInitiated)' 'SideStore/AppBootManager.swift'
require 'private nonisolated func runMinimuxerStartup' 'SideStore/AppBootManager.swift'
reject 'private static var currentStartup' 'SideStore/AppBootManager.swift'
require 'try await self.ensureMinimuxerStarted()' 'SideStore/AppBootManager.swift'
reject 'validateMinimuxerConnection' 'SideStore/AppBootManager.swift'
require 'fm.altstoreSharedDirectory' 'SideStore/AppBootManager.swift'
require 'Bundle.realMainBundle' 'SideStore/AppBootManager.swift'
reject 'group.com.rileytestut.AltStore' 'SideStore/AppBootManager.swift'
require 'AppBootManager.shared.getSavedPairingFile()' 'SideStore/Core/Pairing/PairingFileManager.swift'
require 'Successfully copied pairing file to shared container' 'SideStore/Core/Pairing/PairingFileManager.swift'
require 'try? await AppBootManager.shared.ensureMinimuxerStarted()' 'SideStore/Views/Settings/TechyThings/HealthCheck/HealthCheckViewModel.swift'
require 'let readyResult = await minimuxer.core.isReady()' 'SideStore/Views/Settings/TechyThings/HealthCheck/HealthCheckViewModel.swift'
reject 'isReady(withDDIMountCheck: true)' 'SideStore/Views/Settings/TechyThings/HealthCheck/HealthCheckViewModel.swift'
require 'group.context.error = error' 'SideStore/Core/Operations/PipelineRunner.swift'
require 'async let minimuxerCheck: Void' 'SideStore/AppBootManager.swift'
require 'try await AppBootManager.shared.ensureMinimuxerStarted()' 'SideStore/SideStoreClient.swift'
require 'public func refreshAllApps(progress: Progress) async throws' 'SideStore/SideStoreClient.swift'
require '@objc(SideStoreRefreshService)' 'SideStore/SideStoreClient.swift'
require '@objc(performRefreshWithServer:)' 'SideStore/SideStoreClient.swift'
reject 'connection.exportedInterface = NSXPCInterface(with: RefreshClient.self)' 'SideStore/SideStoreClient.swift'
require_host 'refreshAllAppsWithIdentifier:' 'SideStoreSupport/XPCServer.h'
require_host 'mangledTypeName:' 'SideStoreSupport/XPCServer.h'
require_host 'NSClassFromString(@"SideStoreRefreshService")' 'SideStoreSupport/XPCClient.m'
require_host 'NSSelectorFromString(@"performRefreshWithServer:")' 'SideStoreSupport/XPCClient.m'
reject_host '[self performRefreshForRealWithIdentifier:' 'SideStoreSupport/XPCClient.m'
require_host 'LiveContainerShortcutsProvider: AppShortcutsProvider' 'SideStoreSupport/SideStore.swift'
require 'ShortcutsProvider: AppShortcutsProvider' 'AltStore/Intents/App Intents/AppShortcuts.swift'
reject 'bbc110bea43f84ba8cdb2e18490328024e6aba51' 'AltStore.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
require '@MainActor static func enqueueAppImport(_ url: URL)' 'AltStore/AppDelegate.swift'
require '@MainActor static func dequeueAppImport() -> URL?' 'AltStore/AppDelegate.swift'
require 'AppDelegate.enqueueAppImport(ipa)' 'AltStore/SceneDelegate.swift'
require 'self.presentNextAppImportIfNeeded()' 'AltStore/My Apps/MyAppsViewController.swift'
require 'if AppDelegate.hasPendingAppImports' 'AltStore/TabBarController.swift'
reject 'asyncAfter(deadline: .now() + 1.0)' 'AltStore/SceneDelegate.swift'
reject 'pendingImportIPAURL' 'AltStore/SceneDelegate.swift'
require 'recoverEmbeddedInstalledAppsFromCache' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
require '!FileManager.default.fileExists(atPath: databaseURL.path)' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
reject 'try FileManager.default.removeItem(at: databaseURL)' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
reject 'UTType(InstalledApp.installedAppUTI' 'AltStore/Core/Model/DatabaseManager/DatabaseManager.swift'
require 'isDefaultSourceRemoved' 'AltStore/Core/Extensions/UserDefaults+AltStore.swift'
require 'UserDefaults.standard.isDefaultSourceRemoved = true' 'AltStore/Managing Apps/AppManager.swift'
reject 'The default SideStore source cannot be removed.' 'AltStore/Managing Apps/AppManager.swift'
reject 'if self.source.identifier == Source.altStoreIdentifier' 'AltStore/Sources/SourceDetailViewController.swift'
require 'cell.accessories = [.delete(displayed: .whenEditing)]' 'AltStore/Sources/SourcesViewController.swift'
reject 'let hasOtherSources = sources.contains' 'AltStore/Sources/SourcesViewController.swift'
reject 'isMinimuxerStatusCheckEnabled' 'SideStore/AppBootManager.swift'
reject 'isMinimuxerStatusCheckEnabled' 'SideStore/Core/DeviceApi/MinimuxerWrapper.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStore/App IDs/AppIDsViewController.swift'
reject 'isMinimuxerStatusCheckEnabled' 'AltStore/Core/Extensions/UserDefaults+AltStore.swift'
require 'url = https://github.com/xw-yin/minimuxer' '.gitmodules'
require 'ffiDispatchQueue.async {' 'Dependencies/minimuxer/Common/FFIDispatcher.swift'
require 'var mountTask: Task<Bool, Error>? = nil' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
require 'var mountGeneration: UInt = 0' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
reject 'prewarmDDI' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
reject 'heartbeat.start()' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
require 'private func ensureDDIMounted() async throws' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
require 'try await self.ensureDDIMounted()' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
reject 'try await mountDDI(docsPath: mountPath)' 'Dependencies/minimuxer/Sources/MinimuxerImpl.swift'
require 'import Minimuxer' 'SideStore/AppBootManager.swift'
reject 'self.layer.shadowColor' 'AltStore/Components/AppBannerView.swift'
reject 'self.layer.shadowOpacity' 'AltStore/Components/AppBannerView.swift'
reject 'self.layer.shadowPath' 'AltStore/Components/AppBannerView.swift'
require 'minimuxer.emproxy.setHandshakeClient' 'SideStore/Core/DeviceApi/EMProxyWrapper.swift'
require 'try await minimuxer.emproxy.start' 'SideStore/Core/DeviceApi/EMProxyWrapper.swift'
reject 'self.viewModel.isSourceAdded = nil' 'AltStore/Sources/SourceDetailViewController.swift'
require 'title = NSLocalizedString("REMOVE", comment: "")' 'AltStore/Sources/SourceDetailViewController.swift'
reject 'setSideStoreLanguage' 'AltStore/AppDelegate.swift'
require_host 'if (!originalMethod || !swizzledMethod) return;' 'LiveContainer/utils.h'
require_host '@selector(appbundleIdentifier)' 'SideStoreSupport/SideStoreHooks.m'
require_host '@selector(storeAppBundleIdentifier)' 'SideStoreSupport/SideStoreHooks.m'
require_host '@selector(activeBundle)' 'SideStoreSupport/SideStoreHooks.m'
require_host 'SideStoreMyAppsViewController_hook_viewDidload' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'SSInstallVersionWindow' 'SideStoreSupport/SideStoreHooks.m'
reject_host 'swizzle(UITabBarController.class' 'SideStoreSupport/SideStoreHooks.m'
require_host 'hook_altstoreAppGroup' 'SideStoreSupport/SideStoreHooks.m'
require_host 'method_setImplementation' 'SideStoreSupport/SideStoreHooks.m'
require '? Bundle.realMainBundle.bundleURL' 'SideStore/Core/Certificates/CertificateManager.swift'
require 'ALTProvisioningProfile(url: bundleURL.appendingPathComponent("embedded.mobileprovision"))' 'SideStore/Core/Certificates/CertificateManager.swift'
require 'appBundle.provisioningProfile?.certificates.first' 'SideStore/Core/Certificates/CertificateManager.swift'
require 'let runningExpirationDate = ALTApplication(fileURL: runningBundleURL)?.provisioningProfile?.expirationDate' 'SideStore/Core/Operations/StandaloneOperations/ScheduleExpirationWarningNotificationOperation.swift'
require 'center.removeDeliveredNotifications(withIdentifiers: allIdentifiers)' 'SideStore/Core/Operations/StandaloneOperations/ScheduleExpirationWarningNotificationOperation.swift'
require 'content.userInfo[AppManager.expirationWarningDateKey] = expirationDate.timeIntervalSince1970' 'SideStore/Core/Operations/StandaloneOperations/ScheduleExpirationWarningNotificationOperation.swift'
require 'Suppressing stale expiration warning' 'AltStore/AppDelegate.swift'

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
require 'self.insetView.backgroundColor = .secondarySystemGroupedBackground' 'AltStore/Settings/InsetGroupTableViewCell.swift'
require 'static let settingsRowBackground = Color(uiColor: .secondarySystemGroupedBackground)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
require 'static let settingsDivider = Color(uiColor: .separator)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
require '"red" : "1.000"' 'AltStore/Resources/Assets.xcassets/Colors/SettingsBackground.colorset/Contents.json'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Diagnostics/DeveloperOptionsView.swift'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Diagnostics/ExperimentalFeaturesView.swift'
reject 'Color.white.opacity(0.15)' 'SideStore/Views/Settings/Advanced/BackupRestore/BackupAndRestoreView.swift'
require 'self.insetView.layer.masksToBounds = true' 'AltStore/Settings/InsetGroupTableViewCell.swift'
require '"color-space" : "srgb"' 'AltStore/Resources/Assets.xcassets/Colors/SettingsBackground.colorset/Contents.json'
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
require 'Text("MINIMUXER BACKEND")' 'SideStore/Views/Settings/Advanced/UserCustomizations/UserCustomizationsView.swift'
require 'Text(backend.rawValue)' 'SideStore/Views/Settings/Advanced/UserCustomizations/UserCustomizationsView.swift'
reject 'foregroundColor(Color.white.opacity(0.6))' 'SideStore/Views/Settings/Advanced/UserCustomizations/UserCustomizationsView.swift'
require '"MINIMUXER BACKEND" = "MINIMUXER 后端";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Enable SideJITServer" = "启用 SideJIT 服务器";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Connection Status" = "连接状态";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Diagnostics & Tools" = "诊断与工具";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"2N5-zd-fUj.normalTitle" = "登录";' 'AltStore/zh-Hans.lproj/Authentication.strings'
require '"qZ9-AR-2zK.normalTitle" = "知道了";' 'AltStore/zh-Hans.lproj/Authentication.strings'
require '"5nk-NR-jtV.title" = "重签 SideStore";' 'AltStore/zh-Hans.lproj/Authentication.strings'
require '"xcg-hT-tDe.normalTitle" = "立即重签";' 'AltStore/zh-Hans.lproj/Authentication.strings'
require '"qua-VA-asJ.normalTitle" = "稍后重签";' 'AltStore/zh-Hans.lproj/Authentication.strings'
require '"Failed to Sign In" = "登录失败";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"Failed to Resign SideStore" = "重签 SideStore 失败";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"LOGGING & DIAGNOSTICS" = "日志与诊断";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"STANDALONE FEATURES" = "独立功能";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '"No Bonjour services are currently advertised in this domain." = "此域中当前没有正在广播的 Bonjour 服务。";' 'AltStore/zh-Hans.lproj/Localizable.strings'
require '.foregroundStyle(.primary)' 'SideStore/Views/Settings/Advanced/NetworkDiscovery/BonjourDiscoveryViewV2.swift'
require 'NSLocalizedString("Ready (%d ms)"' 'SideStore/Views/Settings/Advanced/JIT/SideJITServerConfigView.swift'
require '<color key="textColor" systemColor="labelColor"/>' 'AltStore/Authentication/Authentication.storyboard'
require '<color key="textColor" systemColor="secondaryLabelColor"/>' 'AltStore/Authentication/Authentication.storyboard'
require '<color key="backgroundColor" systemColor="secondarySystemGroupedBackgroundColor"/>' 'AltStore/Authentication/Authentication.storyboard'
require 'navigationController.navigationBar.tintColor = .altPrimary' 'SideStore/Handlers/AuthFlowHandler.swift'
reject 'navigationController.view.tintColor = .altInvertedPrimary' 'SideStore/Handlers/AuthFlowHandler.swift'
require 'return .default' 'AltStore/Authentication/SelectTeamViewController.swift'
reject 'return .lightContent' 'AltStore/Authentication/SelectTeamViewController.swift'
require 'value: UIColor.secondaryLabel' 'AltStore/Authentication/ResignAltStoreViewController.swift'
require 'reasonLabel.textColor = .label' 'AltStore/Authentication/ResignAltStoreViewController.swift'
reject 'reasonLabel.textColor = .white' 'AltStore/Authentication/ResignAltStoreViewController.swift'
require 'viewControllers[tab.rawValue].tabBarItem.title = title' 'AltStore/TabBarController.swift'
require 'override func safeAreaInsetsDidChange()' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'let horizontalInset = max(self.safeAreaInsets.left, self.safeAreaInsets.right) + 16' 'AltStore/My Apps/InstalledAppsCollectionHeaderView.swift'
require 'self.navigationItem.largeTitleDisplayMode = .always' 'AltStore/Settings/RefreshAttemptsViewController.swift'
require 'ScrollView(.vertical)' 'SideStore/Views/Settings/Advanced/WirelessPair/WirelessPairView.swift'
require 'UIInterfaceOrientationLandscapeLeft' 'AltStore/Info.plist'
require 'widthSizable="YES" flexibleMaxY="YES"' 'AltStore/Settings/Settings.storyboard'
require 'viewControllers.indices.contains(Tab.browse.rawValue)' 'AltStore/TabBarController.swift'
require 'private func selectTab(_ tab: Tab)' 'AltStore/TabBarController.swift'
reject 'configureEmbeddedVersionLabel' 'AltStore/TabBarController.swift'
reject 'embeddedVersionLabel' 'AltStore/TabBarController.swift'
reject 'configureEmbeddedLiveContainerButton' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'liveContainerButton' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'image="escape" catalog="system"' 'AltStore/iOS/Main.storyboard'
reject 'UIStackView(arrangedSubviews: [sideloadButton, liveContainerButton])' 'AltStore/My Apps/MyAppsViewController.swift'
require 'self.tabBarItem.badgeColor = (status == .ready) ? .systemGreen : .systemRed' 'AltStore/My Apps/MyAppsViewController.swift'
reject 'NSStringFromClass(type(of: $0)).contains("LargeTitle")' 'AltStore/My Apps/MyAppsViewController.swift'
require 'guard let destinationVC = destinationViewController else' 'AltStore/LaunchViewController.swift'
reject 'UIStackView.appearance(whenContainedInInstancesOf: [UINavigationBar.self])' 'AltStore/AppDelegate.swift'
reject 'self.viewControllers![' 'AltStore/TabBarController.swift'

echo 'LiveContainer SideStore integration checks passed.'
