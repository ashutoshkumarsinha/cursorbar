import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore!
    private var statusBarController: StatusBarController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UITestSupport.applyLaunchArgumentsIfNeeded()
        store = UsageStore()
        statusBarController = StatusBarController(store: store)

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusBarController.updateStatusItemView()
            }
            .store(in: &cancellables)

        statusBarController.showOnboardingIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
