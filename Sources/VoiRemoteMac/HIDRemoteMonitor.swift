import Foundation
import IOKit.hid
import VoiRemoteCore

public struct HIDOpenFailure: Error, LocalizedError {
    public let code: IOReturn
    public var errorDescription: String? {
        "系统拒绝打开遥控器（\(code)）。请检查输入监控授权，或退出占用设备的软件后重试。"
    }
}

private func remoteAdded(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ device: IOHIDDevice) {
    guard let context else { return }
    let monitor = Unmanaged<HIDRemoteMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { monitor.rescan(result: result) }
}
private func remoteRemoved(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ device: IOHIDDevice) {
    guard let context else { return }
    let monitor = Unmanaged<HIDRemoteMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { monitor.rescan(result: result) }
}
private func remoteReport(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ type: IOHIDReportType, _ id: UInt32, _ report: UnsafeMutablePointer<UInt8>, _ length: CFIndex) {
    guard let context, let sender else { return }
    let monitor = Unmanaged<HIDRemoteMonitor>.fromOpaque(context).takeUnretainedValue()
    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
    guard let deviceID = remoteRegistryID(device) else { return }
    let bytes = Array(UnsafeBufferPointer(start: report, count: max(0, min(length, 64))))
    MainActor.assumeIsolated {
        monitor.received(deviceID, result: result, reportID: id, bytes: bytes)
    }
}

private func remoteRegistryID(_ device: IOHIDDevice) -> UInt64? {
    var id: UInt64 = 0
    return IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == KERN_SUCCESS ? id : nil
}

/// Nonexclusive raw-report reader. NativeKeyLease must be verified before start; no event-tap fallback.
@MainActor
public final class HIDRemoteMonitor {
    public var onReport: ((String, Set<UInt16>) -> Void)?
    public var onDisconnect: ((String) -> Void)?
    public var onDevicesChanged: (() -> Void)?
    public var onFailure: ((String) -> Void)?
    private var manager: IOHIDManager?
    private var devices: [UInt64: IOHIDDevice] = [:]
    private var locations: [UInt64: UInt64] = [:]
    public var deviceCount: Int { devices.count }
    public init() {}

    public static func discoverCount() -> Int {
        // Metadata only: IOHIDDeviceCreate can instantiate a plug-in/user client before authorization.
        guard let query = IOServiceMatching("IOHIDDevice") else { return 0 }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, query, &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }
        var count = 0
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            func number(_ key: String) -> Int? {
                (IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
            }
            if number(kIOHIDVendorIDKey) == XiaomiRemote.vendorID,
               number(kIOHIDProductIDKey) == XiaomiRemote.productID,
               number(kIOHIDPrimaryUsagePageKey) == 1, number(kIOHIDPrimaryUsageKey) == 6 { count += 1 }
        }
        return count
    }
    private static var matching: CFDictionary {
        [kIOHIDVendorIDKey: XiaomiRemote.vendorID, kIOHIDProductIDKey: XiaomiRemote.productID,
         kIOHIDPrimaryUsagePageKey: 1, kIOHIDPrimaryUsageKey: 6] as CFDictionary
    }

    public func start() throws {
        stop()
        let value = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = value
        IOHIDManagerSetDeviceMatching(value, Self.matching)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(value, remoteAdded, context)
        IOHIDManagerRegisterDeviceRemovalCallback(value, remoteRemoved, context)
        IOHIDManagerRegisterInputReportCallback(value, remoteReport, context)
        IOHIDManagerScheduleWithRunLoop(value, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(value, 0)
        if result != kIOReturnSuccess { stop(); throw HIDOpenFailure(code: result) }
    }

    public func stop() {
        guard let value = manager else { return }
        manager = nil
        IOHIDManagerRegisterInputReportCallback(value, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(value, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(value, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(value, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(value, 0)
        devices.removeAll(); locations.removeAll()
    }

    fileprivate func rescan(result: IOReturn) {
        guard let manager, result == kIOReturnSuccess else { return }
        let previous = Set(devices.keys)
        let current = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        devices.removeAll(); locations.removeAll()
        for device in current {
            guard let id = remoteRegistryID(device) else { continue }
            let location = (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.uint64Value
            if let location, location != 0, locations.values.contains(location) { continue }
            devices[id] = device
            locations[id] = location == 0 ? nil : location
        }
        for id in previous.subtracting(devices.keys) { onDisconnect?(String(id)) }
        onDevicesChanged?()
    }
    fileprivate func received(_ id: UInt64, result: IOReturn, reportID: UInt32, bytes: [UInt8]) {
        guard manager != nil, devices[id] != nil else { return }
        guard result == kIOReturnSuccess else { onFailure?("读取遥控器按键失败，已停止接管。"); return }
        guard reportID == 1 else { return }
        guard let usages = XiaomiRemote.usages(reportID: reportID, bytes: bytes) else {
            onFailure?("遥控器按键报告格式不受支持，已停止接管。"); return
        }
        onReport?(String(id), usages)
    }
}
