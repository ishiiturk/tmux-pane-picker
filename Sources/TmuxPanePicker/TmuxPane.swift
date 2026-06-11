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

    var agentStatus: AgentStatus? {
        AgentStatus(title: paneTitle, currentCommand: currentCommand)
    }

    var displayTitle: String {
        let title = paneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = agentStatus?.message ?? title
        let cleanedText = Self.cleanDisplayTitle(displayText)

        if !cleanedText.isEmpty {
            return Self.shortDisplayTitle(cleanedText)
        }

        return URL(fileURLWithPath: currentPath).lastPathComponent
    }

    var requiresUserAction: Bool {
        agentAttention != nil
    }

    private static func cleanDisplayTitle(_ title: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "-:|"))

        return title.trimmingCharacters(in: separators)
    }

    private static func shortDisplayTitle(_ title: String) -> String {
        let maxLength = 16
        guard title.count > maxLength else {
            return title
        }

        return String(title.prefix(maxLength)) + "..."
    }
}

enum TmuxPaneFormat {
    static let delimiter = "\u{1F}"
}

enum CodingAgent: Equatable, Sendable {
    case codex
    case claudeCode

    var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        }
    }
}

enum AgentStatus: Equatable, Sendable {
    case running(CodingAgent, String)
    case done(String)

    init?(title: String, currentCommand: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = trimmedTitle.lowercased()

        if let agentPrefix = Self.runningAgentPrefix(in: lowercasedTitle) {
            self = .running(
                agentPrefix.agent,
                Self.message(from: trimmedTitle, prefixLength: agentPrefix.prefix.count)
            )
        } else if lowercasedTitle.hasPrefix("done:") {
            self = .done(Self.message(from: trimmedTitle, prefixLength: 5))
        } else if let agent = Self.runningAgent(command: currentCommand) {
            self = .running(agent, trimmedTitle)
        } else {
            return nil
        }
    }

    var label: String {
        switch self {
        case let .running(agent, _):
            return "\(agent.displayName) running"
        case .done:
            return "Agent done"
        }
    }

    var message: String {
        switch self {
        case let .running(_, message), let .done(message):
            return message
        }
    }

    private static func runningAgentPrefix(in lowercasedTitle: String) -> (agent: CodingAgent, prefix: String)? {
        let prefixes: [(CodingAgent, String)] = [
            (.claudeCode, "claudecode:"),
            (.claudeCode, "claude code:"),
            (.claudeCode, "claude:"),
            (.codex, "codex:")
        ]

        return prefixes.first { lowercasedTitle.hasPrefix($0.1) }
    }

    private static func runningAgent(command: String) -> CodingAgent? {
        let executable = URL(fileURLWithPath: command).lastPathComponent.lowercased()

        switch executable {
        case "codex":
            return .codex
        case "claude":
            return .claudeCode
        default:
            return nil
        }
    }

    private static func message(from title: String, prefixLength: Int) -> String {
        String(title.dropFirst(prefixLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AgentAttention: Equatable, Sendable {
    case waitingForUser
    case awaitingApproval

    init?(screenText: String, agentStatus: AgentStatus?) {
        guard case .running = agentStatus else {
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

        if lines.suffix(8).contains(where: Self.isInputPrompt) {
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

    private static func isInputPrompt(_ line: String) -> Bool {
        line.hasPrefix("›")
            || line.hasPrefix(">")
            || line.hasPrefix("❯")
            || line.contains("│ >")
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
        let columns = parseColumns(line)
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

    private static func parseColumns(_ line: String) -> [String] {
        for delimiter in ["\\037", TmuxPaneFormat.delimiter, "\t", "|"] {
            let columns = split(line, separator: delimiter, maxSplits: 7)
            if columns.count == 8 {
                return columns
            }
        }

        return []
    }

    private static func split(_ line: String, separator: String, maxSplits: Int) -> [String] {
        guard !separator.isEmpty else {
            return [line]
        }

        var columns: [String] = []
        var remainder = line[...]

        while columns.count < maxSplits,
              let range = remainder.range(of: separator) {
            columns.append(String(remainder[..<range.lowerBound]))
            remainder = remainder[range.upperBound...]
        }

        columns.append(String(remainder))
        return columns
    }
}
