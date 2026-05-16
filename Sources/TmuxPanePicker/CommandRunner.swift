import Foundation

struct CommandResult: Equatable, Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
}

protocol CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandResult
}

struct ProcessCommandRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return CommandResult(
            status: process.terminationStatus,
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}
