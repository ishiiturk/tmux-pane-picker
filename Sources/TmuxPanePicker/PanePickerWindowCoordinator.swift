import AppKit
import SwiftUI

@MainActor
final class PanePickerWindowCoordinator {
    static let shared = PanePickerWindowCoordinator()

    private let viewModel = PanePickerViewModel()
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

    func hide() {
        viewModel.stopAutoRefresh()
        window?.orderOut(nil)
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
