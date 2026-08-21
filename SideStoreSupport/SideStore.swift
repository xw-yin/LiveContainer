//
//  SideStore.swift
//  SideStoreSupport
//
//  Created by s s on 2025/7/20.
//

import Foundation
import AppIntents
import UserNotifications

@available(iOS 17.0, *)
func performIntentRefresh(identifier: String, mangledTypeName: String, intentProgress: Progress) async throws {
    intentProgress.totalUnitCount = 100
    if UserDefaults.isSideStore() {
        try await SideStoreIntentCaller.shared.callRefreshIntent(mangledTypeName: mangledTypeName)
    } else {
        RefreshHandler.shared.progress = intentProgress
        try await RefreshHandler.shared.startRefresh(identifier: identifier, mangledName: mangledTypeName)
    }
}

@available(iOS 17.0, *)
public struct RefreshAllAppsWidgetIntent: AppIntent, ProgressReportingIntent
{
    public static var title: LocalizedStringResource { LocalizedStringResource("Refresh Apps via Widget", defaultValue: "通过小组件刷新应用") }
    public static var isDiscoverable: Bool { false } // Don't show in Shortcuts or Spotlight.
    
    public init() {}
    
    public func perform() async throws -> some IntentResult
    {
        try await performIntentRefresh(identifier: "RefreshAllAppsWidgetIntent", mangledTypeName: "9SideStore26RefreshAllAppsWidgetIntentV", intentProgress: progress)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct RefreshAllAppsIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent, ProgressReportingIntent, ForegroundContinuableIntent
{
    public static let intentClassName = "RefreshAllIntent"
    
    public static var title: LocalizedStringResource = LocalizedStringResource("Refresh All Apps", defaultValue: "刷新所有应用")
    public static var description = IntentDescription(LocalizedStringResource("Refreshes your sideloaded apps to prevent them from expiring.", defaultValue: "刷新已侧载的应用以防止证书过期。"))
    
    public init() {}
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Refresh All Apps")
    }
    
    public static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction {
            DisplayRepresentation(
                title: LocalizedStringResource("Refresh All Apps", defaultValue: "刷新所有应用"),
                subtitle: ""
            )
        }
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog
    {
        try await performIntentRefresh(identifier: "RefreshAllIntent", mangledTypeName: "9SideStore20RefreshAllAppsIntentV", intentProgress: progress)
        return .result(dialog: IntentDialog(LocalizedStringResource("All apps have been refreshed.", defaultValue: "所有应用已成功刷新。")))
    }
}

@available(iOS 17.0, *)
public struct LiveContainerShortcutsProvider: AppShortcutsProvider
{
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshAllAppsIntent(),
            phrases: [
                "Refresh \(.applicationName)",
                "Refresh \(.applicationName) apps",
                "Refresh my \(.applicationName) apps",
                "Refresh apps with \(.applicationName)",
                "刷新 \(.applicationName)",
                "刷新 \(.applicationName) 应用",
                "刷新我的 \(.applicationName) 应用",
                "使用 \(.applicationName) 刷新应用",
            ],
            shortTitle: LocalizedStringResource("Refresh All Apps", defaultValue: "刷新所有应用"),
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
    
    public static var shortcutTileColor: ShortcutTileColor {
        return .teal
    }
}


class RefreshHandler: NSObject, RefreshServer {
    var c: UnsafeContinuation<(), any Error>? = nil
    var launchContinuation: UnsafeContinuation<(), any Error>? = nil
    var progress: Progress? = nil
    var listener: NSXPCListener? = nil
    var sideStorePid: Int32 = 0
    var client: RefreshClient? = nil
    var ext: NSExtension? = nil
    
    static var shared = RefreshHandler()
    
    func startRefresh(identifier: String, mangledName: String) async throws {
        if sideStorePid <= 0 || getpgid(sideStorePid) <= 0, let c {
            c.resume(throwing: NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Built-in SideStore quit unexpectedly"]))
            self.c = nil
        }
        
        if c != nil {
            throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Another refresh task is in progress."])
        }
        
        if listener == nil {
            guard let listener = startAnonymousListener(self) else {
                throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to start the built-in SideStore listener."])
            }
            self.listener = listener
        }
        guard let listener = self.listener else {
            throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "The built-in SideStore listener is unavailable."])
        }

        // launch SideStore if it's not running
        if (sideStorePid <= 0 || getpgid(sideStorePid) <= 0) && launchContinuation == nil {
            let lcHome = String(cString:getenv("LC_HOME_PATH"))
            let sideStoreHomeURL = URL(fileURLWithPath: lcHome).appendingPathComponent("Documents/SideStore")
            let bookmarkData = bookmarkForURL(sideStoreHomeURL)!

            // start LiveProcess
            let extensionItem = NSExtensionItem()
            extensionItem.userInfo = [
                "selected": "builtinSideStore",
                "bookmarks": [bookmarkData],
                "endpoint": listener.endpoint
            ]

            guard let liveProcessURL = UserDefaults.lcMainBundle().builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex"),
                  let liveProcessBundle = Bundle(url: liveProcessURL)
            else {
                NSLog("Unable to locate LiveProcess bundle")
                throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to locate LiveProcess bundle. To use the Refresh All Apps shortcut, reinstall LiveContainer+SideStore with LiveProcess installed. If you use SideStore, choose \"Keep App Extensions (Use Main Profile)\". If you use PlumeImpactor, choose \"Only Register Main Bundle\". For other sideloaders, select keep all extensions, i.e. DO NOT Remove any extension."])
            }
            
            var ext : NSExtension?
            do {
                ext = try NSExtension(identifier: liveProcessBundle.bundleIdentifier)
            } catch {
                NSLog("Failed to start extension \(error)")
                throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start extension \(error). To use the Refresh All Apps shortcut, reinstall LiveContainer+SideStore with LiveProcess installed. If you use SideStore, choose \"Keep App Extensions (Use Main Profile)\". If you use Impactor, choose \"Only Register Main Bundle\". For other sideloaders, select keep all extensions, i.e. DO NOT Remove any extension."])
            }
            guard let ext else {
                throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create the built-in SideStore extension."])
            }
            self.ext = ext
            
            ext.setRequestInterruptionBlock { uuid in
                let error = NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Built-in SideStore quit unexpectedly"])
                self.c?.resume(throwing: error)
                self.c = nil
                self.launchContinuation?.resume(throwing: error)
                self.launchContinuation = nil
                self.sideStorePid = 0
            }

            try await withUnsafeThrowingContinuation { c in
                self.launchContinuation = c
                Task {
                    let uuid = await ext.beginRequest(withInputItems: [extensionItem])
                    self.sideStorePid = ext.pid(forRequestIdentifier: uuid)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                    if let c = self.launchContinuation {
                        c.resume(throwing: NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Built-in SideStore failed to start in reasonable time"]))
                        self.launchContinuation = nil
                        ext._kill(9)
                    }
                }
            }
        }

        guard let client else {
            throw NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Built-in SideStore did not establish a refresh connection."])
        }

        try await withUnsafeThrowingContinuation { c in
            self.c = c
            client.refreshAllApps(withIdentifier: identifier, mangledTypeName: mangledName)
        }
        
    }
    
    func updateProgress(_ value: Double) {
        progress?.completedUnitCount = Int64(value*100)
    }
    
    func finish(_ error: String?) {
        if let error {
            c?.resume(throwing: NSError(domain: "SideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: error]))
            c = nil
        } else {
            c?.resume()
            c = nil
        }
    }
    
    func onConnection(_ connection: NSXPCConnection!) {
        connection.remoteObjectInterface = NSXPCInterface(with: RefreshClient.self)
        client = connection.remoteObjectProxy as? RefreshClient
    }
    
    func finishedLaunching() {
        launchContinuation?.resume()
        launchContinuation = nil
    }

    func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Failed to add SideStore notification: \(error)")
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
}
