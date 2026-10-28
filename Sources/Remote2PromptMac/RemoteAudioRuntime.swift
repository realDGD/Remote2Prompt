import Combine
import Foundation
import Remote2PromptCore

/// Coordinates a single RC003 audio stream. Data stays in memory and goes only to the chosen loopback.
@MainActor
public final class RemoteAudioRuntime: ObservableObject {
    @Published public private(set) var devices: [LoopbackDevice] = []
    @Published public private(set) var status = "遥控器音频已关闭"
    @Published public private(set) var outputStatus = "未选择回环设备"
    @Published public private(set) var isReady = false
    @Published public private(set) var sessionActive = false
    @Published public private(set) var testingTone = false
    public private(set) var receivedSamples = 0
    @Published public private(set) var progress = VoiceStreamProgress()
    private var receivedPackets = 0
    private var lastPacketAt: TimeInterval?
    private var signalChanging = false
    public var canStart: (() -> Bool)?
    public var prepareInput: ((@escaping (Bool) -> Void) -> Void)?
    public var onBegin: (() -> Bool)?
    public var onEnd: (() -> Void)?
    private let writer: LoopbackWriter
    private let bluetooth: any RemoteVoiceTransport
    private let catalog: @MainActor () -> [LoopbackDevice]
    private let clock: @MainActor () -> TimeInterval
    private var recovery = AudioRecoveryBudget()
    private var connectionGeneration: UInt64 = 0
    private var connectionActive = false
    private var checkingHealth = false
    private var selectedAvailable = false
    private var configuration = AppConfiguration()
    private var decoder = try! RemoteVoiceDecoder(frameBytes: 120)
    private var outputReady = false
    private var bluetoothReady = false
    private var configuring = false
    private var deviceCount = 0
    private var generation: UInt64 = 0
    private var routeGeneration: UInt64 = 0
    private var finishing = false
    private var preparingInput = false
    private var preroll = VoiceStartBuffer()
    private var draining = false
    private var protocolStarted = false
    private var allowEarlyAudio = true
    private var tail: Task<Void, Never>?
    private var startTimeout: Task<Void, Never>?
    private var timer: Timer?
    private let hardwareEnabled: Bool
    private var stopped = false

    public init(hardwareEnabled: Bool = true, writer: LoopbackWriter? = nil,
                transport: (any RemoteVoiceTransport)? = nil,
                catalog: @escaping @MainActor () -> [LoopbackDevice] = { LoopbackDevices.available() },
                clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                automaticMonitoring: Bool = true) {
        self.hardwareEnabled = hardwareEnabled
        self.writer = writer ?? LoopbackWriter()
        bluetooth = transport ?? RemoteVoiceBluetooth()
        self.catalog = catalog; self.clock = clock
        guard hardwareEnabled else { return }
        refreshDevices()
        if automaticMonitoring {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDevices() }
            }
        }
    }
    private func bindTransport() {
        connectionGeneration &+= 1; let token = connectionGeneration
        bluetooth.onStatus = { [weak self] value in
            guard let self, self.connectionGeneration == token, !self.stopped else { return }
            self.status = value
        }
        bluetooth.onFailure = { [weak self] value in
            guard let self, self.connectionGeneration == token, !self.stopped else { return }
            self.invalidateOutput(value)
        }
        bluetooth.onReady = { [weak self] capabilities in
            guard let self, self.connectionGeneration == token, !self.stopped else { return }
            do { self.decoder = try RemoteVoiceDecoder(frameBytes: capabilities.frameBytes) }
            catch { self.invalidateOutput("遥控器音频帧格式不受支持。"); return }
            self.bluetoothReady = true; self.updateReady()
        }
        // HID is the only start signal. A delayed ATVV open cannot start or retry a released session.
        bluetooth.onStarted = { [weak self] in
            guard let self, self.connectionGeneration == token, !self.stopped else { return }
            if !self.sessionActive || self.finishing { _ = self.bluetooth.close() }
            else { self.protocolStarted = true }
        }
        bluetooth.onStopped = { [weak self] in
            guard let self, self.connectionGeneration == token, !self.stopped, self.protocolStarted || self.finishing else { return }
            self.release()
        }
        bluetooth.onSync = { [weak self] data in
            guard let self, self.connectionGeneration == token, !self.stopped, self.sessionActive, !self.draining, self.protocolStarted || self.allowEarlyAudio else { return }
            do { try self.decoder.synchronize(packet: data) }
            catch { self.invalidateOutput("遥控器音频同步数据无效，请重新连接音频。") }
        }
        bluetooth.onAudio = { [weak self] data in
            guard let self, self.connectionGeneration == token, !self.stopped else { return }
            self.receive(data)
        }
    }
    private func stopTransport() {
        connectionGeneration &+= 1; connectionActive = false
        bluetooth.stop(); bluetoothReady = false
    }
    public func configure(_ value: AppConfiguration) {
        guard hardwareEnabled, !stopped else { return }
        let routeChanged = configuration.selectedVirtualInputUID != value.selectedVirtualInputUID
        let changed = routeChanged || configuration.remoteAudioEnabled != value.remoteAudioEnabled || configuration.voiceEnabled != value.voiceEnabled
        if changed {
            cancel(); routeGeneration &+= 1; configuring = false
            stopTransport(); writer.stop(); outputReady = false; isReady = false
            recovery.reset(); selectedAvailable = false
        }
        configuration = value
        guard wanted else { status = "遥控器音频已关闭"; return }
        guard value.selectedVirtualInputUID != nil else {
            outputStatus = "未选择回环设备"; status = outputStatus; return
        }
        refreshDevices()
    }
    public func setRemoteCount(_ count: Int) {
        guard hardwareEnabled, !stopped, deviceCount != count else { return }
        deviceCount = count
        if count != 1 {
            cancel(message: wanted ? "语音音频需要恰好一只兼容遥控器" : nil)
            stopTransport(); updateReady()
        } else {
            recovery.reset()
            if !outputReady && !configuring { prepareOutput() }
            connectIfPossible()
        }
    }
    public func retry() {
        guard hardwareEnabled, !stopped else { return }
        cancel(); routeGeneration &+= 1; configuring = false
        stopTransport(); writer.stop(); outputReady = false; isReady = false
        recovery.reset(); selectedAvailable = false; refreshDevices()
    }
    public func refreshDevices() {
        guard hardwareEnabled, !stopped else { return }
        let available = catalog()
        if devices != available { devices = available }
        guard wanted, let uid = configuration.selectedVirtualInputUID else { return }
        let availableNow = devices.contains { $0.uid == uid }
        let returned = availableNow && !selectedAvailable
        selectedAvailable = availableNow
        guard availableNow else {
            if outputReady || configuring { invalidateOutput("所选回环设备已断开。") }
            outputStatus = "所选设备当前不可用"
            return
        }
        if returned { recovery.reset() }
        if recovery.takeRetry(at: clock()) || (returned && !configuring) { prepareOutput() }
        if outputReady { checkOutputHealth() }
        if sessionActive && !preparingInput && !finishing,
           let lastPacketAt, clock() - lastPacketAt >= 3 {
            invalidateOutput("遥控器音频数据已中断，已结束本次语音。")
        }
    }
    private var wanted: Bool { configuration.remoteAudioEnabled && configuration.voiceEnabled }
    public var canTestTone: Bool { outputReady && !sessionActive && !testingTone }
    private func prepareOutput() {
        guard hardwareEnabled, !stopped, wanted else { return }
        routeGeneration &+= 1; let token = routeGeneration
        outputReady = false; isReady = false
        guard let uid = configuration.selectedVirtualInputUID else {
            writer.stop(); configuring = false; outputStatus = "未选择回环设备"; return
        }
        configuring = true; outputStatus = "正在打开所选回环设备"
        writer.configure(uid: uid, onFailure: { [weak self] error in
            Task { @MainActor in
                guard let self, !self.stopped, self.routeGeneration == token else { return }
                self.invalidateOutput(error.localizedDescription)
            }
        }) { [weak self] result in
            Task { @MainActor in
                guard let self, !self.stopped, self.routeGeneration == token else { return }
                self.configuring = false
                switch result {
                case .success:
                    self.outputReady = true; self.outputStatus = "所选回环设备已就绪"
                    self.updateReady(); self.connectIfPossible()
                case .failure(let error):
                    self.invalidateOutput(error.localizedDescription)
                }
            }
        }
    }
    private func connectIfPossible() {
        guard wanted else { return }
        guard outputReady else { status = outputStatus; return }
        guard deviceCount == 1 else { status = "语音音频需要恰好一只兼容遥控器"; return }
        guard !connectionActive else { return }
        connectionActive = true; bindTransport(); bluetooth.start()
    }
    private func updateReady() {
        let ready = wanted && outputReady && bluetoothReady && deviceCount == 1
        if isReady != ready { isReady = ready }
    }

    @discardableResult public func press() -> Bool {
        let interruptedTail = sessionActive && finishing
        if sessionActive && !finishing { return true }
        guard !stopped, isReady, canStart?() == true else {
            if !sessionActive {
                _ = bluetooth.close()
                // A route/decoder/Bluetooth failure already explains why readiness is false.
                // Keep that actionable cause instead of replacing it with a permission guess.
                if wanted && isReady { status = "按键接管尚未就绪，请检查遥控器连接和设备控制权限。" }
            }
            return false
        }
        if interruptedTail { cancel() }
        generation &+= 1; let token = generation
        try? decoder.reset(); receivedSamples = 0; receivedPackets = 0; lastPacketAt = nil; signalChanging = false; finishing = false; draining = false
        protocolStarted = false; allowEarlyAudio = !interruptedTail
        preparingInput = true; preroll.clear()
        testingTone = false; writer.begin(); sessionActive = true
        status = "正在准备语音输入"
        let prepared: (Bool) -> Void = { [weak self] success in
            guard let self, self.generation == token, self.sessionActive, !self.finishing else { return }
            guard success else { self.cancel(message: "未能确认遥控器输入，语音未开始。"); return }
            self.startPreparedVoice(token: token)
        }
        if let prepareInput { prepareInput(prepared) } else { prepared(true) }
        return sessionActive
    }
    private func startPreparedVoice(token: UInt64) {
        guard !stopped, isReady, canStart?() == true else { cancel(message: "语音键已松开或音频链路已失效。"); return }
        preparingInput = false
        guard onBegin?() == true else { cancel(message: "无法发送语音触发键。"); return }
        write(preroll.take(), token: token)
        guard bluetooth.open() else { invalidateOutput("无法打开遥控器麦克风。"); return }
        status = "正在接收遥控器语音"
        startTimeout?.cancel()
        startTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, self.generation == token, self.sessionActive, self.receivedSamples == 0 else { return }
            self.invalidateOutput("遥控器尚未传来音频，已结束本次语音。")
        }
    }
    public func release() {
        guard sessionActive, !finishing else { return }
        if preparingInput { cancel(message: "语音键已松开，已取消等待输入切换。"); return }
        finishing = true; _ = bluetooth.close(); startTimeout?.cancel()
        let token = generation
        tail?.cancel()
        tail = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            guard let self, self.generation == token, self.sessionActive else { return }
            self.draining = true
            self.writer.finish { [weak self] completed in
                Task { @MainActor in
                    guard let self, self.generation == token, self.sessionActive else { return }
                    self.sessionActive = false; self.finishing = false; self.draining = false
                    self.onEnd?()
                    self.status = completed ? "语音已结束" : "语音输出排空超时，已释放触发键"
                }
            }
        }
    }
    private func receive(_ packet: Data) {
        guard sessionActive, !draining, protocolStarted || allowEarlyAudio else { return }
        receivedPackets += 1; lastPacketAt = clock()
        do {
            let samples = try decoder.append(packet)
            guard !samples.isEmpty else { return }
            receivedSamples += samples.count
            if let low = samples.min(), let high = samples.max() { signalChanging = Int(high) - Int(low) > 64 }
            protocolStarted = true
            if preparingInput { try preroll.append(samples); return }
            let token = generation
            write(samples, token: token)
        } catch LoopbackFailure.overflow {
            cancel(message: "等待输入切换过久，语音缓存已满，请松开后重试。")
        } catch { invalidateOutput("遥控器音频帧无效，请重新连接音频。") }
    }
    private func checkOutputHealth() {
        guard !checkingHealth else { return }
        checkingHealth = true
        let route = routeGeneration; let session = generation
        writer.checkHealth { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.checkingHealth = false
                guard !self.stopped, self.routeGeneration == route else { return }
                switch result {
                case .failure(let error): self.invalidateOutput(error.localizedDescription)
                case .success(let output):
                    if self.isReady { self.recovery.observeHealthy(at: self.clock()) }
                    guard self.generation == session else { return }
                    var value = VoiceStreamProgress()
                    value.packets = self.receivedPackets; value.decodedSamples = self.receivedSamples
                    value.secondsSincePacket = self.lastPacketAt.map { max(0, Int(self.clock() - $0)) }
                    value.signalChanging = self.signalChanging; value.output = output
                    if value != self.progress { self.progress = value }
                }
            }
        }
    }
    private func write(_ samples: [Int16], token: UInt64) {
        guard !samples.isEmpty else { return }
        writer.append(samples) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.invalidateOutput(error.localizedDescription)
            }
        }
    }
    private func invalidateOutput(_ message: String) {
        guard !stopped else { return }
        routeGeneration &+= 1; configuring = false
        // Release the synthetic trigger and restore input before readiness observers run.
        cancel(message: message)
        outputReady = false; isReady = false
        stopTransport(); writer.stop()
        recovery.failed(at: clock())
        let suffix = recovery.exhausted ? "自动恢复已达3次，请唤醒遥控器后重新连接。" : "正在等待自动恢复，请松开语音键。"
        outputStatus = message
        status = message + " " + suffix
    }
    public func cancel(message: String? = nil) {
        generation &+= 1; tail?.cancel(); startTimeout?.cancel()
        let wasActive = sessionActive
        sessionActive = false; finishing = false; draining = false; testingTone = false
        preparingInput = false; preroll.clear()
        if wasActive { _ = bluetooth.close() }
        writer.cancel(); try? decoder.reset()
        if wasActive { onEnd?() }
        if wasActive && message == nil { status = "语音已取消" }
        if let message { status = message }
    }
    public func playTestTone() {
        guard outputReady, !sessionActive, !testingTone else { return }
        testingTone = true; generation &+= 1; let token = generation
        writer.begin()
        let samples: [Int16] = (0..<6400).map { Int16(sin(Double($0) * 2 * .pi * 440 / 16000) * 2600) }
        writer.append(samples) { [weak self] error in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let error { self.invalidateOutput(error.localizedDescription); return }
                self.writer.finish { [weak self] completed in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        self.testingTone = false
                        self.outputStatus = completed ? "测试音已写入所选回环设备" : "测试音已中断"
                    }
                }
            }
        }
    }
    public func shutdown() {
        stopped = true; timer?.invalidate(); timer = nil
        cancel(); stopTransport(); writer.stop()
        outputReady = false; bluetoothReady = false; isReady = false
    }
}
