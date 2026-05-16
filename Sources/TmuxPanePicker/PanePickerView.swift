import SwiftUI

struct PanePickerView: View {
    @Bindable var viewModel: PanePickerViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else if viewModel.filteredPanes.isEmpty {
                    emptyView
                } else {
                    paneList
                }

                if let busyMessage = viewModel.busyMessage {
                    busyOverlay(busyMessage)
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 500, minHeight: 260, idealHeight: 320)
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

    private var paneList: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(paneGroups) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                SessionHeader(group: group)

                                LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 6) {
                                    ForEach(group.panes) { pane in
                                        PaneTile(
                                            pane: pane,
                                            isSelected: pane.id == viewModel.selectedPaneID
                                        )
                                        .id(pane.id)
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                                            viewModel.selectedPaneID = pane.id
                                        })
                                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                                            viewModel.selectedPaneID = pane.id
                                            focusSelectedPane()
                                        })
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: viewModel.selectedPaneID) {
                    guard let selectedPaneID = viewModel.selectedPaneID else {
                        return
                    }

                    withAnimation(.snappy(duration: 0.12)) {
                        proxy.scrollTo(selectedPaneID, anchor: .center)
                    }
                }
            }
        }
    }

    private var tileColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 142, maximum: 210), spacing: 6, alignment: .topLeading)
        ]
    }

    private var paneGroups: [PaneGroup] {
        viewModel.filteredPanes.reduce(into: []) { groups, pane in
            if let index = groups.firstIndex(where: { $0.sessionName == pane.sessionName }) {
                groups[index].panes.append(pane)
            } else {
                groups.append(PaneGroup(sessionName: pane.sessionName, panes: [pane]))
            }
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

    private func busyOverlay(_ message: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 12, y: 6)
    }

    private func focusSelectedPane() {
        viewModel.focusSelectedPane {
            onDismiss()
        }
    }
}

private struct PaneGroup: Identifiable {
    let sessionName: String
    var panes: [TmuxPane]

    var id: String { sessionName }
}

private struct SessionHeader: View {
    let group: PaneGroup

    var body: some View {
        HStack(spacing: 8) {
            Text(group.sessionName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("\(group.panes.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

private struct PaneTile: View {
    let pane: TmuxPane
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(pane.displayWindow)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(pane.paneID)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryTextStyle)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(pane.currentCommand)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(1)

                if let codexStatus = pane.codexStatus {
                    CodexStatusIcon(status: codexStatus, isSelected: isSelected)
                }
            }

            Text(detailText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(secondaryTextStyle)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6))
        }
    }

    private var detailText: String {
        let title: String? = if let codexStatus = pane.codexStatus {
            codexStatus.message.isEmpty ? nil : codexStatus.message
        } else {
            pane.paneTitle.isEmpty ? nil : pane.paneTitle
        }

        if let title {
            return title
        }

        return URL(fileURLWithPath: pane.currentPath).lastPathComponent
    }

    private var primaryTextStyle: some ShapeStyle {
        isSelected ? .white : .primary
    }

    private var secondaryTextStyle: some ShapeStyle {
        isSelected ? .white.opacity(0.82) : .secondary
    }
}

private struct CodexStatusIcon: View {
    let status: CodexStatus
    let isSelected: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundStyle)
            .frame(width: 20, height: 20)
            .background(backgroundStyle, in: Circle())
            .help(status.label)
    }

    private var symbolName: String {
        switch status {
        case .running:
            return "sparkles"
        case .done:
            return "checkmark.seal.fill"
        }
    }

    private var foregroundStyle: Color {
        if isSelected {
            return .white
        }

        switch status {
        case .running:
            return .orange
        case .done:
            return .green
        }
    }

    private var backgroundStyle: Color {
        if isSelected {
            return .white.opacity(0.18)
        }

        switch status {
        case .running:
            return .orange.opacity(0.14)
        case .done:
            return .green.opacity(0.14)
        }
    }
}
