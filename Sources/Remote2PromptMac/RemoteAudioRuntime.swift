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
    public var canStart: (() -> Bool)?
    public var prepareInput: ((@escaping (Bool) -> Void) -> Void)?
    public var onBegin: (() -> Bool)?
    public var onEnd: (() -> Void)?
    private let writer = LoopbackWriter()
    private let bluetooth = RemoteVoiceBluetooth()
    private var configuration = AppConfiguration()
    private var decoder = try! RemoteVoiceDecoder(frameBytes: 120)
    private var outputReady = false
    private var bluetoothReady = false
    private var configuring = false
    private var routeFailures = 0
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

    public init(hardwareEnabled: Bool = true) {
        self.hardwareEnabled = hardwareEnabled
        guard hardwareEnabled else { return }
        bluetooth.onStatus = { [weak self] value in self?.status = value }
        bluetooth.onFailure = { [weak self] value in
            guard let self else { return }
            self.bluetoothReady = false; self.isReady = false; self.cancel(message: value)
        }
        bluetooth.onReady = { [weak self] capabilities in
            guard let self else { return }
            do { self.decoder = try RemoteVoiceDecoder(frameBytes: capabilities.frameBytes) }
            catch { self.cancel(message: "遥控器音频帧格式不受支持。"); return }
            self.bluetoothReady = true; self.updateReady()
        }
        // HID is the only start signal. A delayed ATVV open cannot start or retry a released session.
        bluetooth.onStarted = { [weak self] in
            guard let self else { return }
            if !self.sessionActive || self.finishing { _ = self.bluetooth.close() }
            else { self.protocolStarted = true }
        }
        bluetooth.onStopped = { [weak self] in
            guard let self, self.protocolStarted || self.finishing else { return }
            self.release()
        }
        bluetooth.onSync = { [weak self] data in
            guard let self, self.sessionActive, !self.draining, self.protocolStarted || self.allowEarlyAudio else { return }
            do { try self.decoder.synchronize(packet: data) }
            catch { self.invalidateOutput("遥控器音频同步数据无效，请重新连接音频。") }
        }
        bluetooth.onAudio = { [weak self] data in self?.receive(data) }
        refreshDevices()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDevices() }
        }
    }
    public func configure(_ value: AppConfiguration) {
        guard hardwareEnabled, !stopped else { return }
        let routeChanged = configuration.selectedVirtualInputUID != value.selectedVirtualInputUID
        let changed = routeChanged || configuration.remoteAudioEnabled != value.remoteAudioEnabled || configuration.voiceEnabled != value.voiceEnabled
        if changed { cancel() }
        configuration = value
        if routeChanged { bluetooth.stop(); bluetoothReady = false; routeFailures = 0; prepareOutput() }
        if !wanted {
            bluetooth.stop(); bluetoothReady = false; isReady = false
            status = "遥控器音频已关闭"
        } else { connectIfPossible() }
    }
    public func setRemoteCount(_ count: Int) {
        guard deviceCount != count else { return }
        deviceCount = count
        if count != 1, sessionActive { cancel(message: "遥控器数量变化，已结束语音。") }
        if count != 1, wanted { bluetooth.stop(); bluetoothReady = false; status = "语音音频需要恰好一只兼容遥控器" }
        updateReady(); connectIfPossible()
    }
    public func retry() {
        guard hardwareEnabled, !stopped else { return }
        cancel(); bluetooth.stop(); bluetoothReady = false; isReady = false
        routeFailures = 0; refreshDevices(); if !configuring { prepareOutput() }
    }
    public func refreshDevices() {
        guard hardwareEnabled, !stopped else { return }
        devices = LoopbackDevices.available()
        if let uid = configuration.selectedVirtualInputUID {
            if !devices.contains(where: { $0.uid == uid }) {
                if outputReady || configuring { routeGeneration &+= 1; configuring = false; writer.stop(); cancel(message: "所选回环设备已断开。"); bluetooth.stop(); bluetoothReady = false }
                outputReady = false; isReady = false; outputStatus = "所选设备当前不可用"
            } else if !outputReady && !configuring && routeFailures < 3 { prepareOutput() }
        }
    }
    private var wanted: Bool { configuration.remoteAudioEnabled && configuration.voiceEnabled }
    public var canTestTone: Bool { outputReady && !sessionActive && !testingTone }
    private func prepareOutput() {
        guard hardwareEnabled, !stopped else { return }
        routeGeneration &+= 1; let token = routeGeneration
        outputReady = false; isReady = false
        guard let uid = configuration.selectedVirtualInputUID else {
            writer.stop(); configuring = false; outputStatus = "未选择回环设备"; return
        }
        configuring = true; outputStatus = "正在打开所选回环设备"
        writer.configure(uid: uid) { [weak self] result in
            Task { @MainActor in
                guard let self, !self.stopped, self.routeGeneration == token else { return }
                self.configuring = false
                switch result {
                case .success:
                    self.outputReady = true; self.outputStatus = "所选回环设备已就绪"; self.routeFailures = 0
                    self.updateReady(); self.connectIfPossible()
                case .failure(let error):
                    self.routeFailures += 1; self.outputReady = false; self.outputStatus = error.localizedDescription
                    self.outputReady = false; self.isReady = false; self.outputStatus = error.localizedDescription
                    self.writer.stop(); self.cancel(message: error.localizedDescription)
                }
            }
        }
    }
    private func connectIfPossible() {
        guard wanted else { return }
        guard outputReady else { status = "请先选择可用的 MiRemoteV 2ch 或 BlackHole 2ch"; return }
        guard deviceCount == 1 else { status = "语音音频需要恰好一只兼容遥控器"; return }
        bluetooth.start()
    }
    private func updateReady() { isReady = wanted && outputReady && bluetoothReady && deviceCount == 1 }

    @discardableResult public func press() -> Bool {
        let interruptedTail = sessionActive && finishing
        if sessionActive && !finishing { return true }
        guard !stopped, isReady, canStart?() == true else {
            if !sessionActive {
                _ = bluetooth.close()
                if wanted { status = "请检查语音开关、设备连接和设备控制权限" }
            }
            return false
        }
        if interruptedTail { cancel() }
        generation &+= 1; let token = generation
        try? decoder.reset(); receivedSamples = 0; finishing = false; draining = false
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
        guard bluetooth.open() else { cancel(message: "无法打开遥控器麦克风。"); return }
        status = "正在接收遥控器语音"
        startTimeout?.cancel()
        startTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, self.generation == token, self.sessionActive, self.receivedSamples == 0 else { return }
            self.cancel(message: "遥控器尚未传来音频，请松开语音键后重试。")
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
        do {
            let samples = try decoder.append(packet)
            guard !samples.isEmpty else { return }
            receivedSamples += samples.count
            protocolStarted = true
            if preparingInput { try preroll.append(samples); return }
            let token = generation
            write(samples, token: token)
        } catch LoopbackFailure.overflow {
            cancel(message: "等待输入切换过久，语音缓存已满，请松开后重试。")
        } catch { invalidateOutput("遥控器音频帧无效，请重新连接音频。") }
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
        outputReady = false; bluetoothReady = false; isReady = false
        routeFailures = 3; outputStatus = message
        cancel(message: message); bluetooth.stop(); writer.stop()
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
        cancel(); bluetooth.stop(); writer.stop()
        outputReady = false; bluetoothReady = false; isReady = false
    }
}
