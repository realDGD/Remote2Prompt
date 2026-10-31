import IOKit.hid
import Foundation
import Security

public enum IOHIDPermission {
    public static var controlPermissionTitle: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "设备控制和数据访问" : "辅助功能"
    }
    public static var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    public static func runningCodeIsCurrent() -> Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        return SecCodeCheckValidity(code, [], nil) == errSecSuccess
    }
}
