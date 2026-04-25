import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hoverTooltipPopover: NSPopover!
    private var statusItemHoverController: StatusItemHoverController?
    private var isReorderingFromPopover = false
    private var frozenStatusItemLength: CGFloat?
    private var menuBarHoverTitle: String?
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
        setupHoverTooltip(for: button)
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

    private func setupHoverTooltip(for button: NSStatusBarButton) {
        hoverTooltipPopover = NSPopover()
        hoverTooltipPopover.behavior = .transient
        hoverTooltipPopover.animates = false

        statusItemHoverController = StatusItemHoverController(
            button: button,
            tooltipProvider: { [weak self] in self?.menuBarHoverTitle },
            onShow: { [weak self] in self?.showHoverTooltip() },
            onHide: { [weak self] in self?.hideHoverTooltip() }
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
            menuBarHoverTitle = title.count > 28 ? title : nil
        } else {
            button.title = " All done"
            menuBarHoverTitle = nil
        }

        button.toolTip = nil
        refreshHoverTooltipIfNeeded()
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
        hoverTooltipPopover.contentViewController?.view.appearance = appearance
        hoverTooltipPopover.contentViewController?.view.window?.appearance = appearance
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        hideHoverTooltip()
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

    private func showHoverTooltip() {
        guard
            !popover.isShown,
            let button = statusItem.button,
            let title = menuBarHoverTitle,
            !title.isEmpty
        else { return }

        let hostingController = NSHostingController(
            rootView: MenuBarHoverTooltipView(title: title)
        )
        let fittingSize = hostingController.view.fittingSize
        hoverTooltipPopover.contentSize = NSSize(
            width: min(max(fittingSize.width, 180), 320),
            height: fittingSize.height
        )
        hoverTooltipPopover.contentViewController = hostingController

        if !hoverTooltipPopover.isShown {
            hoverTooltipPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        applyThemeAppearance()
    }

    private func hideHoverTooltip() {
        statusItemHoverController?.cancelPendingShow()
        hoverTooltipPopover?.performClose(nil)
    }

    private func refreshHoverTooltipIfNeeded() {
        guard hoverTooltipPopover?.isShown == true else { return }
        if menuBarHoverTitle == nil {
            hideHoverTooltip()
        } else {
            showHoverTooltip()
        }
    }
}

extension Notification.Name {
    static let todoDragDidStart = Notification.Name("menubard.todoDragDidStart")
    static let todoDragDidEnd = Notification.Name("menubard.todoDragDidEnd")
}

private final class StatusItemHoverController: NSObject {
    private weak var button: NSStatusBarButton?
    private var trackingArea: NSTrackingArea?
    private let tooltipProvider: () -> String?
    private let onShow: () -> Void
    private let onHide: () -> Void
    private let showDelay: TimeInterval = 0.18
    private var pendingShowWorkItem: DispatchWorkItem?

    init(
        button: NSStatusBarButton,
        tooltipProvider: @escaping () -> String?,
        onShow: @escaping () -> Void,
        onHide: @escaping () -> Void
    ) {
        self.button = button
        self.tooltipProvider = tooltipProvider
        self.onShow = onShow
        self.onHide = onHide
        super.init()
        installTrackingArea()
    }

    func cancelPendingShow() {
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil
    }

    @objc func mouseEntered(with event: NSEvent) {
        guard tooltipProvider() != nil else { return }
        cancelPendingShow()

        let workItem = DispatchWorkItem { [weak self] in
            self?.onShow()
        }
        pendingShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: workItem)
    }

    @objc func mouseExited(with event: NSEvent) {
        cancelPendingShow()
        onHide()
    }

    private func installTrackingArea() {
        guard let button else { return }

        if let trackingArea {
            button.removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
}

private struct MenuBarHoverTooltipView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Typography.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(6)
    }
}
