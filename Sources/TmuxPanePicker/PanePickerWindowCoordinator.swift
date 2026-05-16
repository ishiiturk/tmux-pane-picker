import AppKit
import SwiftUI

@MainActor
final class PanePickerWindowCoordinator {
    static let shared = PanePickerWindowCoordinator()

    let viewModel = PanePickerViewModel()
    private var window: NSWindow?

    private init() {}

    func show() {
        let window = window ?? makeWindow()
        self.window = window

        viewModel.prepareForPresentation()
        viewModel.startAutoRefresh()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func showAnchored(to statusButton: NSStatusBarButton) {
        let window = window ?? makeWindow()
        self.window = window

        viewModel.prepareForPresentation()
        viewModel.startAutoRefresh()
        NSApp.activate(ignoringOtherApps: true)
        window.setFrameOrigin(anchorOrigin(for: statusButton, window: window))
        window.makeKeyAndOrderFront(nil)
    }

    func refocusWindow() {
        guard let window else {
            return
        }

        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func refocusWindowAfterITermActivation() {
        Task { @MainActor in
            refocusWindow()
            try? await Task.sleep(for: .milliseconds(350))
            refocusWindow()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func anchorOrigin(for statusButton: NSStatusBarButton, window: NSWindow) -> NSPoint {
        guard let buttonWindow = statusButton.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return NSPoint(x: 0, y: 0)
        }

        let buttonFrameInScreen = buttonWindow.convertToScreen(statusButton.convert(statusButton.bounds, to: nil))
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = min(
            max(buttonFrameInScreen.midX - windowFrame.width / 2, screenFrame.minX + 8),
            screenFrame.maxX - windowFrame.width - 8
        )
        let y = buttonFrameInScreen.minY - windowFrame.height - 6

        return NSPoint(x: x, y: max(y, screenFrame.minY + 8))
    }

    private func makeWindow() -> NSWindow {
        let contentView = PanePickerView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "tmux pane picker"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 500, height: 320))
        window.minSize = NSSize(width: 420, height: 260)

        return window
    }
}
