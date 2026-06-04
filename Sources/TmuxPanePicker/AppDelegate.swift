import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyController = GlobalHotKeyController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let fallbackButtonController = MenuBarFallbackButtonController()
    private var statusBadgeView: MenuBarStatusBadgeView?
    private var statusItemUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        hotKeyController.register()
        PanePickerWindowCoordinator.shared.viewModel.startAutoRefresh()
        statusItemUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
                self?.updateFallbackButtonVisibility()
            }
        }

        DispatchQueue.main.async {
            PanePickerWindowCoordinator.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemUpdateTimer?.invalidate()
        hotKeyController.unregister()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanePickerWindowCoordinator.shared.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem.autosaveName = nil
        statusItem.behavior = []
        statusItem.isVisible = true

        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        updateStatusItem()
        updateFallbackButtonVisibility()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let viewModel = PanePickerWindowCoordinator.shared.viewModel
        let badge = viewModel.menuBarTitle.isEmpty ? nil : viewModel.menuBarTitle
        button.image = makeStatusImage()
        button.title = ""
        statusItem.length = NSStatusItem.squareLength
        statusItem.isVisible = true
        updateStatusBadge(badge, on: button)
        fallbackButtonController.updateBadge(badge)
    }

    private func makeStatusImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 20))
        image.lockFocus()

        let iconRect = NSRect(x: 2.5, y: 3, width: 16, height: 14)
        let outline = NSBezierPath(roundedRect: iconRect, xRadius: 3.5, yRadius: 3.5)
        NSColor.labelColor.withAlphaComponent(0.92).setStroke()
        outline.lineWidth = 1.7
        outline.stroke()

        NSColor.labelColor.withAlphaComponent(0.82).setStroke()
        let verticalDivider = NSBezierPath()
        verticalDivider.lineWidth = 1.4
        verticalDivider.move(to: NSPoint(x: iconRect.minX + 6.2, y: iconRect.minY + 1.8))
        verticalDivider.line(to: NSPoint(x: iconRect.minX + 6.2, y: iconRect.maxY - 1.8))
        verticalDivider.stroke()

        let horizontalDivider = NSBezierPath()
        horizontalDivider.lineWidth = 1.4
        horizontalDivider.move(to: NSPoint(x: iconRect.minX + 7.4, y: iconRect.midY))
        horizontalDivider.line(to: NSPoint(x: iconRect.maxX - 1.8, y: iconRect.midY))
        horizontalDivider.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func updateStatusBadge(_ badge: String?, on button: NSStatusBarButton) {
        guard let badge else {
            statusBadgeView?.removeFromSuperview()
            statusBadgeView = nil
            return
        }

        let badgeView = statusBadgeView ?? MenuBarStatusBadgeView()
        badgeView.badge = badge
        let width: CGFloat = badge.count > 1 ? 14 : 9
        badgeView.frame = NSRect(
            x: button.bounds.maxX - width - 1,
            y: button.bounds.maxY - 11,
            width: width,
            height: 9
        )

        if badgeView.superview == nil {
            button.addSubview(badgeView)
        }
        statusBadgeView = badgeView
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            PanePickerWindowCoordinator.shared.toggleAnchored(to: sender)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open Floating Pane Picker",
            action: #selector(openFloatingPanePicker),
            keyEquivalent: "p"
        ))
        menu.addItem(NSMenuItem(
            title: "Refresh Panes",
            action: #selector(refreshPanes),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openFloatingPanePicker() {
        PanePickerWindowCoordinator.shared.show()
    }

    @objc private func refreshPanes() {
        PanePickerWindowCoordinator.shared.viewModel.refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateFallbackButtonVisibility() {
        fallbackButtonController.show()
    }
}

@MainActor
private final class MenuBarStatusBadgeView: NSView {
    var badge = "" {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: badge.count > 1 ? 6.5 : 7.5, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        badge.draw(in: bounds.offsetBy(dx: 0, dy: badge.count > 1 ? 1.3 : 0.8), withAttributes: attributes)
    }
}

@MainActor
private final class MenuBarFallbackButtonController: NSObject {
    private var window: NSWindow?
    private let buttonView = MenuBarFallbackButtonView()

    override init() {
        super.init()
        buttonView.frame = NSRect(x: 0, y: 0, width: 28, height: 24)
        buttonView.onClick = { [weak self] in
            self?.clicked()
        }
    }

    func updateBadge(_ badge: String?) {
        buttonView.badge = badge
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        position(window)
        buttonView.needsDisplay = true
        buttonView.displayIfNeeded()
        window.display()
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 28, height: 24),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = buttonView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .systemBlue
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        return window
    }

    private func position(_ window: NSWindow) {
        guard let screen = NSScreen.screens.max(by: { $0.visibleFrame.maxY < $1.visibleFrame.maxY }) else {
            return
        }

        let frame = screen.frame
        let origin = NSPoint(x: frame.maxX - window.frame.width - 14, y: frame.maxY - window.frame.height - 7)
        window.setFrameOrigin(origin)
    }

    @objc private func clicked() {
        PanePickerWindowCoordinator.shared.showNearMenuBarFallback()
    }
}

@MainActor
private final class MenuBarFallbackButtonView: NSView {
    var badge: String? {
        didSet {
            needsDisplay = true
        }
    }
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        let backgroundRect = bounds.insetBy(dx: 1, dy: 1)
        NSColor(calibratedRed: 0.16, green: 0.49, blue: 0.98, alpha: 1).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 6, yRadius: 6).fill()

        let iconRect = NSRect(x: 7, y: 6, width: 14, height: 12)
        let outline = NSBezierPath(roundedRect: iconRect, xRadius: 3, yRadius: 3)
        NSColor.white.withAlphaComponent(0.94).setStroke()
        outline.lineWidth = 1.5
        outline.stroke()

        NSColor.white.withAlphaComponent(0.82).setStroke()
        let verticalDivider = NSBezierPath()
        verticalDivider.lineWidth = 1.2
        verticalDivider.move(to: NSPoint(x: iconRect.minX + 5.2, y: iconRect.minY + 1.4))
        verticalDivider.line(to: NSPoint(x: iconRect.minX + 5.2, y: iconRect.maxY - 1.4))
        verticalDivider.stroke()

        let horizontalDivider = NSBezierPath()
        horizontalDivider.lineWidth = 1.2
        horizontalDivider.move(to: NSPoint(x: iconRect.minX + 6.2, y: iconRect.midY))
        horizontalDivider.line(to: NSPoint(x: iconRect.maxX - 1.4, y: iconRect.midY))
        horizontalDivider.stroke()

        guard let badge else {
            return
        }

        let badgeRect = badge.count > 1
            ? NSRect(x: bounds.maxX - 16, y: bounds.maxY - 12, width: 14, height: 9)
            : NSRect(x: bounds.maxX - 12, y: bounds.maxY - 12, width: 9, height: 9)

        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height / 2, yRadius: badgeRect.height / 2).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: badge.count > 1 ? 6.5 : 7.5, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        badge.draw(in: badgeRect.offsetBy(dx: 0, dy: badge.count > 1 ? 1.3 : 0.8), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
