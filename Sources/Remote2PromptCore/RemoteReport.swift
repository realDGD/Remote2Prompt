/// Protocol constants for the Xiaomi RC001/RC003 keyboard interface. Names never authorize a device.
public enum XiaomiRemote {
    public static let vendorID = 0x2717
    public static let productID = 0x32B8
    public static let voiceUsage: UInt16 = 0x3E
    public static let buttonUsages: [UInt16: RemoteButton] = [
        0x52: .up, 0x51: .down, 0x50: .left, 0x4F: .right,
        0x28: .select, 0xF1: .back, 0x4A: .home, 0x65: .menu,
        0x35: .tv, 0x80: .volumeUp, 0x81: .volumeDown, 0x66: .power
    ]

    /// Report 1 contains three little-endian 16-bit usages, optionally prefixed by the report ID.
    /// Unknown usages remain in the snapshot; callers must not turn malformed reports into releases.
    public static func usages(reportID: UInt32, bytes: [UInt8]) -> Set<UInt16>? {
        guard reportID == 1 else { return nil }
        let payload: ArraySlice<UInt8>
        if bytes.count == 7 && bytes.first == 1 { payload = bytes.dropFirst() }
        else if bytes.count == 6 { payload = bytes[...] }
        else { return nil }
        let values = Array(payload)
        var result: Set<UInt16> = []
        for index in stride(from: 0, to: values.count, by: 2) {
            let usage = UInt16(values[index]) | UInt16(values[index + 1]) << 8
            if usage != 0 { result.insert(usage) }
        }
        return result
    }
}
