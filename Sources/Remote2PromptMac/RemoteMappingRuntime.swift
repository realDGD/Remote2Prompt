import AppKit
import ApplicationServices
import Combine
import IOKit.hid
import Remote2PromptCore

public struct RemoteKeyActivity {
    public let button: RemoteButton?
    public let isVoice: Bool
    public let isDown: Bool
}

/// Serial main-run-loop owner of hardware, mapping lease, gesture timers and synthetic key lifetimes.
@MainActor
public final class RemoteMappingRuntime: ObservableObject {
    @Published public private(set) var status = "自定义映射已关闭"
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var detectedCount = 0
    @Published public private(set) var isRunning = false
    @Published public private(set) var activeButtons: Set<RemoteButton> = []
    @Published public private(set) var voiceHeld = false
    @Published public private(set) var reportCount = 0
    @Published public private(set) var lastActivity: RemoteKeyActivity?
    @Published public private(set) var inputMonitoring = false
    @Published public private(set) var accessibility = false
    private var configuration = AppConfiguration()
    private var lease: NativeKeyLease?
    private let monitor = HIDRemoteMonitor()
    private let sender = SystemActionSender()
    private var gestures = ButtonGestures()
    private var voice = VoiceSession()
    private var held: [String: Set<UInt16>] = [:]
    private var pollTimer: Timer?
    private var gestureTimer: Timer?
    private var observations: [NSObjectProtocol] = []
    private var workspaceObservation: NSObjectProtocol?
    private var retryAllowed = true
    private let hardwareEnabled: Bool

    public init(hardwareEnabled: Bool = true) {
        self.hardwareEnabled = hardwareEnabled
        guard hardwareEnabled else { status = "界面检查模式，未访问设备"; return }
        do { lease = try NativeKeyLease.system(); try lease?.restore() }
        catch { errorMessage = error.localizedDescription; retryAllowed = false }
        monitor.onReport = { [weak self] owner, usages in self?.received(owner, usages) }
        monitor.onDisconnect = { [weak self] owner in self?.disconnected(owner) }
        monitor.onFailure = { [weak self] message in self?.fail(message) }
        monitor.onDevicesChanged = { [weak self] in
            guard let self, self.isRunning else { return }
            guard self.monitor.deviceCount > 0 else {
                self.stop(); self.status = "等待已配对的小米遥控器"; return
            }
            do {
                guard try self.lease?.verifyCoverage() == true else {
                    self.fail("设备接口发生变化，请重试连接以验证原生按键抑制。"); return
                }
            } catch { self.fail(error.localizedDescription) }
        }
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        })
        workspaceObservation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop(); self?.retryAllowed = false; self?.status = "已因休眠停止接管，唤醒后请重试连接"
            }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    public func configure(_ value: AppConfiguration) {
        let wasEnabled = configuration.mappingsEnabled
        if configuration.bindings != value.bindings { gestures.cancelAll() }
        configuration = value
        if !value.mappingsEnabled { stop(); status = "自定义映射已关闭" }
        else {
            if !wasEnabled { retryAllowed = true }
            refresh()
        }
    }

    public func refresh() {
        guard hardwareEnabled else { return }
        let oldCount = detectedCount
        let oldInput = inputMonitoring; let oldAX = accessibility
        detectedCount = HIDRemoteMonitor.discoverCount()
        inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        accessibility = AXIsProcessTrusted()
        if oldCount != detectedCount || oldInput != inputMonitoring || oldAX != accessibility { retryAllowed = true }
        guard configuration.mappingsEnabled else { return }
        guard inputMonitoring && accessibility else {
            stop(); status = "等待输入监控与辅助功能授权"; return
        }
        guard detectedCount > 0 else { stop(); status = "等待已配对的小米遥控器"; return }
        if isRunning {
            do {
                guard try lease?.verifyCoverage() == true else { fail("原生按键映射被修改，请重试连接。"); return }
            } catch { fail(error.localizedDescription) }
            return
        }
        guard retryAllowed else { return }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.hd838a.RemoteMic").isEmpty else {
            fail("请先退出 SayAll，避免两款软件同时处理遥控器按键。"); return
        }
        retryAllowed = false
        do {
            if lease == nil { lease = try NativeKeyLease.system() }
            try lease?.acquire()
            try monitor.start()
            isRunning = true; errorMessage = nil
            status = "按键映射已启用"
            gestureTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        } catch { fail(error.localizedDescription) }
    }

    public func retry() {
        stop(); errorMessage = nil; retryAllowed = true
        do { if lease == nil { lease = try NativeKeyLease.system() }; try lease?.restore() }
        catch { fail(error.localizedDescription); return }
        refresh()
    }

    public func requestInputMonitoring() { _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent); refresh() }
    public func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refresh()
    }

    public func shutdown() {
        pollTimer?.invalidate(); pollTimer = nil
        stop()
        observations.forEach(NotificationCenter.default.removeObserver); observations.removeAll()
        if let observation = workspaceObservation { NSWorkspace.shared.notificationCenter.removeObserver(observation); workspaceObservation = nil }
    }

    private func received(_ owner: String, _ usages: Set<UInt16>) {
        guard isRunning else { return }
        do {
            guard try lease?.verifyCoverage() == true else { fail("无法验证当前设备的原生按键抑制，已停止接管。"); return }
            let previous = held[owner] ?? []
            reportCount += 1
            for usage in previous.symmetricDifference(usages).sorted() {
                if usage == XiaomiRemote.voiceUsage || XiaomiRemote.buttonUsages[usage] != nil {
                    lastActivity = RemoteKeyActivity(button: XiaomiRemote.buttonUsages[usage], isVoice: usage == XiaomiRemote.voiceUsage, isDown: usages.contains(usage))
                }
            }
            held[owner] = usages
            if previous.contains(XiaomiRemote.voiceUsage) && !usages.contains(XiaomiRemote.voiceUsage) {
                try deliver(voice.end(owner: owner))
            }
            if usages.contains(XiaomiRemote.voiceUsage) && !previous.contains(XiaomiRemote.voiceUsage) {
                gestures.cancelAll()
                try deliver(voice.begin(owner: owner, trigger: configuration.voiceTrigger))
            }
            if voice.heldTrigger == nil {
                for usage in previous.subtracting(usages).sorted() {
                    if let button = XiaomiRemote.buttonUsages[usage] {
                        try perform(gestures.handle(owner: owner, button: button, isDown: false, at: ProcessInfo.processInfo.systemUptime, configuration: configuration))
                    }
                }
                for usage in usages.subtracting(previous).sorted() {
                    if let button = XiaomiRemote.buttonUsages[usage] {
                        try perform(gestures.handle(owner: owner, button: button, isDown: true, at: ProcessInfo.processInfo.systemUptime, configuration: configuration))
                    }
                }
            }
            publishPressed()
        } catch { fail(error.localizedDescription) }
    }
    private func disconnected(_ owner: String) {
        held.removeValue(forKey: owner); gestures.cancel(owner: owner)
        do { try deliver(voice.end(owner: owner)) } catch { fail(error.localizedDescription) }
        publishPressed()
    }
    private func tick() {
        guard isRunning else { return }
        do { try perform(gestures.advance(to: ProcessInfo.processInfo.systemUptime)) }
        catch { fail(error.localizedDescription) }
    }
    private func perform(_ invocations: [MappedInvocation]) throws {
        for invocation in invocations { try sender.perform(invocation) }
    }
    private func deliver(_ events: [VoiceKeyEvent]) throws {
        for event in events { try sender.voice(event) }
    }
    private func publishPressed() {
        activeButtons = Set(held.values.flatMap { $0.compactMap { XiaomiRemote.buttonUsages[$0] } })
        voiceHeld = voice.heldTrigger != nil
    }
    private func stop() {
        isRunning = false
        gestureTimer?.invalidate(); gestureTimer = nil
        monitor.stop(); gestures.cancelAll(); held.removeAll()
        do { try deliver(voice.cancelAll()); try sender.releaseAll() }
        catch { errorMessage = error.localizedDescription }
        do { try lease?.restore() } catch { errorMessage = error.localizedDescription }
        publishPressed()
    }
    private func fail(_ message: String) {
        errorMessage = nil
        stop(); retryAllowed = false; errorMessage = errorMessage ?? message
        status = "按键接管已停止"
    }
}
