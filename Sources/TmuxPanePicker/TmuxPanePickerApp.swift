import SwiftUI

@main
struct TmuxPanePickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = PanePickerWindowCoordinator.shared.viewModel

    var body: some Scene {
        MenuBarExtra {
            Button("Open Pane Picker") {
                PanePickerWindowCoordinator.shared.show()
            }
            .keyboardShortcut("p", modifiers: [.control, .option])

            Button("Refresh Panes") {
                PanePickerWindowCoordinator.shared.show()
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Label(viewModel.menuBarTitle, systemImage: viewModel.menuBarSystemImage)
                .labelStyle(.titleAndIcon)
        }
    }
}
