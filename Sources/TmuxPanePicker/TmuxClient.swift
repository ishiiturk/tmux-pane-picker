import Foundation

struct TmuxClient: Equatable {
    let name: String
    let sessionName: String
    let activity: Int
    let flags: Set<String>
    let tty: String

    var isFocused: Bool {
        flags.contains("focused")
    }

    var isAttached: Bool {
        flags.contains("attached")
    }
}

enum TmuxClientParser {
    static func parseListClientsOutput(_ output: String) -> [TmuxClient] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> TmuxClient? {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard columns.count == 5,
              let activity = Int(columns[2]) else {
            return nil
        }

        return TmuxClient(
            name: columns[0],
            sessionName: columns[1],
            activity: activity,
            flags: Set(columns[3].split(separator: ",").map(String.init)),
            tty: columns[4]
        )
    }
}

enum TmuxClientSelector {
    static func targetClient(from clients: [TmuxClient]) -> TmuxClient? {
        clients
            .filter(\.isAttached)
            .sorted { lhs, rhs in
                if lhs.isFocused != rhs.isFocused {
                    return lhs.isFocused
                }
                return lhs.activity > rhs.activity
            }
            .first
    }
}
