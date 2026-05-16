import SwiftUI

struct PanePickerView: View {
    @Bindable var viewModel: PanePickerViewModel
    let onDismiss: () -> Void
    @FocusState private var isSearchFocused: Bool

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
            focusSearchField()
        }
        .onChange(of: viewModel.query) {
            viewModel.selectFirstFilteredPaneIfNeeded()
        }
        .onSubmit {
            focusSelectedPane()
        }
        .onKeyPress(.return) {
            focusSelectedPane()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onExitCommand {
            onDismiss()
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                viewModel.selectNextPane()
            case .up:
                viewModel.selectPreviousPane()
            default:
                break
            }
        }
    }

    private var searchField: some View {
        TextField("Search panes", text: $viewModel.query)
            .textFieldStyle(.plain)
            .font(.system(size: 20, weight: .medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(nsColor: .textBackgroundColor))
            .focused($isSearchFocused)
    }

    private var paneList: some View {
        VStack(spacing: 0) {
            header

            List(selection: $viewModel.selectedPaneID) {
                ForEach(viewModel.filteredPanes) { pane in
                    PaneRow(pane: pane)
                        .tag(pane.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            viewModel.selectedPaneID = pane.id
                            focusSelectedPane()
                        }
                }
            }
            .listStyle(.inset)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.filteredPanes.count) panes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
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

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func focusSelectedPane() {
        if viewModel.focusSelectedPane() {
            onDismiss()
        }
    }
}

private struct PaneRow: View {
    let pane: TmuxPane

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 2) {
            GridRow {
                Text(pane.sessionName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 96, alignment: .leading)
                    .lineLimit(1)

                Text(pane.displayWindow)
                    .foregroundStyle(.secondary)
                    .frame(width: 128, alignment: .leading)
                    .lineLimit(1)

                Text(pane.currentCommand)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Text(pane.paneID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 48, alignment: .trailing)
            }

            GridRow {
                Color.clear
                    .frame(width: 96, height: 0)
                Color.clear
                    .frame(width: 128, height: 0)
                Text(pane.currentPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Color.clear
                    .frame(width: 48, height: 0)
            }
        }
        .padding(.vertical, 7)
    }
}
