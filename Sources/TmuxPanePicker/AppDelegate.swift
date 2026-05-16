import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyController = GlobalHotKeyController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var statusItemUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        hotKeyController.register()
        PanePickerWindowCoordinator.shared.viewModel.startAutoRefresh()
        statusItemUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
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
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let viewModel = PanePickerWindowCoordinator.shared.viewModel
        button.image = NSImage(systemSymbolName: viewModel.menuBarSystemImage, accessibilityDescription: "tmux pane picker")
        button.title = viewModel.menuBarTitle
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
}
