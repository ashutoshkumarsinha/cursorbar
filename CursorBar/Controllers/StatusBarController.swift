import AppKit
import SwiftUI

/// AppKit anchor: NSStatusItem + NSPopover hosting SwiftUI content.
final class StatusBarController: NSObject {
    private let store: UsageStore
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(store: UsageStore) {
        self.store = store
        super.init()
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self

        updateStatusItemView()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true

        let content = PopoverContentView(
            store: store,
            onPreferences: { [weak self] in
                self?.popover.performClose(nil)
                self?.showPreferences()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: content)
    }

    func updateStatusItemView() {
        guard let button = statusItem?.button else { return }

        let label = MenuBarLabelView(store: store)
        button.subviews.forEach { $0.removeFromSuperview() }

        let hostingView = NSHostingView(rootView: label)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func showPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesView(store: store)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "CursorBar Preferences"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 380))
            window.center()
            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboardingIfNeeded() {
        guard !KeychainService.shared.hasToken else { return }

        var isPresented = true
        let view = AuthenticationView(store: store, isPresented: Binding(
            get: { isPresented },
            set: { [weak self] newValue in
                isPresented = newValue
                if !newValue {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                }
            }
        ))

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to CursorBar"
        window.styleMask = [.titled, .closable]
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
