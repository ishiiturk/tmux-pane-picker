import Foundation

struct TmuxPane: Identifiable, Equatable {
    let sessionName: String
    let windowIndex: String
    let windowName: String
    let paneIndex: String
    let paneID: String
    let currentCommand: String
    let currentPath: String

    var id: String { paneID }

    var targetWindow: String {
        "\(sessionName):\(windowIndex)"
    }

    var displayWindow: String {
        "\(windowIndex):\(windowName)"
    }

    var searchableText: String {
        [
            sessionName,
            windowIndex,
            windowName,
            paneIndex,
            paneID,
            currentCommand,
            currentPath
        ].joined(separator: " ").lowercased()
    }
}

enum TmuxPaneParser {
    static func parseListPanesOutput(_ output: String) -> [TmuxPane] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> TmuxPane? {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard columns.count == 7 else {
            return nil
        }

        return TmuxPane(
            sessionName: columns[0],
            windowIndex: columns[1],
            windowName: columns[2],
            paneIndex: columns[3],
            paneID: columns[4],
            currentCommand: columns[5],
            currentPath: columns[6]
        )
    }
}
