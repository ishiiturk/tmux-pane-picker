import Testing
@testable import TmuxPanePicker

struct TmuxPaneParserTests {
    @Test
    func parsesListPanesOutput() {
        let output = """
        dev\t1\teditor\t0\t%12\tnvim\t/Users/example/app
        ops\t0\tlogs\t1\t%21\ttail\t/var/log

        """

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 2)
        #expect(panes[0].sessionName == "dev")
        #expect(panes[0].targetWindow == "dev:1")
        #expect(panes[0].paneID == "%12")
        #expect(panes[1].currentCommand == "tail")
    }

    @Test
    func skipsMalformedLines() {
        let output = """
        invalid
        dev\t1\teditor\t0\t%12\tnvim\t/Users/example/app
        """

        let panes = TmuxPaneParser.parseListPanesOutput(output)

        #expect(panes.count == 1)
        #expect(panes[0].paneID == "%12")
    }
}
