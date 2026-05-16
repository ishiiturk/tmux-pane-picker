import Foundation
import Observation

@MainActor
@Observable
final class PanePickerViewModel {
    var panes: [TmuxPane] = []
    var query = ""
    var selectedPaneID: TmuxPane.ID?
    var errorMessage: String?

    private var service: TmuxService?

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
        do {
            let service = try self.service ?? TmuxService()
            self.service = service
            panes = try service.listPanes()
            selectedPaneID = filteredPanes.first?.id
            errorMessage = nil
        } catch {
            panes = []
            selectedPaneID = nil
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func focusSelectedPane() -> Bool {
        guard let selectedPane = filteredPanes.first(where: { $0.id == selectedPaneID }) ?? filteredPanes.first else {
            return false
        }

        do {
            let service = try self.service ?? TmuxService()
            self.service = service
            try service.focus(selectedPane)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
