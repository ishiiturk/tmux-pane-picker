import Testing
@testable import TmuxPanePicker

struct TmuxClientParserTests {
    @Test
    func parsesListClientsOutput() {
        let output = """
        /dev/ttys000\t0\t1778946965\tattached,focused,UTF-8\t/dev/ttys000
        /dev/ttys001\twork\t1778946900\tattached,UTF-8\t/dev/ttys001

        """

        let clients = TmuxClientParser.parseListClientsOutput(output)

        #expect(clients.count == 2)
        #expect(clients[0].name == "/dev/ttys000")
        #expect(clients[0].sessionName == "0")
        #expect(clients[0].activity == 1778946965)
        #expect(clients[0].isAttached)
        #expect(clients[0].isFocused)
        #expect(clients[1].isAttached)
        #expect(!clients[1].isFocused)
    }

    @Test
    func skipsMalformedClientLines() {
        let output = """
        invalid
        /dev/ttys000\t0\t1778946965\tattached,focused,UTF-8\t/dev/ttys000
        """

        let clients = TmuxClientParser.parseListClientsOutput(output)

        #expect(clients.count == 1)
        #expect(clients[0].name == "/dev/ttys000")
    }

    @Test
    func selectorPrefersFocusedAttachedClient() {
        let clients = TmuxClientParser.parseListClientsOutput("""
        /dev/ttys000\t0\t1778946900\tattached,UTF-8\t/dev/ttys000
        /dev/ttys001\t0\t1778946800\tattached,focused,UTF-8\t/dev/ttys001
        """)

        let selected = TmuxClientSelector.targetClient(from: clients)

        #expect(selected?.name == "/dev/ttys001")
    }

    @Test
    func selectorFallsBackToMostRecentlyActiveAttachedClient() {
        let clients = TmuxClientParser.parseListClientsOutput("""
        /dev/ttys000\t0\t1778946900\tattached,UTF-8\t/dev/ttys000
        /dev/ttys001\t0\t1778947000\tattached,UTF-8\t/dev/ttys001
        /dev/ttys002\t0\t1778948000\tUTF-8\t/dev/ttys002
        """)

        let selected = TmuxClientSelector.targetClient(from: clients)

        #expect(selected?.name == "/dev/ttys001")
    }
}
