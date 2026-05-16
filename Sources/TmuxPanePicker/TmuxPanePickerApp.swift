import SwiftUI

@main
struct TmuxPanePickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("tmux panes", systemImage: "rectangle.split.3x1") {
            Button("Open Pane Picker") {
                PanePickerWindowCoordinator.shared.show()
            }
            .keyboardShortcut("p")

            Button("Refresh Panes") {
                PanePickerWindowCoordinator.shared.show()
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
