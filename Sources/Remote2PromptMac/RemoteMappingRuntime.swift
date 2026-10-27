import AppKit
import ApplicationServices
import Combine
import CoreServices
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
    @Published public private(set) var setupActive = false
    @Published public private(set) var setupInput = SetupInputCheck()
    @Published public private(set) var requestingPermission = false
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
    private enum PermissionRequest { case input, accessibility }
    private var pendingPermission: PermissionRequest?

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
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.performPendingPermissionRequest()
            }
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
        if !value.mappingsEnabled && !setupActive { stop(); status = "自定义映射已关闭" }
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
        guard configuration.mappingsEnabled || setupActive else { return }
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
            status = setupActive ? "设置向导正在检测按键，日常映射已暂停" : "按键映射已启用"
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

    /// Capture uses the production HID lease but never executes saved actions or voice modifiers.
    public func beginSetup() {
        guard !setupActive else { return }
        stop()
        setupActive = true; errorMessage = nil; retryAllowed = true
        refresh()
    }

    public func checkSetupButtons() { setupInput.beginButtons() }
    public func checkSetupVoice() { setupInput.beginVoice() }

    public func endSetup() {
        guard setupActive else { return }
        stop()
        setupActive = false; retryAllowed = true
        if !configuration.mappingsEnabled { status = "自定义映射已关闭" }
        refresh()
    }

    public func requestInputMonitoring() {
        queuePermissionRequest(.input)
    }
    public func requestAccessibility() {
        queuePermissionRequest(.accessibility)
    }

    private func queuePermissionRequest(_ request: PermissionRequest) {
        guard !requestingPermission else { return }
        pendingPermission = request; requestingPermission = true
        permissionNotice = "正在准备系统授权请求…"
        NSApp.activate(ignoringOtherApps: true)
        // Activation is asynchronous. Request only after this application owns the foreground.
        DispatchQueue.main.async { [weak self] in self?.performPendingPermissionRequest() }
    }

    private func performPendingPermissionRequest() {
        guard NSApp.isActive, let request = pendingPermission else { return }
        pendingPermission = nil
        defer { requestingPermission = false }
        guard IOHIDPermission.runningCodeIsCurrent() else { refresh(); return }
        // Keep System Settings pointing to this bundle when another local build has been removed.
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        switch request {
        case .input:
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            permissionNotice = granted ? "系统已允许监听按键，无需再次申请。这可能来自设备控制授权，不表示已在输入监控列表单独授权。" : "已向 macOS 请求输入监控并打开设置。请启用当前应用；若列表没有条目，可点击“＋”添加下方路径的应用。系统不会为每次请求重新弹窗。"
            if !granted { openInputMonitoringSettings() }
        case .accessibility:
            let granted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            permissionNotice = granted ? "设备控制权限已授予。" : "已向 macOS 请求设备控制权限。完成后返回本应用会自动刷新状态；系统不再提示时请打开对应设置页。"
        }
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
            if setupActive {
                setupInput.receive(owner: owner, previous: previous, current: usages)
                publishPressed()
                return
            }
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
        setupInput.disconnected(owner: owner)
        held.removeValue(forKey: owner); gestures.cancel(owner: owner)
        do { try deliver(voice.end(owner: owner)) } catch { fail(error.localizedDescription) }
        publishPressed()
    }
    private func tick() {
        guard isRunning && !setupActive else { return }
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
        voiceHeld = held.values.contains { $0.contains(XiaomiRemote.voiceUsage) }
    }
    private func stop() {
        isRunning = false
        gestureTimer?.invalidate(); gestureTimer = nil
        monitor.stop(); gestures.cancelAll(); held.removeAll()
        setupInput.invalidate()
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
