import Foundation
import Observation

@MainActor
@Observable
final class PanePickerViewModel {
    var panes: [TmuxPane] = []
    var query = ""
    var selectedPaneID: TmuxPane.ID?
    var errorMessage: String?
    var isLoading = false
    var isFocusing = false

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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return panes
        }

        return panes.filter { $0.searchableText.contains(normalizedQuery) }
    }

    func prepareForPresentation() {
        query = ""
        refresh()
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let panes = try await Task.detached {
                    let service = try TmuxService()
                    return try service.listPanes()
                }.value

                self.panes = panes
                self.selectedPaneID = filteredPanes.first?.id
                self.errorMessage = nil
            } catch {
                self.panes = []
                self.selectedPaneID = nil
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }

    func focusSelectedPane(onSuccess: @escaping @MainActor () -> Void) {
        guard let selectedPane = filteredPanes.first(where: { $0.id == selectedPaneID }) ?? filteredPanes.first else {
            return
        }

        isFocusing = true
        errorMessage = nil

        Task {
            do {
                try await Task.detached {
                    let service = try TmuxService()
                    try service.focus(selectedPane)
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
