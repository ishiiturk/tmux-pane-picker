import SwiftUI

@main
struct TmuxPanePickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = PanePickerWindowCoordinator.shared.viewModel

    var body: some Scene {
        MenuBarExtra {
            PanePickerView(
                viewModel: viewModel,
                onDismiss: {}
            )
        } label: {
            Label(menuBarLabel, systemImage: viewModel.menuBarSystemImage)
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }

    private var menuBarLabel: String {
        viewModel.menuBarTitle.isEmpty ? "T" : "T \(viewModel.menuBarTitle)"
    }
}
