import AppKit
import Combine
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

private final class VoiceLimitPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Application-owned, so closing settings does not detach the reminder.
@MainActor final class VoiceLimitHUDController: ObservableObject {
    let runtime = VoiceLimitReminderRuntime()
    private var subscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var panel: VoiceLimitPanel?
    private var hosting: NSHostingView<VoiceLimitHUD>?
    private var screenID: NSNumber?
    private var displayEpoch: UInt64?
    private var stopped = false

    init() {
        subscription = runtime.$state.sink { [weak self] state in self?.render(state) }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render(self?.runtime.state ?? VoiceLimitReminderState()) }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.runtime.suspend() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.runtime.resume() }
        })
    }
    func configure(_ value: AppConfiguration) { runtime.configure(value) }
    func update(_ value: VoiceLimitIndicator) { runtime.update(value) }
    func preview() { runtime.preview() }
    var previewIsHidden: Bool { runtime.state.presentation == .hidden && panel?.isVisible != true }
    var previewIsNonactivating: Bool {
        guard let panel else { return false }
        return panel.isVisible && panel.isOnActiveSpace && panel.occlusionState.contains(.visible) && !panel.isKeyWindow && !panel.isMainWindow && !panel.canBecomeKey
            && !panel.canBecomeMain && panel.ignoresMouseEvents && panel.styleMask.contains(.nonactivatingPanel)
    }
    func shutdown() {
        guard !stopped else { return }
        stopped = true; runtime.shutdown(); subscription = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll(); panel?.orderOut(nil); panel?.close(); panel = nil; hosting = nil
    }
    private func currentScreen() -> NSScreen? {
        if let screenID, let existing = NSScreen.screens.first(where: { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == screenID }) {
            return existing
        }
        let chosen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        screenID = chosen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return chosen
    }
    private func render(_ state: VoiceLimitReminderState) {
        guard !stopped else { return }
        if displayEpoch != state.displayEpoch {
            displayEpoch = state.displayEpoch; screenID = nil
            _ = currentScreen()
        }
        guard state.presentation != .hidden, let screen = currentScreen() else { panel?.orderOut(nil); return }
        let window: VoiceLimitPanel
        if let panel { window = panel }
        else {
            window = VoiceLimitPanel(contentRect: NSRect(x: 0, y: 0, width: 264, height: 74), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "语音时限提醒"
            window.isOpaque = false; window.backgroundColor = .clear
            window.hasShadow = true; window.level = .floating
            window.ignoresMouseEvents = true; window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel = window
        }
        if let hosting { hosting.rootView = VoiceLimitHUD(presentation: state.presentation) }
        else {
            let view = NSHostingView(rootView: VoiceLimitHUD(presentation: state.presentation))
            hosting = view; window.contentView = view
        }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let desiredX = state.position == .bottomCenter ? frame.midX - size.width / 2 : frame.maxX - size.width - 24
        let x = min(max(frame.minX + 12, desiredX), max(frame.minX + 12, frame.maxX - size.width - 12))
        let y = min(frame.minY + 88, max(frame.minY, frame.maxY - size.height - 12))
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.orderFrontRegardless()
    }
}

private struct VoiceLimitHUD: View {
    let presentation: VoiceLimitPresentation
    private var urgent: Bool {
        if case .countdown(_, let urgent) = presentation { return urgent }
        return false
    }
    private var title: String {
        switch presentation {
        case .countdown(let seconds, _): "本段约剩 \(seconds) 秒"
        case .approachingLimit: "已接近单段时限"
        case .ended: "已到单段上限"
        case .endedUnconfirmed: "本段语音已结束"
        case .hidden: ""
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill").font(.system(size: 21, weight: .medium))
                .foregroundStyle(urgent ? .red : .orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                Text("松开再按，接着说").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).frame(width: 264, height: 74)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        // No animation/ticker: respects Reduce Motion and never flashes or speaks.
    }
}
