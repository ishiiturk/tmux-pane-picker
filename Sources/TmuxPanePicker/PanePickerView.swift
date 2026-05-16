import SwiftUI

struct PanePickerView: View {
    @Bindable var viewModel: PanePickerViewModel
    let onDismiss: () -> Void
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField

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
        .frame(minWidth: 520, idealWidth: 640, minHeight: 360, idealHeight: 460)
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(paneGroups) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                SessionHeader(group: group)

                                ForEach(group.panes) { pane in
                                    PaneRow(
                                        pane: pane,
                                        isSelected: pane.id == viewModel.selectedPaneID
                                    )
                                    .id(pane.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectedPaneID = pane.id
                                    }
                                    .onTapGesture(count: 2) {
                                        viewModel.selectedPaneID = pane.id
                                        focusSelectedPane()
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

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
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

private struct PaneRow: View {
    let pane: TmuxPane
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(pane.displayWindow)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextStyle)
                    .frame(width: 104, alignment: .leading)
                    .lineLimit(1)

                Text(pane.currentCommand)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(1)

                if let codexStatus = pane.codexStatus {
                    CodexStatusBadge(status: codexStatus, isSelected: isSelected)
                }

                Spacer(minLength: 8)

                Text(pane.paneID)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondaryTextStyle)
                    .lineLimit(1)
            }

            Text(detailText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(secondaryTextStyle)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        }
    }

    private var detailText: String {
        let title: String? = if let codexStatus = pane.codexStatus {
            codexStatus.message.isEmpty ? nil : codexStatus.message
        } else {
            pane.paneTitle.isEmpty ? nil : pane.paneTitle
        }

        if let title {
            return "\(title) - \(pane.currentPath)"
        }

        return pane.currentPath
    }

    private var primaryTextStyle: some ShapeStyle {
        isSelected ? .white : .primary
    }

    private var secondaryTextStyle: some ShapeStyle {
        isSelected ? .white.opacity(0.82) : .secondary
    }
}

private struct CodexStatusBadge: View {
    let status: CodexStatus
    let isSelected: Bool

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foregroundStyle)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(backgroundStyle, in: Capsule())
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
