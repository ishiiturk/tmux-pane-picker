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
    func detectsCodexStatusFromPaneTitle() {
        let running = CodexStatus(title: "codex: updating UI")
        let done = CodexStatus(title: "done: fixed bug")

        #expect(running == .running("updating UI"))
        #expect(running?.label == "Codex running")
        #expect(done == .done("fixed bug"))
        #expect(done?.label == "Codex done")
        #expect(CodexStatus(title: "ishii-mac.local") == nil)
    }
}
