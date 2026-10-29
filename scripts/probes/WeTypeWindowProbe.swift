import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowSample: Codable, Equatable {
    let id: UInt32
    let pid: Int32
    let layer: Int
    let alpha: Double
    let frame: [Double]
}
struct ProbeLine: Encodable {
    let elapsed: Double
    let available: Bool
    let windows: [WindowSample]
}

// Deliberately omit window names, AX values, screenshots, recognized text and audio.
let duration = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 60
guard duration.isFinite, duration > 0, duration <= 300 else { exit(2) }
let start = ProcessInfo.processInfo.systemUptime
var previous: [WindowSample]?
var samples = 0
var unavailable = 0
let encoder = JSONEncoder()
while ProcessInfo.processInfo.systemUptime - start < duration {
    autoreleasepool {
        let owners = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.tencent.inputmethod.wetype").map(\.processIdentifier))
        let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        samples += 1
        if raw == nil { unavailable += 1 }
        let windows = (raw ?? []).compactMap { value -> WindowSample? in
            guard let pid = value[kCGWindowOwnerPID as String] as? Int32, owners.contains(pid),
                  let id = value[kCGWindowNumber as String] as? UInt32,
                  let bounds = value[kCGWindowBounds as String] as? [String: Double],
                  let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"] else { return nil }
            return WindowSample(id: id, pid: pid, layer: value[kCGWindowLayer as String] as? Int ?? -1,
                                alpha: value[kCGWindowAlpha as String] as? Double ?? -1,
                                frame: [x, y, w, h])
        }.sorted { $0.id < $1.id }
        if previous != windows || raw == nil {
            let line = ProbeLine(elapsed: ProcessInfo.processInfo.systemUptime - start, available: raw != nil, windows: windows)
            if let data = try? encoder.encode(line) {
                FileHandle.standardOutput.write(data + Data([10]))
            }
            previous = windows
        }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
FileHandle.standardError.write(Data("samples=\(samples) unavailable=\(unavailable) axTrusted=\(AXIsProcessTrusted())\n".utf8))
