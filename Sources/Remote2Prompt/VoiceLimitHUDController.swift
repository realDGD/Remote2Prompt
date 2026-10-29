import AppKit
import Combine
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

private final class VoiceLimitPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum VoiceLimitHUDLayout {
    static let size = CGSize(width: 192, height: 34)
    static let cornerRadius: CGFloat = 17
}

/// Application-owned, so closing settings does not detach the reminder.
@MainActor final class VoiceLimitHUDController: ObservableObject {
    let runtime: VoiceLimitReminderRuntime
    private let follower: WeTypeCapsuleFollower
    private let hasInspectionSource: Bool
    private var subscription: AnyCancellable?
    private var anchorSubscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var panel: VoiceLimitPanel?
    private var hosting: NSHostingView<VoiceLimitHUD>?
    private var screenID: NSNumber?
    private var displayEpoch: UInt64?
    // @Published sends before storing. Anchor callbacks must use this incoming value,
    // never re-read runtime.state while a hide/epoch transition is being delivered.
    private var presentationState = VoiceLimitReminderState()
    private var stopped = false

    init(runtime: VoiceLimitReminderRuntime = VoiceLimitReminderRuntime(), inspectionSource: (any WeTypeWindowSource)? = nil) {
        self.runtime = runtime
        hasInspectionSource = inspectionSource != nil
        follower = WeTypeCapsuleFollower(source: inspectionSource ?? SystemWeTypeWindowSource())
        anchorSubscription = follower.anchors.sink { [weak self] _ in self?.placeVisiblePanel() }
        subscription = runtime.$state.sink { [weak self] state in self?.render(state) }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeVisiblePanel() }
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
    var inspectionFrame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }
    var previewIsNonactivating: Bool {
        guard let panel else { return false }
        return panel.isVisible && panel.isOnActiveSpace && panel.occlusionState.contains(.visible) && !panel.isKeyWindow && !panel.isMainWindow && !panel.canBecomeKey
            && !panel.canBecomeMain && panel.ignoresMouseEvents && panel.styleMask.contains(.nonactivatingPanel)
    }
    func shutdown() {
        guard !stopped else { return }
        stopped = true; follower.shutdown(); runtime.shutdown(); subscription = nil; anchorSubscription = nil
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
        presentationState = state
        if displayEpoch != state.displayEpoch {
            displayEpoch = state.displayEpoch; screenID = nil
            _ = currentScreen()
        }
        follower.update(state, allowed: !InterfaceInspection.enabled || hasInspectionSource)
        guard state.presentation != .hidden, currentScreen() != nil else { panel?.orderOut(nil); return }
        let window: VoiceLimitPanel
        if let panel { window = panel }
        else {
            window = VoiceLimitPanel(contentRect: NSRect(origin: .zero, size: VoiceLimitHUDLayout.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
        placeVisiblePanel()
        if !window.isVisible { window.orderFrontRegardless() }
    }
    private func placeVisiblePanel() {
        guard !stopped, presentationState.presentation != .hidden,
              let window = panel, let screen = currentScreen() else { return }
        let screens = NSScreen.screens
        let size = window.frame.size
        if let anchor = follower.anchor, let primary = screens.first,
           let point = VoiceReminderPlacement.following(topLeftWindow: anchor, primaryMaxY: primary.frame.maxY,
                screens: screens.map { ReminderScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) }, size: size) {
            move(window, to: point)
            return
        }
        let frame = screen.visibleFrame
        let desiredX = presentationState.position == .bottomCenter ? frame.midX - size.width / 2 : frame.maxX - size.width - 24
        let x = min(max(frame.minX + 12, desiredX), max(frame.minX + 12, frame.maxX - size.width - 12))
        let y = min(frame.minY + 88, max(frame.minY, frame.maxY - size.height - 12))
        let point = NSPoint(x: x, y: y)
        move(window, to: point)
    }
    private func move(_ window: NSWindow, to point: CGPoint) {
        // AppKit can integralize a panel origin. Normalize once instead of repeatedly
        // sending a half-point origin which the window server rounds on every refresh.
        let aligned = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        if window.frame.origin != aligned { window.setFrameOrigin(aligned) }
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
        case .countdown(let seconds, _): "约剩 \(seconds) 秒"
        case .approachingLimit: "接近单段时限"
        case .ended: "已到单段上限"
        case .endedUnconfirmed: "本段语音已结束"
        case .hidden: ""
        }
    }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill").font(.system(size: 12, weight: .medium))
                .foregroundStyle(urgent ? .red : .orange)
                .frame(width: 14)
            Text(title).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.9)
            Spacer(minLength: 4)
            Text("松开再按").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 10).frame(width: VoiceLimitHUDLayout.size.width, height: VoiceLimitHUDLayout.size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VoiceLimitHUDLayout.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: VoiceLimitHUDLayout.cornerRadius).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        // No animation/ticker: respects Reduce Motion and never flashes or speaks.
    }
}
