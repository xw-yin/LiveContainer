//
//  AutomaticRefreshBridge.swift
//  SideStoreSupport
//
//  Forwards BGProcessingTask firings for the built-in SideStore's
//  automatic refresh to the built-in SideStore running in LiveProcess.
//

import BackgroundTasks
import Foundation

/// iOS wakes the host app (LiveContainer) when a BGProcessingTask fires,
/// never a guest app, so the handler for the built-in SideStore's
/// automatic-refresh task has to live in the host and be registered during
/// the host's launch, before `didFinishLaunching` returns. When the task
/// fires, the bridge starts the built-in SideStore in LiveProcess (the
/// same machinery the Refresh All Apps shortcut uses) and asks it to run
/// one automatic refresh cycle, then reports the outcome back to the
/// system task.
///
/// The identifier must stay in sync with:
/// - `AutomaticRefreshManager.taskIdentifier` in SideStore, and
/// - `BGTaskSchedulerPermittedIdentifiers` in the host app's Info.plist.
public enum SideStoreAutomaticRefreshBridge {
    public static let taskIdentifier = "com.SideStore.SideStore.automatic-refresh"

    public static func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            let completer = BGTaskCompleter(task: processingTask)
            processingTask.expirationHandler = {
                completer.complete(success: false)
            }

            Task {
                do {
                    try await RefreshHandler.shared.startAutomaticRefresh()
                    completer.complete(success: true)
                } catch {
                    completer.complete(success: false)
                }
            }
        }
    }
}

/// Guarantees `setTaskCompleted` is called exactly once, whether the
/// forwarded refresh finishes first or the system expires the task first.
/// If the task expires first, the guest-side refresh is left to wind down
/// on its own; its late finish report is simply dropped.
private final class BGTaskCompleter: @unchecked Sendable {
    private let task: BGProcessingTask
    private let lock = NSLock()
    private var completed = false

    init(task: BGProcessingTask) {
        self.task = task
    }

    func complete(success: Bool) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        task.setTaskCompleted(success: success)
    }
}
