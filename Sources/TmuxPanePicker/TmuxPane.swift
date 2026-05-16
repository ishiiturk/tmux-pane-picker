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
    let agentAttention: AgentAttention?

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

    var requiresUserAction: Bool {
        agentAttention != nil
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

enum AgentAttention: Equatable, Sendable {
    case waitingForUser
    case awaitingApproval

    init?(screenText: String, codexStatus: CodexStatus?) {
        guard case .running = codexStatus else {
            return nil
        }

        let lines = screenText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tail = lines.suffix(16).joined(separator: "\n")
        let lowercasedTail = tail.lowercased()

        if Self.containsApprovalPrompt(lowercasedTail) {
            self = .awaitingApproval
            return
        }

        if tail.contains("• Working") {
            return nil
        }

        if lines.suffix(8).contains(where: { $0.hasPrefix("›") }) {
            self = .waitingForUser
            return
        }

        return nil
    }

    var label: String {
        switch self {
        case .waitingForUser:
            return "Waiting for user"
        case .awaitingApproval:
            return "Approval needed"
        }
    }

    private static func containsApprovalPrompt(_ text: String) -> Bool {
        let approvalWords = [
            "approval",
            "approve",
            "allow",
            "permission",
            "do you want to",
            "requires approval"
        ]

        return approvalWords.contains { text.contains($0) }
    }
}

extension TmuxPane {
    func withAgentAttention(_ agentAttention: AgentAttention?) -> TmuxPane {
        TmuxPane(
            sessionName: sessionName,
            windowIndex: windowIndex,
            windowName: windowName,
            paneIndex: paneIndex,
            paneID: paneID,
            currentCommand: currentCommand,
            currentPath: currentPath,
            paneTitle: paneTitle,
            agentAttention: agentAttention
        )
    }
}

enum TmuxPaneParser {
    static func parseListPanesOutput(_ output: String) -> [TmuxPane] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> TmuxPane? {
        let columns = line
            .split(separator: "\t", maxSplits: 7, omittingEmptySubsequences: false)
            .map(String.init)
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
            paneTitle: columns[7],
            agentAttention: nil
        )
    }
}
