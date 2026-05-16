import Foundation
import Observation

@MainActor
@Observable
final class PanePickerViewModel {
    var panes: [TmuxPane] = []
    var selectedPaneID: TmuxPane.ID?
    var errorMessage: String?
    var isLoading = false
    var isFocusing = false
    private var refreshTask: Task<Void, Never>?
    private var isRefreshInFlight = false

    var isBusy: Bool {
        isLoading || isFocusing
    }

    var busyMessage: String? {
        if isFocusing {
            return "Focusing pane"
        }

        if isLoading {
            return "Loading panes"
        }

        return nil
    }

    var filteredPanes: [TmuxPane] {
        panes
    }

    var waitingForUserCount: Int {
        panes.filter { $0.agentAttention == .waitingForUser }.count
    }

    var awaitingApprovalCount: Int {
        panes.filter { $0.agentAttention == .awaitingApproval }.count
    }

    var menuBarTitle: String {
        if awaitingApprovalCount > 0 {
            return "\(awaitingApprovalCount)"
        }

        if waitingForUserCount > 0 {
            return "\(waitingForUserCount)"
        }

        return ""
    }

    var menuBarSystemImage: String {
        if awaitingApprovalCount > 0 {
            return "person.crop.circle.badge.exclamationmark"
        }

        if waitingForUserCount > 0 {
            return "person.crop.circle.badge.questionmark"
        }

        return "rectangle.split.3x1"
    }

    func prepareForPresentation() {
        refresh()
    }

    func startAutoRefresh() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }

                self?.refresh(showLoading: false)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh(showLoading: Bool = true) {
        if isRefreshInFlight {
            return
        }

        isRefreshInFlight = true
        if showLoading {
            isLoading = true
        }

        errorMessage = nil

        Task {
            do {
                let panes = try await Task.detached {
                    let service = try TmuxService()
                    return try service.listPanes()
                }.value

                let previousSelectedPaneID = self.selectedPaneID
                self.panes = panes
                if let previousSelectedPaneID,
                   panes.contains(where: { $0.id == previousSelectedPaneID }) {
                    self.selectedPaneID = previousSelectedPaneID
                } else {
                    self.selectedPaneID = filteredPanes.first?.id
                }
                self.errorMessage = nil
            } catch {
                self.panes = []
                self.selectedPaneID = nil
                self.errorMessage = error.localizedDescription
            }

            if showLoading {
                self.isLoading = false
            }
            self.isRefreshInFlight = false
        }
    }

    func focusSelectedPane(onSuccess: @escaping @MainActor () -> Void) {
        guard let selectedPane = filteredPanes.first(where: { $0.id == selectedPaneID }) ?? filteredPanes.first else {
            return
        }

        focus(pane: selectedPane, onSuccess: onSuccess)
    }

    func focus(pane: TmuxPane, onSuccess: @escaping @MainActor () -> Void) {
        selectedPaneID = pane.id
        isFocusing = true
        errorMessage = nil

        Task {
            do {
                try await Task.detached {
                    let service = try TmuxService()
                    try service.focus(pane)
                }.value

                self.errorMessage = nil
                self.isFocusing = false
                onSuccess()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isFocusing = false
            }
        }
    }

    func selectFirstFilteredPaneIfNeeded() {
        guard !filteredPanes.contains(where: { $0.id == selectedPaneID }) else {
            return
        }

        selectedPaneID = filteredPanes.first?.id
    }

    func selectNextPane() {
        moveSelection(by: 1)
    }

    func selectPreviousPane() {
        moveSelection(by: -1)
    }

    private func moveSelection(by offset: Int) {
        let panes = filteredPanes
        guard !panes.isEmpty else {
            selectedPaneID = nil
            return
        }

        let currentIndex = panes.firstIndex { $0.id == selectedPaneID } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), panes.count - 1)
        selectedPaneID = panes[nextIndex].id
    }
}
