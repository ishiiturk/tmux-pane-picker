import Foundation

struct TmuxPane: Identifiable, Equatable, Sendable {
    let sessionName: String
    let windowIndex: String
    let windowName: String
    let paneIndex: String
    let paneID: String
    let currentCommand: String
    let currentPath: String
    let paneTitle: String

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
            currentPath,
            paneTitle
        ].joined(separator: " ").lowercased()
    }

    var codexStatus: CodexStatus? {
        CodexStatus(title: paneTitle)
    }
}

enum CodexStatus: Equatable, Sendable {
    case running(String)
    case done(String)

    init?(title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = trimmedTitle.lowercased()

        if lowercasedTitle.hasPrefix("codex:") {
            self = .running(Self.message(from: trimmedTitle, prefixLength: 6))
        } else if lowercasedTitle.hasPrefix("done:") {
            self = .done(Self.message(from: trimmedTitle, prefixLength: 5))
        } else {
            return nil
        }
    }

    var label: String {
        switch self {
        case .running:
            return "Codex running"
        case .done:
            return "Codex done"
        }
    }

    var message: String {
        switch self {
        case let .running(message), let .done(message):
            return message
        }
    }

    private static func message(from title: String, prefixLength: Int) -> String {
        String(title.dropFirst(prefixLength)).trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard columns.count == 8 else {
            return nil
        }

        return TmuxPane(
            sessionName: columns[0],
            windowIndex: columns[1],
            windowName: columns[2],
            paneIndex: columns[3],
            paneID: columns[4],
            currentCommand: columns[5],
            currentPath: columns[6],
            paneTitle: columns[7]
        )
    }
}
