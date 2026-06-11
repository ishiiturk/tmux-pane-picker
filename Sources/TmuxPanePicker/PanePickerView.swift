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
        .background(PickerPalette.canvas)
        .frame(minWidth: 420, idealWidth: 500, minHeight: 360, idealHeight: 560)
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

                                ForEach(group.windowGroups) { windowGroup in
                                    VStack(alignment: .leading, spacing: 4) {
                                        WindowHeader(group: windowGroup)

                                        LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 6) {
                                            ForEach(windowGroup.panes) { pane in
                                                PaneTile(
                                                    pane: pane,
                                                    isSelected: pane.id == viewModel.selectedPaneID
                                                )
                                                .id(pane.id)
                                                .contentShape(Rectangle())
                                                .highPriorityGesture(TapGesture(count: 2).onEnded {
                                                    focus(pane)
                                                })
                                                .onTapGesture {
                                                    focusKeepingWindowOpen(pane)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .background(PickerPalette.canvas)
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

            Text("\(paneGroups.count) sessions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(PickerPalette.divider)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No panes",
            systemImage: "rectangle.split.3x1",
            description: Text("No tmux panes are available.")
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
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private func focusSelectedPane() {
        viewModel.focusSelectedPane {
            onDismiss()
        }
    }

    private func focus(_ pane: TmuxPane) {
        viewModel.focus(pane: pane) {
            onDismiss()
        }
    }

    private func focusKeepingWindowOpen(_ pane: TmuxPane) {
        viewModel.focus(pane: pane) {
            PanePickerWindowCoordinator.shared.refocusWindowAfterITermActivation()
        }
    }
}

private struct PaneGroup: Identifiable {
    let sessionName: String
    var panes: [TmuxPane]

    var id: String { sessionName }
}

private struct WindowGroup: Identifiable {
    let windowIndex: String
    let windowName: String
    var panes: [TmuxPane]

    var id: String { "\(windowIndex):\(windowName)" }
    var displayName: String { "\(windowIndex):\(windowName)" }
}

private struct SessionHeader: View {
    let group: PaneGroup

    var body: some View {
        HStack(spacing: 8) {
            Text("SESSION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))

            Text(group.sessionName)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text("\(group.windowCount) windows")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text("\(group.panes.count) panes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(PickerPalette.sessionHeader)
        }
        .shadow(color: PickerPalette.sessionHeader.opacity(0.18), radius: 8, y: 3)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

private extension PaneGroup {
    var windowCount: Int {
        Set(panes.map(\.windowIndex)).count
    }

    var windowGroups: [WindowGroup] {
        panes.reduce(into: []) { groups, pane in
            if let index = groups.firstIndex(where: { $0.windowIndex == pane.windowIndex }) {
                groups[index].panes.append(pane)
            } else {
                groups.append(WindowGroup(
                    windowIndex: pane.windowIndex,
                    windowName: pane.windowName,
                    panes: [pane]
                ))
            }
        }
    }
}

private struct WindowHeader: View {
    let group: WindowGroup

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("WINDOW")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)

            Text(group.displayName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            Text("\(group.panes.count) panes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(PickerPalette.windowHeader)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(PickerPalette.divider)
        }
        .padding(.top, 4)
    }
}

private struct PaneTile: View {
    let pane: TmuxPane
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("pane \(pane.paneIndex)")
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

                if let agentAttention = pane.agentAttention {
                    AgentAttentionBadge(attention: agentAttention, isSelected: isSelected)
                }

                if let agentStatus = pane.agentStatus {
                    AgentStatusIcon(status: agentStatus, isSelected: isSelected)
                }
            }

            Text(verbatim: detailText)
                .font(.system(size: 12))
                .foregroundStyle(secondaryTextStyle)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(tileBackground)
        }
        .overlay(alignment: .leading) {
            if let attentionColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(attentionColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)
                    .padding(.leading, 4)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(tileBorder, lineWidth: pane.requiresUserAction ? 2 : 1)
        }
        .shadow(color: attentionShadow, radius: pane.requiresUserAction ? 7 : 0, y: 2)
        .help(pane.paneTitle.isEmpty ? pane.currentPath : pane.paneTitle)
    }

    private var detailText: String {
        pane.displayTitle
    }

    private var primaryTextStyle: some ShapeStyle {
        isSelected ? .white : .primary
    }

    private var secondaryTextStyle: some ShapeStyle {
        isSelected ? .white.opacity(0.82) : .secondary
    }

    private var tileBackground: Color {
        if isSelected {
            return PickerPalette.selected
        }

        switch pane.agentAttention {
        case .awaitingApproval:
            return PickerPalette.approvalBackground
        case .waitingForUser:
            return PickerPalette.waitingBackground
        case nil:
            return PickerPalette.tile
        }
    }

    private var tileBorder: Color {
        if let attentionColor {
            return attentionColor
        }

        switch pane.agentAttention {
        case .awaitingApproval:
            return PickerPalette.approval
        case .waitingForUser:
            return PickerPalette.waiting
        case nil:
            return PickerPalette.divider
        }
    }

    private var attentionColor: Color? {
        switch pane.agentAttention {
        case .awaitingApproval:
            return PickerPalette.approval
        case .waitingForUser:
            return PickerPalette.waiting
        case nil:
            return nil
        }
    }

    private var attentionShadow: Color {
        switch pane.agentAttention {
        case .awaitingApproval:
            return PickerPalette.approval.opacity(0.24)
        case .waitingForUser:
            return PickerPalette.waiting.opacity(0.24)
        case nil:
            return .clear
        }
    }
}

private struct AgentAttentionBadge: View {
    let attention: AgentAttention
    let isSelected: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(foregroundStyle)
            .frame(width: 18, height: 18)
            .background(backgroundStyle, in: Circle())
            .help(attention.label)
    }

    private var symbolName: String {
        switch attention {
        case .waitingForUser:
            return "questionmark"
        case .awaitingApproval:
            return "exclamationmark"
        }
    }

    private var foregroundStyle: Color {
        switch attention {
        case .waitingForUser:
            return isSelected ? PickerPalette.waiting : .orange
        case .awaitingApproval:
            return PickerPalette.approval
        }
    }

    private var backgroundStyle: Color {
        if isSelected {
            return .white
        }

        switch attention {
        case .waitingForUser:
            return PickerPalette.waiting.opacity(0.22)
        case .awaitingApproval:
            return PickerPalette.approval.opacity(0.18)
        }
    }
}

private struct AgentStatusIcon: View {
    let status: AgentStatus
    let isSelected: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foregroundStyle)
                .frame(width: 20, height: 20)
                .background(backgroundStyle, in: Circle())
                .offset(x: runningOffset(at: timeline.date))
                .help(status.label)
        }
        .frame(width: 24, height: 20)
    }

    private var symbolName: String {
        switch status {
        case .running:
            return "figure.run"
        case .done:
            return "figure.stand"
        }
    }

    private var foregroundStyle: Color {
        if isSelected {
            return .white
        }

        switch status {
        case .running:
            return PickerPalette.running
        case .done:
            return PickerPalette.done
        }
    }

    private var backgroundStyle: Color {
        if isSelected {
            return .white.opacity(0.18)
        }

        switch status {
        case .running:
            return PickerPalette.running.opacity(0.14)
        case .done:
            return PickerPalette.done.opacity(0.14)
        }
    }

    private func runningOffset(at date: Date) -> CGFloat {
        guard case .running = status else {
            return 0
        }

        let phase = date.timeIntervalSinceReferenceDate.remainder(dividingBy: 0.84) / 0.84
        return CGFloat(sin(phase * .pi * 2)) * 1.8
    }
}

private enum PickerPalette {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 1.00)
    static let tile = Color.white.opacity(0.92)
    static let windowHeader = Color(red: 0.91, green: 0.95, blue: 1.00)
    static let divider = Color(red: 0.70, green: 0.75, blue: 0.86).opacity(0.62)
    static let selected = Color(red: 0.16, green: 0.49, blue: 0.98)
    static let sessionHeader = Color(red: 1.00, green: 0.39, blue: 0.43)
    static let waiting = Color(red: 1.00, green: 0.72, blue: 0.18)
    static let waitingBackground = Color(red: 1.00, green: 0.82, blue: 0.28).opacity(0.22)
    static let approval = Color(red: 0.96, green: 0.22, blue: 0.50)
    static let approvalBackground = Color(red: 0.96, green: 0.22, blue: 0.50).opacity(0.16)
    static let running = Color(red: 0.63, green: 0.34, blue: 1.00)
    static let done = Color(red: 0.00, green: 0.70, blue: 0.55)
}
