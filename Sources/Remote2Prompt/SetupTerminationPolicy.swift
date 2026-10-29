import AppKit
import SwiftUI

/// AppKit otherwise rejects quit/relaunch before consulting our bounded cleanup delegate.
struct SetupTerminationPolicy: NSViewRepresentable {
    func makeNSView(context: Context) -> SetupTerminationView { SetupTerminationView() }
    func updateNSView(_ view: SetupTerminationView, context: Context) {}
    static func dismantleNSView(_ view: SetupTerminationView, coordinator: ()) { view.restore() }
}

final class SetupTerminationView: NSView {
    private weak var configuredWindow: NSWindow?
    private var original: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restore()
        guard let window else { return }
        configuredWindow = window
        original = window.preventsApplicationTerminationWhenModal
        window.preventsApplicationTerminationWhenModal = false
    }

    func restore() {
        if let original { configuredWindow?.preventsApplicationTerminationWhenModal = original }
        configuredWindow = nil; original = nil
    }
}
