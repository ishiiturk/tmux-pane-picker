import Darwin
import Foundation

enum TmuxServiceError: LocalizedError {
    case tmuxNotFound
    case commandFailed(command: String, status: Int32, stderr: String)
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .tmuxNotFound:
            return "tmux executable was not found."
        case let .commandFailed(command, status, stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return "\(command) failed with status \(status)."
            }
            return "\(command) failed with status \(status): \(message)"
        case let .invalidOutput(message):
            return message
        }
    }
}

struct TmuxPaneListResult: Sendable {
    let panes: [TmuxPane]
    let diagnostics: String
}

struct TmuxService {
    private let tmuxPath: String
    private let socketPath: String?
    private let commandRunner: CommandRunning

    init(commandRunner: CommandRunning = ProcessCommandRunner()) throws {
        guard let tmuxPath = Self.findTmuxPath(commandRunner: commandRunner) else {
            throw TmuxServiceError.tmuxNotFound
        }

        self.tmuxPath = tmuxPath
        self.socketPath = Self.findTmuxSocketPath()
        self.commandRunner = commandRunner
    }

    func listPanes() throws -> [TmuxPane] {
        try listPanesWithDiagnostics().panes
    }

    func listPanesWithDiagnostics() throws -> TmuxPaneListResult {
        let format = [
            "#{session_name}",
            "#{window_index}",
            "#{window_name}",
            "#{pane_index}",
            "#{pane_id}",
            "#{pane_current_command}",
            "#{pane_current_path}",
            "#{pane_title}"
        ].joined(separator: String(TmuxPaneFormat.delimiter))

        let result = try commandRunner.run(
            executable: tmuxPath,
            arguments: tmuxArguments(["list-panes", "-a", "-F", format])
        )
        let rawLineCount = result.stdout.split(whereSeparator: \.isNewline).count

        guard result.status == 0 else {
            throw TmuxServiceError.commandFailed(
                command: "tmux list-panes",
                status: result.status,
                stderr: result.stderr
            )
        }

        let panes = TmuxPaneParser.parseListPanesOutput(result.stdout).map { pane in
            enrichAgentAttention(for: pane)
        }
        let diagnostics = [
            "tmux: \(tmuxPath)",
            "socket: \(socketPath ?? "default")",
            "raw lines: \(rawLineCount)",
            "parsed panes: \(panes.count)"
        ].joined(separator: "\n")

        if panes.isEmpty,
           !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TmuxServiceError.invalidOutput("\(diagnostics)\n\nRaw tmux output could not be parsed.")
        }

        return TmuxPaneListResult(panes: panes, diagnostics: diagnostics)
    }

    func listClients() throws -> [TmuxClient] {
        let format = [
            "#{client_name}",
            "#{client_session}",
            "#{client_activity}",
            "#{client_flags}",
            "#{client_tty}"
        ].joined(separator: "\t")

        let result = try commandRunner.run(
            executable: tmuxPath,
            arguments: tmuxArguments(["list-clients", "-F", format])
        )

        guard result.status == 0 else {
            throw TmuxServiceError.commandFailed(
                command: "tmux list-clients",
                status: result.status,
                stderr: result.stderr
            )
        }

        return TmuxClientParser.parseListClientsOutput(result.stdout)
    }

    func focus(_ pane: TmuxPane) throws {
        let client = try targetClient()
        try runTmux(
            arguments: ["switch-client", "-c", client.name, "-t", pane.targetWindow],
            commandName: "tmux switch-client"
        )
        try runTmux(arguments: ["select-pane", "-t", pane.paneID], commandName: "tmux select-pane")
        try activateITerm2()
    }

    private func targetClient() throws -> TmuxClient {
        guard let client = TmuxClientSelector.targetClient(from: try listClients()) else {
            throw TmuxServiceError.commandFailed(
                command: "tmux list-clients",
                status: 1,
                stderr: "No attached tmux clients were found."
            )
        }

        return client
    }

    private func runTmux(arguments: [String], commandName: String) throws {
        let result = try commandRunner.run(executable: tmuxPath, arguments: arguments)
        guard result.status == 0 else {
            throw TmuxServiceError.commandFailed(
                command: commandName,
                status: result.status,
                stderr: result.stderr
            )
        }
    }

    private func enrichAgentAttention(for pane: TmuxPane) -> TmuxPane {
        guard let codexStatus = pane.codexStatus else {
            return pane
        }

        guard let result = try? commandRunner.run(
            executable: tmuxPath,
            arguments: tmuxArguments(["capture-pane", "-p", "-t", pane.paneID, "-S", "-80"])
        ), result.status == 0 else {
            return pane
        }

        return pane.withAgentAttention(AgentAttention(
            screenText: result.stdout,
            codexStatus: codexStatus
        ))
    }

    private func activateITerm2() throws {
        let result = try commandRunner.run(
            executable: "/usr/bin/open",
            arguments: ["-b", "com.googlecode.iterm2"]
        )

        guard result.status == 0 else {
            throw TmuxServiceError.commandFailed(
                command: "open -b com.googlecode.iterm2",
                status: result.status,
                stderr: result.stderr
            )
        }
    }

    private static func findTmuxPath(commandRunner: CommandRunning) -> String? {
        let candidates = [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        if let result = try? commandRunner.run(executable: "/usr/bin/env", arguments: ["which", "tmux"]),
           result.status == 0 {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                return path
            }
        }

        return nil
    }

    private func tmuxArguments(_ arguments: [String]) -> [String] {
        guard let socketPath else {
            return arguments
        }

        return ["-S", socketPath] + arguments
    }

    private static func findTmuxSocketPath() -> String? {
        if let tmux = ProcessInfo.processInfo.environment["TMUX"]?.split(separator: ",").first {
            let socketPath = String(tmux)
            if FileManager.default.fileExists(atPath: socketPath) {
                return socketPath
            }
        }

        let defaultSocketPath = "/private/tmp/tmux-\(getuid())/default"
        if FileManager.default.fileExists(atPath: defaultSocketPath) {
            return defaultSocketPath
        }

        return nil
    }
}
