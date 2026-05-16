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
        #expect(panes[0].codexStatus == nil)
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
    func detectsCodexStatusFromPaneTitle() {
        let running = CodexStatus(title: "codex: updating UI")
        let done = CodexStatus(title: "done: fixed bug")

        #expect(running == .running("updating UI"))
        #expect(running?.label == "Codex running")
        #expect(done == .done("fixed bug"))
        #expect(done?.label == "Codex done")
        #expect(CodexStatus(title: "ishii-mac.local") == nil)
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
            codexStatus: .running("review changes")
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
            codexStatus: .running("build")
        )

        #expect(attention == .awaitingApproval)
        #expect(attention?.label == "Approval needed")
    }

    @Test
    func doesNotFlagWorkingAgentAsWaiting() {
        let screen = """
        › Implement feature

        • Working (21s • esc to interrupt)
        """

        let attention = AgentAttention(
            screenText: screen,
            codexStatus: .running("implement feature")
        )

        #expect(attention == nil)
    }
}
