import CoreAudio
import Foundation
import Remote2PromptCore

public struct SystemAudioInput: Equatable, Sendable {
    public let policy: AudioInput
    public let name: String
    public init(policy: AudioInput, name: String) { self.policy = policy; self.name = name }
}

public struct SystemInputSnapshot: Equatable, Sendable {
    public var inputs: [SystemAudioInput]
    public var defaultUID: String?
    public init(inputs: [SystemAudioInput], defaultUID: String?) { self.inputs = inputs; self.defaultUID = defaultUID }
    public func name(for uid: String?) -> String? { inputs.first { $0.policy.uid == uid }?.name }
}

public enum InputSystemFailure: Error, LocalizedError {
    case property(Int32), unavailable, defaultChanged, notSettable
    public var errorDescription: String? {
        switch self {
        case .property(let status): "系统音频属性操作失败（\(status)）。"
        case .unavailable: "输入设备已失效或不符合切换条件。"
        case .defaultChanged: "系统输入刚刚改变，正在重新读取。"
        case .notSettable: "系统默认输入当前不可修改。"
        }
    }
}

@MainActor
public protocol AudioInputSystem: AnyObject {
    func start(onChange: @escaping @MainActor () -> Void) throws
    func snapshot() throws -> SystemInputSnapshot
    func setDefaultInput(_ request: InputPriorityRequest) throws
    func stop()
}

/// Owns CoreAudio listeners and the only system-default write path (voice policy or explicit menu choice).
/// Never opens an input stream.
@MainActor
public final class CoreAudioInputSystem: AudioInputSystem {
    private struct Listener {
        let object: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    private struct Device {
        let id: AudioDeviceID
        let input: SystemAudioInput
    }
    private var listeners: [Listener] = []
    private var watchedDevices: Set<AudioDeviceID> = []
    private var callback: (@MainActor () -> Void)?
    private var generation: UInt64 = 0
    private var running = false
    public var listenerCount: Int { listeners.count }
    public init() {}

    public func start(onChange: @escaping @MainActor () -> Void) throws {
        stop(); generation &+= 1; running = true; callback = onChange
        do {
            try addListener(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
            try addListener(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices)
            try synchronizeListeners(deviceIDs())
        } catch { stop(); throw error }
    }

    public func snapshot() throws -> SystemInputSnapshot {
        let ids = try deviceIDs()
        if running { try synchronizeListeners(ids) }
        let inputs = ids.compactMap { try? device($0) }.map(\.input).sorted { $0.policy.uid < $1.policy.uid }
        return SystemInputSnapshot(inputs: inputs, defaultUID: try currentUID())
    }

    public func setDefaultInput(_ request: InputPriorityRequest) throws {
        guard running else { throw InputSystemFailure.unavailable }
        let candidates = try deviceIDs().compactMap { try? device($0) }
        guard let target = candidates.first(where: { $0.input.policy.uid == request.targetUID }),
              request.purpose == .prioritize ? target.input.policy.supportsPriority : true else {
            throw InputSystemFailure.unavailable
        }
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
        var settable = DarwinBoolean(false)
        try check(AudioObjectIsPropertySettable(AudioObjectID(kAudioObjectSystemObject), &address, &settable))
        guard settable.boolValue else { throw InputSystemFailure.notSettable }
        // CoreAudio has no atomic compare-and-set. Re-resolve the target and check the source immediately before writing.
        guard try currentUID() == request.sourceUID else { throw InputSystemFailure.defaultChanged }
        var id = target.id
        try check(AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id))
    }

    public func stop() {
        running = false; generation &+= 1; callback = nil
        for var listener in listeners {
            _ = AudioObjectRemovePropertyListenerBlock(listener.object, &listener.address, .main, listener.block)
        }
        listeners.removeAll(); watchedDevices.removeAll()
    }

    public static func kind(transport: UInt32) -> AudioInput.Kind {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn, kAudioDeviceTransportTypePCI, kAudioDeviceTransportTypeUSB,
             kAudioDeviceTransportTypeFireWire, kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE,
             kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeThunderbolt:
            .physical
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate, kAudioDeviceTransportTypeAutoAggregate:
            .virtual
        default: .unknown
        }
    }

    private func synchronizeListeners(_ ids: [AudioDeviceID]) throws {
        let current = Set(ids)
        let removed = watchedDevices.subtracting(current)
        for var listener in listeners where removed.contains(listener.object) {
            _ = AudioObjectRemovePropertyListenerBlock(listener.object, &listener.address, .main, listener.block)
        }
        listeners.removeAll { removed.contains($0.object) }
        watchedDevices.subtract(removed)
        for id in current.subtracting(watchedDevices) {
            let start = listeners.count
            do {
                try addListener(id, kAudioDevicePropertyDeviceIsAlive)
                try addListener(id, kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
                try addListener(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: kAudioDevicePropertyScopeInput)
                try addListener(id, kAudioDevicePropertyTransportType)
                watchedDevices.insert(id)
            } catch {
                for var listener in listeners.dropFirst(start) {
                    _ = AudioObjectRemovePropertyListenerBlock(listener.object, &listener.address, .main, listener.block)
                }
                listeners.removeSubrange(start...)
                throw error
            }
        }
    }

    private func addListener(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws {
        var address = Self.address(selector, scope: scope)
        // Output-only devices may not expose input-scoped properties; periodic snapshots cover those drivers.
        if object != AudioObjectID(kAudioObjectSystemObject), !AudioObjectHasProperty(object, &address) { return }
        let token = generation
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.running, self.generation == token else { return }
                self.callback?()
            }
        }
        try check(AudioObjectAddPropertyListenerBlock(object, &address, .main, block))
        listeners.append(Listener(object: object, address: address, block: block))
    }

    private func device(_ id: AudioDeviceID) throws -> Device? {
        guard try uint32(id, kAudioDevicePropertyDeviceIsAlive) != 0,
              try channels(id, scope: kAudioDevicePropertyScopeInput) > 0,
              try uint32(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: kAudioDevicePropertyScopeInput) != 0 else { return nil }
        let uid = try string(id, kAudioDevicePropertyDeviceUID)
        let transport = try uint32(id, kAudioDevicePropertyTransportType)
        let known = LoopbackDevices.supportedUIDs.contains(uid)
        let classification: AudioInput.Kind = known ? .virtual : Self.kind(transport: transport)
        let eligible = try known && channels(id, scope: kAudioDevicePropertyScopeInput) >= 2 && channels(id, scope: kAudioDevicePropertyScopeOutput) >= 2
        return Device(id: id, input: SystemAudioInput(policy: AudioInput(uid: uid, kind: classification, supportsPriority: eligible), name: try string(id, kAudioObjectPropertyName)))
    }

    private func currentUID() throws -> String? {
        let id = try uint32(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
        return id == kAudioObjectUnknown ? nil : try string(id, kAudioDevicePropertyDeviceUID)
    }
    private func deviceIDs() throws -> [AudioDeviceID] {
        var address = Self.address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        guard size >= MemoryLayout<AudioDeviceID>.size else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        try ids.withUnsafeMutableBytes { data in
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, data.baseAddress!))
        }
        return ids
    }
    private func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> UInt32 {
        var address = Self.address(selector, scope: scope)
        var value: UInt32 = 0; var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value))
        return value
    }
    private func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var address = Self.address(selector)
        var value: CFString?; var size = UInt32(MemoryLayout<CFString?>.size)
        try withUnsafeMutablePointer(to: &value) {
            try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, UnsafeMutableRawPointer($0)))
        }
        guard let value, !(value as String).isEmpty else { throw InputSystemFailure.unavailable }
        return value as String
    }
    private func channels(_ id: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var address = Self.address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size))
        guard size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { data.deallocate() }
        try check(AudioObjectGetPropertyData(id, &address, 0, nil, &size, data))
        return UnsafeMutableAudioBufferListPointer(data.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    private func check(_ status: OSStatus) throws { if status != noErr { throw InputSystemFailure.property(status) } }
}
