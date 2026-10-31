import Darwin
import Foundation
import IOKit.hid
import IOKit.hidsystem
import VoiRemoteCore

public struct UsageMapping: Codable, Equatable {
    public let source: UInt64
    public let destination: UInt64
    public init(source: UInt64, destination: UInt64) { self.source = source; self.destination = destination }
}

@MainActor
public struct HIDMappingService {
    public let id: UInt64
    public let read: () throws -> [UsageMapping]
    public let write: ([UsageMapping]) -> Bool
    private let retainedOwner: AnyObject?
    public init(id: UInt64, retainedOwner: AnyObject? = nil, read: @escaping () throws -> [UsageMapping], write: @escaping ([UsageMapping]) -> Bool) {
        self.id = id; self.retainedOwner = retainedOwner; self.read = read; self.write = write
    }
}

public enum MappingFailure: Error, LocalizedError {
    case noService, invalidProperty, writeFailed, recoveryFailed, unavailableBootSession
    public var errorDescription: String? {
        switch self {
        case .noService: "没有发现可接管的小米遥控器键盘服务。"
        case .invalidProperty: "设备的原生按键配置格式无法验证。"
        case .writeFailed: "原生按键抑制未通过读回验证，已停止接管。"
        case .recoveryFailed: "部分原生按键配置尚未恢复，请保持设备连接并点击重试恢复。"
        case .unavailableBootSession: "无法建立本次系统启动的恢复记录，未修改设备。"
        }
    }
}

/// Owns only its neutralized sources. A journal is committed before the first device write.
@MainActor
public final class NativeKeyLease {
    private struct Journal: Codable {
        let version: Int
        let boot: Int64
        var originals: [String: [UsageMapping]]
        var sources: [UInt64]?
    }
    public static let ownedSources: Set<UInt64> = Set(
        (Array(XiaomiRemote.buttonUsages.keys) + [XiaomiRemote.voiceUsage]).map { UInt64(7) << 32 | UInt64($0) }
        + [0xE9, 0xEA, 0xE2, 0x30].map { UInt64(12) << 32 | UInt64($0) }
    )
    private let services: () throws -> [HIDMappingService]
    private let url: URL
    private var journal: Journal

    public init(url: URL, boot: Int64, services: @escaping () throws -> [HIDMappingService]) throws {
        self.url = url; self.services = services
        if FileManager.default.fileExists(atPath: url.path) {
            let saved = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url))
            guard (1...2).contains(saved.version) else { throw MappingFailure.invalidProperty }
            journal = saved.boot == boot ? Journal(version: 2, boot: boot, originals: saved.originals, sources: saved.sources) : Journal(version: 2, boot: boot, originals: [:])
        } else { journal = Journal(version: 2, boot: boot, originals: [:]) }
    }

    public var hasPendingRecovery: Bool { !journal.originals.isEmpty }

    public func verifyCoverage() throws -> Bool {
        let current = try services()
        guard !current.isEmpty else { return false }
        for service in current {
            guard journal.originals[String(service.id)] != nil else { return false }
            let mappings = try service.read()
            try validate(mappings)
            let neutral = Set(mappings.filter { $0.destination == 0 }.map(\.source))
            guard owned.isSubset(of: neutral) else { return false }
        }
        return true
    }

    private var owned: Set<UInt64> { Set(journal.sources ?? Array(Self.ownedSources)) }

    public func acquire(sources: Set<UInt64> = NativeKeyLease.ownedSources) throws {
        try restore()
        guard !sources.isEmpty, sources.isSubset(of: Self.ownedSources) else { throw MappingFailure.invalidProperty }
        journal.sources = sources.sorted()
        let targets = try services()
        guard !targets.isEmpty else { throw MappingFailure.noService }
        var before: [UInt64: [UsageMapping]] = [:]
        for service in targets {
            let mappings = try service.read()
            try validate(mappings)
            before[service.id] = mappings
            journal.originals[String(service.id)] = mappings.filter { owned.contains($0.source) }
        }
        try persist()
        do {
            for service in targets {
                let desired = (before[service.id] ?? []).filter { !owned.contains($0.source) }
                    + owned.sorted().map { UsageMapping(source: $0, destination: 0) }
                guard service.write(desired), try equivalent(service.read(), desired) else { throw MappingFailure.writeFailed }
            }
        } catch {
            try restore()
            throw error
        }
    }

    public func restore() throws {
        guard hasPendingRecovery else { return }
        let available = try services()
        var pending: [String: [UsageMapping]] = [:]
        for (id, original) in journal.originals {
            // A removed service no longer carries these transient HID properties.
            guard let service = available.first(where: { String($0.id) == id }) else { continue }
            do {
                let current = try service.read()
                try validate(current)
                let stillOwned = Set(current.filter { owned.contains($0.source) && $0.destination == 0 }.map(\.source))
                let desired = current.filter { !stillOwned.contains($0.source) } + original.filter { stillOwned.contains($0.source) }
                guard service.write(desired), try equivalent(service.read(), desired) else { throw MappingFailure.recoveryFailed }
            } catch { pending[id] = original }
        }
        journal.originals = pending
        try persist()
        if hasPendingRecovery { throw MappingFailure.recoveryFailed }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(journal).write(to: url, options: .atomic)
    }
    private func validate(_ mappings: [UsageMapping]) throws {
        guard Set(mappings.map(\.source)).count == mappings.count else { throw MappingFailure.invalidProperty }
    }
    private func equivalent(_ lhs: [UsageMapping], _ rhs: [UsageMapping]) throws -> Bool {
        try validate(lhs); try validate(rhs)
        return Dictionary(uniqueKeysWithValues: lhs.map { ($0.source, $0.destination) })
            == Dictionary(uniqueKeysWithValues: rhs.map { ($0.source, $0.destination) })
    }

    public static func system() throws -> NativeKeyLease {
        var boot = timeval(); var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { throw MappingFailure.unavailableBootSession }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return try NativeKeyLease(url: directory.appendingPathComponent("VoiRemote/HIDRecovery.json"), boot: Int64(boot.tv_sec), services: systemServices)
    }

    public static func systemServices() -> [HIDMappingService] {
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        let all = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return all.compactMap { service in
            let vendor = IOHIDServiceClientCopyProperty(service, "VendorID" as CFString) as? NSNumber
            let product = IOHIDServiceClientCopyProperty(service, "ProductID" as CFString) as? NSNumber
            guard vendor?.intValue == XiaomiRemote.vendorID, product?.intValue == XiaomiRemote.productID,
                  let id = (IOHIDServiceClientGetRegistryID(service) as? NSNumber)?.uint64Value else { return nil }
            return HIDMappingService(id: id, retainedOwner: client, read: {
                guard let value = IOHIDServiceClientCopyProperty(service, "UserKeyMapping" as CFString) else { return [] }
                guard let array = value as? [[String: NSNumber]] else { throw MappingFailure.invalidProperty }
                return try array.map {
                    guard let src = $0["HIDKeyboardModifierMappingSrc"], let dst = $0["HIDKeyboardModifierMappingDst"] else { throw MappingFailure.invalidProperty }
                    return UsageMapping(source: src.uint64Value, destination: dst.uint64Value)
                }
            }, write: { mappings in
                let properties = mappings.map { ["HIDKeyboardModifierMappingSrc": NSNumber(value: $0.source), "HIDKeyboardModifierMappingDst": NSNumber(value: $0.destination)] }
                return IOHIDServiceClientSetProperty(service, "UserKeyMapping" as CFString, properties as CFArray)
            })
        }
    }
}
