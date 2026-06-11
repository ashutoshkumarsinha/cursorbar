import AppKit
import Foundation

/// Pauses API polling while the Mac is asleep to avoid wasted network activity.
final class SleepMonitor {
    static let shared = SleepMonitor()

    private(set) var isAsleep = false

    private var observers: [NSObjectProtocol] = []
    private var sleepHandlers: [() -> Void] = []
    private var wakeHandlers: [() -> Void] = []

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter

        observers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isAsleep = true
                self?.sleepHandlers.forEach { $0() }
            }
        )

        observers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isAsleep = false
                self?.wakeHandlers.forEach { $0() }
            }
        )
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    func onSleep(_ handler: @escaping () -> Void) {
        sleepHandlers.append(handler)
    }

    func onWake(_ handler: @escaping () -> Void) {
        wakeHandlers.append(handler)
    }
}
