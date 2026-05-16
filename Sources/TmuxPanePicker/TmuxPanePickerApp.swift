import SwiftUI

@main
struct TmuxPanePickerApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = PanePickerViewModel()

    var body: some Scene {
        MenuBarExtra("tmux panes", systemImage: "rectangle.split.3x1") {
            Button("Open Pane Picker") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "pane-picker")
            }
            .keyboardShortcut("p")

            Button("Refresh Panes") {
                viewModel.refresh()
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Window("tmux pane picker", id: "pane-picker") {
            PanePickerView(viewModel: viewModel)
                .background(FloatingWindowConfigurator())
        }
        .windowResizability(.contentSize)
    }
}
