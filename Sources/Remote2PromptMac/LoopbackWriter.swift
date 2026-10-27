import AVFAudio
import AudioToolbox
import CoreAudio
import Foundation

public enum LoopbackFailure: Error, LocalizedError, Sendable {
    case unavailable, configure(Int32), overflow, notReady
    public var errorDescription: String? {
        switch self {
        case .unavailable: "所选回环设备不可用，请检查 MiRemoteV 2ch 或 BlackHole 2ch。"
        case .configure(let code): "无法打开所选回环设备（\(code)）。"
        case .overflow: "音频队列已满，语音会话已停止。"
        case .notReady: "请先选择并连接回环设备。"
        }
    }
}

/// All engine state belongs to this serial queue. No default input/output property is ever written.
public final class LoopbackWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.remote2prompt.audio-output", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var deviceUID: String?
    private var pending = 0
    private var generation: UInt64 = 0
    private var drained: (@Sendable (Bool) -> Void)?
    private let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    public init() {}

    public func configure(uid: String?, completion: @escaping @Sendable (Result<Void, LoopbackFailure>) -> Void) {
        queue.async { [self] in
            tearDown()
            guard let uid else { completion(.failure(.notReady)); return }
            guard var device = LoopbackDevices.resolve(uid) else { completion(.failure(.unavailable)); return }
            let value = AVAudioEngine()
            guard let unit = value.outputNode.audioUnit else { completion(.failure(.notReady)); return }
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, UInt32(MemoryLayout<AudioDeviceID>.size))
            guard status == noErr else { completion(.failure(.configure(status))); return }
            let node = AVAudioPlayerNode()
            value.attach(node)
            value.connect(node, to: value.mainMixerNode, format: format)
            do {
                value.prepare(); try value.start(); node.play()
                engine = value; player = node; deviceUID = uid
                completion(.success(()))
            } catch { value.stop(); completion(.failure(.configure((error as NSError).code.int32))) }
        }
    }
    public func begin() {
        queue.async { [self] in
            generation &+= 1; drained?(false); drained = nil; pending = 0
            player?.stop(); player?.play()
        }
    }
    public func append(_ samples: [Int16], completion: @escaping @Sendable (LoopbackFailure?) -> Void) {
        queue.async { [self] in
            guard let node = player, let uid = deviceUID, LoopbackDevices.resolve(uid) != nil else { completion(.unavailable); return }
            guard pending + samples.count <= 32000 else { tearDown(); completion(.overflow); return }
            guard !samples.isEmpty else { completion(nil); return }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)), let data = buffer.floatChannelData?[0] else { completion(.notReady); return }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            for (index, sample) in samples.enumerated() { data[index] = Float(sample) / 32768 }
            let token = generation
            let sampleCount = samples.count
            pending += sampleCount
            node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard self.generation == token else { return }
                    self.pending = max(0, self.pending - sampleCount)
                    if self.pending == 0 { let done = self.drained; self.drained = nil; done?(true) }
                }
            }
            completion(nil)
        }
    }
    public func finish(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            if pending == 0 { completion(true); return }
            drained?(false); drained = completion
            let token = generation
            queue.asyncAfter(deadline: .now() + 1) { [self] in
                guard generation == token, let done = drained else { return }
                drained = nil; generation &+= 1; pending = 0
                player?.stop(); player?.play(); done(false)
            }
        }
    }
    public func cancel() { begin() }
    public func stop(completion: (@Sendable () -> Void)? = nil) { queue.async { [self] in tearDown(); completion?() } }
    private func tearDown() {
        generation &+= 1; pending = 0; let done = drained; drained = nil
        player?.stop(); engine?.stop(); player = nil; engine = nil; deviceUID = nil
        done?(false)
    }
}

private extension Int {
    var int32: Int32 { Int32(clamping: self) }
}
