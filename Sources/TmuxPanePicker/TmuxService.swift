import Foundation

enum TmuxServiceError: LocalizedError {
    case tmuxNotFound
    case commandFailed(command: String, status: Int32, stderr: String)
    case invalidOutput

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
        case .invalidOutput:
            return "tmux returned output that could not be parsed."
        }
    }
}

struct TmuxService {
    private let tmuxPath: String
    private let commandRunner: CommandRunning

    init(commandRunner: CommandRunning = ProcessCommandRunner()) throws {
        guard let tmuxPath = Self.findTmuxPath(commandRunner: commandRunner) else {
            throw TmuxServiceError.tmuxNotFound
        }

        self.tmuxPath = tmuxPath
        self.commandRunner = commandRunner
    }

    func listPanes() throws -> [TmuxPane] {
        let format = [
            "#{session_name}",
            "#{window_index}",
            "#{window_name}",
            "#{pane_index}",
            "#{pane_id}",
            "#{pane_current_command}",
            "#{pane_current_path}"
        ].joined(separator: "\t")

        let result = try commandRunner.run(
            executable: tmuxPath,
            arguments: ["list-panes", "-a", "-F", format]
        )

        guard result.status == 0 else {
            throw TmuxServiceError.commandFailed(
                command: "tmux list-panes",
                status: result.status,
                stderr: result.stderr
            )
        }

        return TmuxPaneParser.parseListPanesOutput(result.stdout)
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
            arguments: ["list-clients", "-F", format]
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
}
