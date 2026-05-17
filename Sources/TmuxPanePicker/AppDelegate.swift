import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyController = GlobalHotKeyController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let fallbackButtonController = MenuBarFallbackButtonController()
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
        let label = viewModel.menuBarTitle.isEmpty ? "T" : viewModel.menuBarTitle
        button.image = makeStatusImage(label)
        button.title = ""
        statusItem.length = NSStatusItem.squareLength
        statusItem.isVisible = true
        fallbackButtonController.updateLabel(label)
    }

    private func makeStatusImage(_ label: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.black.setFill()
        let path = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16), xRadius: 4, yRadius: 4)
        path.fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: label.count > 1 ? 9 : 12, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let textRect = NSRect(x: 1, y: label.count > 1 ? 4 : 2.5, width: 16, height: 14)
        label.draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            PanePickerWindowCoordinator.shared.showAnchored(to: sender)
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

    func updateLabel(_ label: String) {
        buttonView.label = label
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
    var label = "T" {
        didSet {
            needsDisplay = true
        }
    }
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: label.count > 1 ? 10 : 13, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let textRect = NSRect(x: 1, y: label.count > 1 ? 5 : 3, width: bounds.width - 2, height: bounds.height - 4)
        label.draw(in: textRect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
