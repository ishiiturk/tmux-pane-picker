import SwiftUI

struct PanePickerView: View {
    @Bindable var viewModel: PanePickerViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.filteredPanes.isEmpty {
                emptyView
            } else {
                paneList
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 420, idealHeight: 520)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var searchField: some View {
        TextField("Search panes", text: $viewModel.query)
            .textFieldStyle(.plain)
            .font(.system(size: 20, weight: .medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(nsColor: .textBackgroundColor))
            .onSubmit {
                viewModel.focusSelectedPane()
            }
    }

    private var paneList: some View {
        List(selection: $viewModel.selectedPaneID) {
            ForEach(viewModel.filteredPanes) { pane in
                PaneRow(pane: pane)
                    .tag(pane.id)
            }
        }
        .listStyle(.inset)
        .onSubmit {
            viewModel.focusSelectedPane()
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No panes",
            systemImage: "rectangle.split.3x1",
            description: Text("No tmux panes matched the current search.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "tmux unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PaneRow: View {
    let pane: TmuxPane

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(pane.sessionName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(pane.displayWindow)
                        .foregroundStyle(.secondary)
                    Text(pane.paneID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Text(pane.currentPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

            Text(pane.currentCommand)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }
}
