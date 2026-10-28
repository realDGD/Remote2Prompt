import AudioToolbox
import Foundation

/// Explicit-device output, independent of AVAudioEngine's default input/output graph.
/// Audio Queue converts 16 kHz mono PCM to the chosen device's format. It never captures input.
final class AudioQueueLoopbackPlayback: LoopbackPlayback, @unchecked Sendable {
    private var output: AudioQueueRef?
    private var deviceUID: String?
    private var started = false
    private var beginFailure: LoopbackFailure?
    private let callbacks = Callbacks()

    // Audio Queue owns its callback thread. Dispose synchronously before releasing this context.
    private final class Callbacks: @unchecked Sendable {
        private let lock = NSLock()
        private var consumed: [UInt: @Sendable () -> Void] = [:]
        private var drained: (@Sendable (Bool) -> Void)?
        private var changed: (@Sendable () -> Void)?
        func observe(_ callback: (@Sendable () -> Void)?) { lock.withLock { changed = callback } }
        func notifyChange() { let callback = lock.withLock { changed }; callback?() }
        func add(_ buffer: AudioQueueBufferRef, _ done: @escaping @Sendable () -> Void) {
            lock.withLock { consumed[UInt(bitPattern: buffer)] = done }
        }
        func take(_ buffer: AudioQueueBufferRef) -> (@Sendable () -> Void)? {
            lock.withLock { consumed.removeValue(forKey: UInt(bitPattern: buffer)) }
        }
        func waitForStop(_ callback: @escaping @Sendable (Bool) -> Void) { lock.withLock { drained = callback } }
        func completeDrain(_ success: Bool) {
            let callback = lock.withLock { let value = drained; drained = nil; return value }
            callback?(success)
        }
        func discard() {
            lock.withLock { consumed.removeAll() }
            completeDrain(false)
        }
    }
    private static let propertyChanged: AudioQueuePropertyListenerProc = { context, queue, property in
        guard let context else { return }
        let callbacks = Unmanaged<Callbacks>.fromOpaque(context).takeUnretainedValue()
        if property == kAudioQueueProperty_CurrentDevice { callbacks.notifyChange() }
        else if let running = running(queue), !running { callbacks.completeDrain(true) }
    }
    private static func running(_ queue: AudioQueueRef) -> Bool? {
        var value: UInt32 = 0; var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &value, &size) == noErr ? value != 0 : nil
    }
    func configure(uid: String, configurationChanged: @escaping @Sendable () -> Void) throws(LoopbackFailure) {
        stop()
        guard LoopbackDevices.resolve(uid) != nil else { throw .unavailable }
        var format = AudioStreamBasicDescription(mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
            mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var queue: AudioQueueRef?
        let context = Unmanaged.passUnretained(callbacks).toOpaque()
        let created = AudioQueueNewOutput(&format, { context, queue, buffer in
            guard let context else { return }
            let callbacks = Unmanaged<Callbacks>.fromOpaque(context).takeUnretainedValue()
            let done = callbacks.take(buffer)
            AudioQueueFreeBuffer(queue, buffer)
            done?()
        }, context, nil, nil, 0, &queue)
        guard created == noErr, let queue else { throw .configure(created) }
        output = queue
        var selected = uid as CFString
        let bound = withUnsafePointer(to: &selected) {
            AudioQueueSetProperty(queue, kAudioQueueProperty_CurrentDevice, $0, UInt32(MemoryLayout<CFString>.size))
        }
        guard bound == noErr else { stop(); throw .configure(bound) }
        deviceUID = uid
        callbacks.observe(configurationChanged)
        for property in [kAudioQueueProperty_CurrentDevice, kAudioQueueProperty_IsRunning] {
            let status = AudioQueueAddPropertyListener(queue, property, Self.propertyChanged, context)
            guard status == noErr else { stop(); throw .configure(status) }
        }
        try validateRoute()
    }
    func begin() {
        callbacks.discard()
        beginFailure = nil; started = false
        if let output {
            let status = AudioQueueStop(output, true)
            if status != noErr { beginFailure = .configure(status) }
        }
    }
    func validateRoute() throws(LoopbackFailure) {
        guard let output, let uid = deviceUID, LoopbackDevices.resolve(uid) != nil else { throw .unavailable }
        var actual: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &actual) {
            AudioQueueGetProperty(output, kAudioQueueProperty_CurrentDevice, $0, &size)
        }
        guard status == noErr else { throw .configure(status) }
        // Never continue on the system output if the explicitly chosen virtual device is lost.
        guard actual as String? == uid else { throw .unavailable }
    }
    func append(_ samples: [Int16], consumed: @escaping @Sendable () -> Void) throws(LoopbackFailure) {
        if let beginFailure { throw beginFailure }
        try validateRoute()
        guard let output else { throw .notReady }
        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        var buffer: AudioQueueBufferRef?
        let allocated = AudioQueueAllocateBuffer(output, byteCount, &buffer)
        guard allocated == noErr, let buffer else { throw .configure(allocated) }
        samples.withUnsafeBytes { data in
            buffer.pointee.mAudioData.copyMemory(from: data.baseAddress!, byteCount: Int(byteCount))
        }
        buffer.pointee.mAudioDataByteSize = byteCount
        callbacks.add(buffer, consumed)
        let queued = AudioQueueEnqueueBuffer(output, buffer, 0, nil)
        guard queued == noErr else {
            _ = callbacks.take(buffer); AudioQueueFreeBuffer(output, buffer); throw .configure(queued)
        }
        if !started {
            let status = AudioQueueStart(output, nil)
            guard status == noErr else { throw .configure(status) }
            started = true
        }
    }
    func finish(completion: @escaping @Sendable (Bool) -> Void) {
        guard let output else { completion(false); return }
        guard started else { completion(beginFailure == nil); return }
        callbacks.waitForStop(completion)
        // Buffer reuse callbacks only prove consumption. IsRunning==false confirms actual playback end.
        let status = AudioQueueStop(output, false)
        started = false
        guard status == noErr else { callbacks.completeDrain(false); return }
        if let running = Self.running(output) {
            if !running { callbacks.completeDrain(true) }
        } else { callbacks.completeDrain(false) }
    }
    func stop() {
        callbacks.observe(nil); callbacks.discard()
        if let output {
            let context = Unmanaged.passUnretained(callbacks).toOpaque()
            for property in [kAudioQueueProperty_CurrentDevice, kAudioQueueProperty_IsRunning] {
                AudioQueueRemovePropertyListener(output, property, Self.propertyChanged, context)
            }
            AudioQueueDispose(output, true)
        }
        output = nil; deviceUID = nil; started = false; beginFailure = nil
    }
    deinit { stop() }
}
