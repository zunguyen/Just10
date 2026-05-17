import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Layout {
        static let panelSize = NSSize(width: 300, height: 460)
        static let panelScreenInset: CGFloat = 8
        static let panelTopGap: CGFloat = 8
    }

    private enum MenuBarIcon {
        static let size = NSSize(width: 18, height: 18)
        static let frameCount = 6
        static let frameDuration: TimeInterval = 0.045
    }

    private struct MenuBarState: Equatable {
        let title: String
        let toolTip: String?
    }

    private var statusItem: NSStatusItem!
    private var panel: TodoPanel!
    private var pendingMenuBarState: MenuBarState?
    private var menuBarIconTimer: Timer?
    private var menuBarIconFrameIndex = 0
    let store = TodoStore()
    let settings = AppSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupStatusItem()
        applyThemeAppearance()
        trackStoreChanges()
        trackSettingsChanges()
    }

    /// First-quit confirmation per Requirements §5.1.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !settings.hasShownQuitConfirmation else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit Just 10?"
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

    // MARK: - Status item & panel

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.imagePosition = .imageLeft
        button.image = makeMenuBarIcon(progress: 1)
        updateMenuBarTitle()
    }

    private func setupPanel() {
        panel = TodoPanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.onClose = { [weak self] in
            self?.panelDidClose()
        }
        let hostingController = NSHostingController(
            rootView: ContentView()
                .environment(store)
                .environment(settings)
        )
        hostingController.sizingOptions = []
        panel.contentViewController = hostingController
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

        if panel.isVisible {
            pendingMenuBarState = nextState
            return
        }

        applyMenuBarState(nextState)
    }

    private func makeMenuBarState() -> MenuBarState {
        guard let title = store.activeTodos.first?.title else {
            return MenuBarState(title: " All done", toolTip: nil)
        }

        let menuTitle = title.replacingOccurrences(of: "\n", with: " ")
        let truncated = menuTitle.count > 20 ? String(menuTitle.prefix(20)) + "…" : menuTitle
        return MenuBarState(title: " \(truncated)", toolTip: title)
    }

    private func applyMenuBarState(_ state: MenuBarState) {
        guard let button = statusItem.button else { return }
        let shouldAnimate = button.title != state.title && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        button.image = makeMenuBarIcon(progress: 1)
        button.title = state.title
        button.toolTip = state.toolTip

        if shouldAnimate {
            animateMenuBarIcon()
        } else {
            button.image = makeMenuBarIcon(progress: 1)
        }
    }

    private func animateMenuBarIcon() {
        menuBarIconTimer?.invalidate()
        menuBarIconFrameIndex = 0

        menuBarIconTimer = Timer.scheduledTimer(withTimeInterval: MenuBarIcon.frameDuration, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, let button = self.statusItem.button else {
                    timer.invalidate()
                    return
                }

                let progress = CGFloat(self.menuBarIconFrameIndex) / CGFloat(MenuBarIcon.frameCount - 1)
                button.image = self.makeMenuBarIcon(progress: progress)

                if self.menuBarIconFrameIndex >= MenuBarIcon.frameCount - 1 {
                    timer.invalidate()
                    self.menuBarIconTimer = nil
                } else {
                    self.menuBarIconFrameIndex += 1
                }
            }
        }
    }

    private func makeMenuBarIcon(progress: CGFloat) -> NSImage {
        let clampedProgress = min(max(progress, 0), 1)
        let image = NSImage(size: MenuBarIcon.size)
        image.lockFocus()

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let circleRect = NSRect(x: 2.5, y: 2.5, width: 13, height: 13)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        circlePath.lineWidth = 1.8
        circlePath.stroke()

        let checkPath = NSBezierPath()
        checkPath.lineWidth = 2
        checkPath.lineCapStyle = .round
        checkPath.lineJoinStyle = .round

        let start = NSPoint(x: 6, y: 8.6)
        let mid = NSPoint(x: 8, y: 6.4)
        let end = NSPoint(x: 12.2, y: 11.4)

        if clampedProgress <= 0.45 {
            let segmentProgress = clampedProgress / 0.45
            checkPath.move(to: start)
            checkPath.line(to: interpolate(from: start, to: mid, progress: segmentProgress))
        } else {
            let segmentProgress = (clampedProgress - 0.45) / 0.55
            checkPath.move(to: start)
            checkPath.line(to: mid)
            checkPath.line(to: interpolate(from: mid, to: end, progress: segmentProgress))
        }

        checkPath.stroke()
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Just 10"
        return image
    }

    private func interpolate(from start: NSPoint, to end: NSPoint, progress: CGFloat) -> NSPoint {
        NSPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
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
        panel.contentViewController?.view.appearance = appearance
        panel.appearance = appearance
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard
            let button = statusItem.button,
            let buttonWindow = button.window
        else { return }

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(
            max(buttonRect.maxX - Layout.panelSize.width, screenFrame.minX + Layout.panelScreenInset),
            screenFrame.maxX - Layout.panelSize.width - Layout.panelScreenInset
        )
        let y = max(
            buttonRect.minY - Layout.panelSize.height - Layout.panelTopGap,
            screenFrame.minY + Layout.panelScreenInset
        )

        panel.setFrame(NSRect(x: x, y: y, width: Layout.panelSize.width, height: Layout.panelSize.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        applyThemeAppearance()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePanel() {
        panel.orderOut(nil)
        panelDidClose()
    }

    private func panelDidClose() {
        guard let pendingMenuBarState else { return }
        applyMenuBarState(pendingMenuBarState)
        self.pendingMenuBarState = nil
    }
}

private final class TodoPanel: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
        onClose?()
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
        onClose?()
    }
}
