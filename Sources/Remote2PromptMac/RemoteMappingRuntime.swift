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
    @Published public private(set) var permissionNotice: String?
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
        guard IOHIDPermission.runningCodeIsCurrent() else {
            stop()
            status = "应用已更新，请退出并重新打开"
            errorMessage = "正在运行的构建与磁盘上的应用不一致，当前权限状态不能用于判断新构建。请重开应用后刷新。"
            return
        }
        let oldCount = detectedCount
        let oldInput = inputMonitoring; let oldAX = accessibility
        detectedCount = HIDRemoteMonitor.discoverCount()
        inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        accessibility = AXIsProcessTrusted()
        if oldCount != detectedCount || oldInput != inputMonitoring || oldAX != accessibility { retryAllowed = true }
        guard configuration.mappingsEnabled else { return }
        // Accessibility includes event posting/listening. The HID open remains authoritative for this device.
        guard accessibility else {
            stop(); status = "等待系统权限授权"; return
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

    public func requestInputMonitoring() {
        NSApp.activate(ignoringOtherApps: true)
        let hidGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let eventGranted = CGRequestListenEventAccess()
        permissionNotice = hidGranted || eventGranted ? "系统已允许输入监听。" : "已向 macOS 请求输入监控权限。若系统不再弹窗，请使用“打开输入监控设置”检查当前应用条目。设备控制授权也可涵盖监听能力，实际连接仍由系统验证。"
        refresh()
    }
    public func requestAccessibility() {
        NSApp.activate(ignoringOtherApps: true)
        let granted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        permissionNotice = granted ? "设备控制权限已授予。" : "已向 macOS 请求设备控制权限。完成后可刷新状态；系统不再弹窗时请打开对应设置页。"
        refresh()
    }
    public func openInputMonitoringSettings() { openPrivacyPane("Privacy_ListenEvent") }
    public func openAccessibilitySettings() { openPrivacyPane("Privacy_Accessibility") }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"), NSWorkspace.shared.open(url) else {
            errorMessage = "无法打开系统设置，请手动前往“隐私与安全性”完成授权。"
            return
        }
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
