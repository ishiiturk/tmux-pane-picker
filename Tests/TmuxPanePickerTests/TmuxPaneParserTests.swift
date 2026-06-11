import Testing
@testable import TmuxPanePicker

struct TmuxPaneParserTests {
    @Test
    func parsesListPanesOutput() {
        let output = """
        dev\t1\teditor\t0\t%12\tnvim\t/Users/example/app\tvim app
        ops\t0\tlogs\t1\t%21\ttail\t/var/log\tlogs

        """

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 2)
        #expect(panes[0].sessionName == "dev")
        #expect(panes[0].targetWindow == "dev:1")
        #expect(panes[0].paneID == "%12")
        #expect(panes[0].paneTitle == "vim app")
        #expect(panes[0].agentStatus == nil)
        #expect(panes[1].currentCommand == "tail")
    }

    @Test
    func skipsMalformedLines() {
        let output = """
        invalid
        dev\t1\teditor\t0\t%12\tnvim\t/Users/example/app\tvim app
        """

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 1)
        #expect(panes[0].paneID == "%12")
    }

    @Test
    func keepsTabsInsidePaneTitle() {
        let output = "dev\t1\teditor\t0\t%12\tnvim\t/Users/example/app\tcodex:\tneeds input"

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 1)
        #expect(panes[0].paneTitle == "codex:\tneeds input")
    }

    @Test
    func parsesUnitSeparatedOutput() {
        let delimiter = String(TmuxPaneFormat.delimiter)
        let output = [
            "dev",
            "1",
            "editor",
            "0",
            "%12",
            "nvim",
            "/Users/example/app",
            "codex: needs input"
        ].joined(separator: delimiter)

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 1)
        #expect(panes[0].paneID == "%12")
        #expect(panes[0].paneTitle == "codex: needs input")
    }

    @Test
    func parsesTmuxEscapedUnitSeparatedOutput() {
        let output = [
            "dev",
            "1",
            "editor",
            "0",
            "%12",
            "nvim",
            "/Users/example/app",
            "codex: needs input"
        ].joined(separator: "\\037")

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 1)
        #expect(panes[0].paneID == "%12")
        #expect(panes[0].paneTitle == "codex: needs input")
    }

    @Test
    func detectsAgentStatusFromPaneTitle() {
        let running = AgentStatus(title: "codex: updating UI")
        let done = AgentStatus(title: "done: fixed bug")

        #expect(running == .running(kind: .codex, message: "updating UI"))
        #expect(running?.label == "Codex running")
        #expect(done == .done("fixed bug"))
        #expect(done?.label == "Agent done")
        #expect(AgentStatus(title: "ishii-mac.local") == nil)
    }

    @Test
    func detectsClaudeCodeStatusFromPaneTitle() {
        let compact = AgentStatus(title: "claudecode: editing files")
        let spaced = AgentStatus(title: "claude code: reviewing diff")
        let short = AgentStatus(title: "claude: fixing test")

        #expect(compact == .running(kind: .claudeCode, message: "editing files"))
        #expect(spaced == .running(kind: .claudeCode, message: "reviewing diff"))
        #expect(short == .running(kind: .claudeCode, message: "fixing test"))
        #expect(short?.label == "ClaudeCode running")
    }

    @Test
    func displayTitleRemovesAgentStatusPrefix() {
        let pane = TmuxPane.makeFixture(paneTitle: "codex: PRにしてください")

        #expect(pane.displayTitle == "PRにしてください")
    }

    @Test
    func displayTitleTrimsTitleSeparators() {
        let pane = TmuxPane.makeFixture(paneTitle: "---実装レビュー---")

        #expect(pane.displayTitle == "実装レビュー")
    }

    @Test
    func displayTitleShortensLongJapaneseTitles() {
        let pane = TmuxPane.makeFixture(paneTitle: "done: グループ一覧画面でも回数表示と上限リセット状態を表示")

        #expect(pane.displayTitle == "グループ一覧画面でも回数表示と上...")
    }

    @Test
    func detectsAgentWaitingForUser() {
        let screen = """
        • Edited 2 files

        › Run /review on my current changes

          main · gpt-5.5 default
        """

        let attention = AgentAttention(
            screenText: screen,
            agentStatus: .running(kind: .codex, message: "review changes")
        )

        #expect(attention == .waitingForUser)
        #expect(attention?.label == "Waiting for user")
    }

    @Test
    func detectsAgentAwaitingApproval() {
        let screen = """
        Do you want to allow this command?
        npm run build
        """

        let attention = AgentAttention(
            screenText: screen,
            agentStatus: .running(kind: .codex, message: "build")
        )

        #expect(attention == .awaitingApproval)
        #expect(attention?.label == "Approval needed")
    }

    @Test
    func detectsClaudeCodeAwaitingApproval() {
        let screen = """
        Claude Code requests permission to run this command.
        Do you want to proceed?
        """

        let attention = AgentAttention(
            screenText: screen,
            agentStatus: .running(kind: .claudeCode, message: "run command")
        )

        #expect(attention == .awaitingApproval)
    }

    @Test
    func doesNotFlagWorkingAgentAsWaiting() {
        let screen = """
        › Implement feature

        • Working (21s • esc to interrupt)
        """

        let attention = AgentAttention(
            screenText: screen,
            agentStatus: .running(kind: .codex, message: "implement feature")
        )

        #expect(attention == nil)
    }

    @MainActor
    @Test
    func announcesNewApprovalOnlyOnceWhilePaneKeepsWaiting() {
        let speaker = AgentApprovalSpeakerSpy()
        var announcer = AgentApprovalAnnouncer()
        let pane = TmuxPane.makeFixture(paneTitle: "codex: build")
            .withAgentAttention(.awaitingApproval)

        announcer.update(panes: [pane], speaker: speaker)
        announcer.update(panes: [pane], speaker: speaker)

        #expect(speaker.spokenCounts == [1])
    }

    @MainActor
    @Test
    func announcesApprovalAgainAfterItClearsAndReturns() {
        let speaker = AgentApprovalSpeakerSpy()
        var announcer = AgentApprovalAnnouncer()
        let pane = TmuxPane.makeFixture(paneTitle: "codex: build")
            .withAgentAttention(.awaitingApproval)

        announcer.update(panes: [pane], speaker: speaker)
        announcer.update(panes: [], speaker: speaker)
        announcer.update(panes: [pane], speaker: speaker)

        #expect(speaker.spokenCounts == [1, 1])
    }
}

@MainActor
private final class AgentApprovalSpeakerSpy: AgentApprovalSpeaking {
    private(set) var spokenCounts: [Int] = []

    func speakApprovalNeeded(count: Int) {
        spokenCounts.append(count)
    }
}

private extension TmuxPane {
    static func makeFixture(paneTitle: String) -> TmuxPane {
        TmuxPane(
            sessionName: "dev",
            windowIndex: "1",
            windowName: "node",
            paneIndex: "0",
            paneID: "%12",
            currentCommand: "node",
            currentPath: "/Users/example/app",
            paneTitle: paneTitle,
            agentAttention: nil
        )
    }
}
