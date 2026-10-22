import Foundation

// Compile the production validators with small fixtures; no Apple account,
// signing certificate, device, or UIKit is needed for these failure cases.
struct MemoryKey { let rawValue: String }
final class InstallAppOperationContext {
    var requiresHostMemoryEntitlements = true
    var requiresAppMemoryEntitlements = false
    var expectedMemoryBundleIdentifier: String?
    var requiresMemoryEntitlements: Bool { requiresHostMemoryEntitlements || requiresAppMemoryEntitlements }
    // MEMORY_SCOPE_SOURCE
    static let memoryEntitlements = [
        MemoryKey(rawValue: "com.apple.developer.kernel.increased-memory-limit"),
        MemoryKey(rawValue: "com.apple.developer.kernel.extended-virtual-addressing")
    ]
}
struct ALTProvisioningProfile { var entitlements: [String: Any] }
struct ALTApplication {
    let name: String
    let fileURL: URL
    var isExtension: Bool { fileURL.pathExtension == "appex" }
    var bundleIdentifier: String { name }
    var entitlements: [String: Any] = [:]
    var appExtensions: [ALTApplication] = []
}
enum OperationError: Error { case invalidParameters(String) }
enum SignerError: Error { case invalidApp(cause: String) }

final class ProfileValidator {
    let context = InstallAppOperationContext()
    func debugLog(_ message: String) {}
    func check(_ profile: ALTProvisioningProfile, _ app: ALTApplication) throws {
        try validateMemoryProfile(profile, for: app)
    }
    // PROFILE_VALIDATOR_SOURCE
}

final class SignatureValidator {
    let context = InstallAppOperationContext()
    func debugLog(_ message: String) {}
    func check(_ app: ALTApplication) throws { try validateMemorySignatures(in: app) }
    // SIGNATURE_VALIDATOR_SOURCE
}

extension UserDefaults {
    // APP_MEMORY_PREFERENCES_SOURCE
}

func restoreMemoryKeys(profile: ALTProvisioningProfile, app: ALTApplication,
                       injectedEntitlements: [String: Any]) throws -> [String: Any] {
    let matchedProfile = profile
    var filteredEntitlements: [String: Any] = [:]
    // SIGNER_VALIDATOR_SOURCE
    return filteredEntitlements
}

func processMemoryKeys(for ext: ALTApplication, injectedEntitlements: [String: Any], includeLiveProcessMemory: Bool = false) -> [String: Any] {
    // PROCESS_MEMORY_SOURCE
    return processMemory
}

@main struct HostMemoryProfileTests {
    static func main() throws {
        let keys = InstallAppOperationContext.memoryEntitlements.map(\.rawValue)
        let granted = Dictionary(uniqueKeysWithValues: keys.map { ($0, true as Any) })
        let profile = ALTProvisioningProfile(entitlements: granted)
        let main = ALTApplication(name: "LiveContainer", fileURL: URL(fileURLWithPath: "/Host.app"))
        let process = ALTApplication(name: "LiveProcess", fileURL: URL(fileURLWithPath: "/Host.app/PlugIns/LiveProcess.appex"))
        let widget = ALTApplication(name: "Widget", fileURL: URL(fileURLWithPath: "/Host.app/PlugIns/Widget.appex"))
        let validator = ProfileValidator()
        var checks = 0
        func expectFailure(_ operation: () throws -> Void) {
            do {
                try operation()
                fatalError("Expected permission validation to stop the operation")
            } catch { checks += 1 }
        }
        for app in [main, process] {
            try validator.check(profile, app)
            checks += 1
            expectFailure { try validator.check(ALTProvisioningProfile(entitlements: [:]), app) }
            for key in keys {
                for invalid in [false as Any, "true" as Any] {
                    var entitlements = granted
                    entitlements[key] = invalid
                    expectFailure { try validator.check(ALTProvisioningProfile(entitlements: entitlements), app) }
                }
            }
            // The old binary may have lost its memory keys. Restore them only
            // after verifying the Apple-signed profile grants each one.
            let restored = try restoreMemoryKeys(profile: profile, app: app, injectedEntitlements: granted)
            precondition(keys.allSatisfy { (restored[$0] as? Bool) == true })
            checks += 1
            expectFailure {
                _ = try restoreMemoryKeys(profile: ALTProvisioningProfile(entitlements: [:]), app: app, injectedEntitlements: granted)
            }
            var rejected = granted
            rejected[keys[0]] = false
            expectFailure {
                _ = try restoreMemoryKeys(profile: ALTProvisioningProfile(entitlements: rejected), app: app, injectedEntitlements: granted)
            }
        }
        try validator.check(ALTProvisioningProfile(entitlements: [:]), widget)
        checks += 1
        validator.context.requiresHostMemoryEntitlements = false
        try validator.check(ALTProvisioningProfile(entitlements: [:]), main)
        checks += 1
        precondition(processMemoryKeys(for: process, injectedEntitlements: granted, includeLiveProcessMemory: true).count == keys.count)
        precondition(processMemoryKeys(for: process, injectedEntitlements: granted).isEmpty)
        precondition(processMemoryKeys(for: widget, injectedEntitlements: granted).isEmpty)
        let unrelated: [String: Any] = ["get-task-allow": true]
        precondition(processMemoryKeys(for: process, injectedEntitlements: unrelated).isEmpty)
        checks += 4

        // Standalone opt-ins require the main app only, even if an unrelated
        // extension happens to be named LiveProcess.appex.
        validator.context.requiresAppMemoryEntitlements = true
        try validator.check(profile, main)
        expectFailure { try validator.check(ALTProvisioningProfile(entitlements: [:]), main) }
        try validator.check(ALTProvisioningProfile(entitlements: [:]), process)
        try validator.check(ALTProvisioningProfile(entitlements: [:]), widget)
        checks += 3

        let signatureValidator = SignatureValidator()
        var signedMain = main
        var signedProcess = process
        signedMain.entitlements = granted
        signedProcess.entitlements = granted
        signedMain.appExtensions = [signedProcess, widget]
        signatureValidator.context.expectedMemoryBundleIdentifier = main.bundleIdentifier
        try signatureValidator.check(signedMain)
        checks += 1
        var noProcess = signedMain
        noProcess.appExtensions = []
        expectFailure { try signatureValidator.check(noProcess) }
        for key in keys {
            var missingMain = signedMain
            missingMain.entitlements.removeValue(forKey: key)
            expectFailure { try signatureValidator.check(missingMain) }
            var missingProcess = signedProcess
            missingProcess.entitlements[key] = false
            var incompleteHost = signedMain
            incompleteHost.appExtensions = [missingProcess]
            expectFailure { try signatureValidator.check(incompleteHost) }
        }
        signatureValidator.context.requiresHostMemoryEntitlements = false
        signatureValidator.context.requiresAppMemoryEntitlements = true
        try signatureValidator.check(noProcess)
        var standaloneWithExtensions = signedMain
        standaloneWithExtensions.appExtensions = [process, widget]
        try signatureValidator.check(standaloneWithExtensions)
        checks += 2
        var missingStandalone = noProcess
        missingStandalone.entitlements = [:]
        expectFailure { try signatureValidator.check(missingStandalone) }
        signatureValidator.context.expectedMemoryBundleIdentifier = "AnotherInstalledApp"
        expectFailure { try signatureValidator.check(noProcess) }

        // These are real production preference methods, run in an isolated suite.
        let suite = "HostMemoryTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set(["app.a"], forKey: "moreRAMEnabledBundleIdentifiers")
        precondition(!preferences.isMemoryPermissionRequested(for: "app.a"))
        preferences.set(true, forKey: "liveContainerHostMemoryRequested")
        preferences.setMemoryPermissionRequested(true, for: "app.a")
        precondition(preferences.isMemoryPermissionRequested(for: "app.a"))
        precondition(!preferences.isMemoryPermissionRequested(for: "app.b"))
        preferences.setMemoryPermissionRequested(true, for: "app.b")
        preferences.setMemoryPermissionRequested(true, for: "app.a")
        precondition((preferences.array(forKey: "memoryPermissionRequestedBundleIdentifiers") as? [String])?.count == 2)
        preferences.setMemoryPermissionRequested(false, for: "app.a")
        precondition(!preferences.isMemoryPermissionRequested(for: "app.a"))
        precondition(preferences.isMemoryPermissionRequested(for: "app.b"))
        precondition(preferences.bool(forKey: "liveContainerHostMemoryRequested"))
        checks += 7
        print("Host and standalone app memory permission tests passed (\(checks) checks).")
    }
}
