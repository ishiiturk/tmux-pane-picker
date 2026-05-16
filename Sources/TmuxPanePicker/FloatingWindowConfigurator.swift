import SwiftUI

struct FloatingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.isReleasedWhenClosed = false
            window.center()
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.level = .floating
        }
    }
}
