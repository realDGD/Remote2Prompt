import CoreAudio
import Foundation

public struct LoopbackDevice: Identifiable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public var id: String { uid }
}

public struct AudioDefaultsSnapshot: Equatable, Sendable {
    fileprivate let input: AudioDeviceID
    fileprivate let output: AudioDeviceID
}

public enum LoopbackDevices {
    public static func defaultSnapshot() -> AudioDefaultsSnapshot? {
        func read(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: AudioDeviceID = 0; var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value) == noErr ? value : nil
        }
        guard let input = read(kAudioHardwarePropertyDefaultInputDevice), let output = read(kAudioHardwarePropertyDefaultOutputDevice) else { return nil }
        return AudioDefaultsSnapshot(input: input, output: output)
    }
    /// Exact driver UIDs, plus duplex channel validation. A display name alone never grants eligibility.
    public static func available() -> [LoopbackDevice] {
        devices().compactMap { id in
            guard let uid = string(id, kAudioDevicePropertyDeviceUID),
                  ["MiRemoteV2ch_UID", "BlackHole2ch_UID"].contains(uid),
                  channelCount(id, scope: kAudioDevicePropertyScopeInput) >= 2,
                  channelCount(id, scope: kAudioDevicePropertyScopeOutput) >= 2,
                  alive(id), let name = string(id, kAudioObjectPropertyName) else { return nil }
            return LoopbackDevice(uid: uid, name: name)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    static func resolve(_ uid: String) -> AudioDeviceID? {
        guard available().contains(where: { $0.uid == uid }) else { return nil }
        return devices().first { string($0, kAudioDevicePropertyDeviceUID) == uid }
    }
    private static func devices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        guard size >= MemoryLayout<AudioDeviceID>.size else { return [] }
        var result = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let status = result.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, buffer.baseAddress!)
        }
        return status == noErr ? result : []
    }
    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: CFString?; var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value as String?
    }
    private static func alive(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsAlive, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0; var size: UInt32 = 4
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr && value != 0
    }
    private static func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let data = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { data.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, data) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(data.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
