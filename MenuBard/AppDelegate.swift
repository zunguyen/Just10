import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var isReorderingFromPopover = false
    private var frozenStatusItemLength: CGFloat?
    let store = TodoStore()
    let settings = AppSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupObservers()
        applyThemeAppearance()
        trackStoreChanges()
        trackSettingsChanges()
    }

    /// First-quit confirmation per Requirements §5.1.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !settings.hasShownQuitConfirmation else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit MenuBard?"
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
        updateMenuBarTitle()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environment(store)
                .environment(settings)
        )
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTodoDragDidStart),
            name: .todoDragDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTodoDragDidEnd),
            name: .todoDragDidEnd,
            object: nil
        )
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
        let topTodoTitle = store.activeTodos.first?.title
        guard let button = statusItem.button else { return }
        let icon = NSImage(systemSymbolName: "checklist", accessibilityDescription: "MenuBard")
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeft

        guard !isReorderingFromPopover else { return }

        if let title = topTodoTitle {
            let truncated = title.count > 28 ? String(title.prefix(28)) + "…" : title
            button.title = " \(truncated)"
            button.toolTip = title
        } else {
            button.title = " All done"
            button.toolTip = nil
        }
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
        freezeStatusItemWidthIfNeeded(using: button)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        applyThemeAppearance()
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleTodoDragDidStart() {
        isReorderingFromPopover = true
    }

    @objc private func handleTodoDragDidEnd() {
        isReorderingFromPopover = false
        updateMenuBarTitle()
    }

    func popoverDidClose(_ notification: Notification) {
        restoreStatusItemWidth()
    }

    private func freezeStatusItemWidthIfNeeded(using button: NSStatusBarButton) {
        guard frozenStatusItemLength == nil else { return }

        let measuredWidth = max(button.frame.width, button.intrinsicContentSize.width)
        frozenStatusItemLength = measuredWidth
        statusItem.length = measuredWidth
    }

    private func restoreStatusItemWidth() {
        guard frozenStatusItemLength != nil else { return }
        frozenStatusItemLength = nil
        statusItem.length = NSStatusItem.variableLength
        updateMenuBarTitle()
    }
}

extension Notification.Name {
    static let todoDragDidStart = Notification.Name("menubard.todoDragDidStart")
    static let todoDragDidEnd = Notification.Name("menubard.todoDragDidEnd")
}
