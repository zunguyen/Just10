import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private struct MenuBarState: Equatable {
        let title: String
        let toolTip: String?
    }

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var pendingMenuBarState: MenuBarState?
    let store = TodoStore()
    let settings = AppSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPopover()
        setupStatusItem()
        applyThemeAppearance()
        trackStoreChanges()
        trackSettingsChanges()
    }

    /// First-quit confirmation per Requirements §5.1.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !settings.hasShownQuitConfirmation else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit Jet10?"
        alert.informativeText = "Your todos are saved. You can reopen anytime from Applications."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let suppress = NSButton(checkboxWithTitle: "Don't ask again", target: nil, action: nil)
        suppress.state = .on
        alert.accessoryView = suppress

        // Bring the alert above the status menu/popover.
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if suppress.state == .on { settings.hasShownQuitConfirmation = true }
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }

    // MARK: - Status item & popover

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.imagePosition = .imageLeft
        updateMenuBarTitle()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let hostingController = NSHostingController(
            rootView: ContentView()
                .environment(store)
                .environment(settings)
        )
        // Prevent SwiftUI layout changes from resizing/repositioning the popover.
        hostingController.sizingOptions = []
        popover.contentViewController = hostingController
    }

    private func trackStoreChanges() {
        withObservationTracking {
            updateMenuBarTitle()
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.trackStoreChanges() }
        }
    }

    private func trackSettingsChanges() {
        withObservationTracking {
            _ = settings.theme
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.applyThemeAppearance()
                self?.trackSettingsChanges()
            }
        }
    }

    private func updateMenuBarTitle() {
        let nextState = makeMenuBarState()

        if popover.isShown {
            pendingMenuBarState = nextState
            return
        }

        applyMenuBarState(nextState)
    }

    private func makeMenuBarState() -> MenuBarState {
        guard let title = store.activeTodos.first?.title else {
            return MenuBarState(title: " All done", toolTip: nil)
        }

        let truncated = title.count > 20 ? String(title.prefix(20)) + "…" : title
        return MenuBarState(title: " \(truncated)", toolTip: title)
    }

    private func applyMenuBarState(_ state: MenuBarState) {
        guard let button = statusItem.button else { return }
        let icon = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Jet10")
        icon?.isTemplate = true
        button.image = icon
        button.title = state.title
        button.toolTip = state.toolTip
    }

    private func applyThemeAppearance() {
        let appearance: NSAppearance?
        switch settings.theme {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = appearance
        popover.contentViewController?.view.appearance = appearance
        popover.contentViewController?.view.window?.appearance = appearance
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        let rightEdge = NSRect(
            x: button.bounds.width - 1,
            y: 0,
            width: 1,
            height: button.bounds.height
        )
        popover.show(relativeTo: rightEdge, of: button, preferredEdge: .minY)
        applyThemeAppearance()
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        guard let pendingMenuBarState else { return }
        applyMenuBarState(pendingMenuBarState)
        self.pendingMenuBarState = nil
    }
}
