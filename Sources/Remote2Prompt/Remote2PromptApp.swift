import AppKit
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

@main
enum Launcher {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--version") {
            print("Remote2Prompt \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
            return
        }
        if CommandLine.arguments.contains("--self-check") {
            do {
                let configuration = AppConfiguration()
                guard try AppConfiguration.decode(configuration.encoded()) == configuration else { exit(1) }
                print("Remote2Prompt self-check passed (configuration only; no hardware access)")
            } catch {
                fputs("Remote2Prompt self-check failed: \(error)\n", stderr)
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--list-remotes") {
            print("Xiaomi RC001/RC003 keyboard interfaces: \(HIDRemoteMonitor.discoverCount())")
            print("Input monitoring: \(IOHIDPermission.inputMonitoringGranted)")
            return
        }
        if CommandLine.arguments.contains("--list-loopback-devices") {
            let devices = LoopbackDevices.available()
            print("Compatible loopback devices: \(devices.count)")
            for device in devices { print(device.name) }
            return
        }
        Remote2PromptApp.main()
    }
}

struct Remote2PromptApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var store = ConfigurationStore()
    @StateObject private var runtime = RemoteMappingRuntime(hardwareEnabled: !CommandLine.arguments.contains("--smoke-test") && !CommandLine.arguments.contains("--smoke-test-guide"))

    var body: some Scene {
        Window("Remote2Prompt", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .environmentObject(runtime)
                .onReceive(store.$configuration) { runtime.configure($0) }
        }
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Remote2Prompt", systemImage: "mic.badge.plus") {
            MenuContents()
                .environmentObject(store)
        }
    }
}

private struct MenuContents: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: ConfigurationStore

    var body: some View {
        Text("Remote2Prompt")
        Divider()
        Button("打开设置…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Button("运行设置向导…") {
            openWindow(id: "settings")
            store.isSetupPresented = true
            NSApp.activate(ignoringOtherApps: true)
        }
        .disabled(store.persistenceError != nil)
        Divider()
        Button("退出 Remote2Prompt") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--smoke-test-guide") {
            if CommandLine.arguments.contains("--smoke-test-guide") { PermissionDragGuide.shared.show() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else {
                    fputs("UI smoke failed: settings window is not visible\n", stderr)
                    exit(1)
                }
                if CommandLine.arguments.contains("--smoke-test-guide"),
                   !NSApp.windows.contains(where: { $0.isVisible && $0.title.contains("拖入授权引导") }) {
                    fputs("UI smoke failed: permission guide is not visible\n", stderr)
                    exit(1)
                }
                if let flag = CommandLine.arguments.firstIndex(of: "--preview-directory"), CommandLine.arguments.indices.contains(flag + 1) {
                    self.savePreviews(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true))
                }
                print("UI smoke passed: settings window is visible")
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func savePreviews(to directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (index, window) in NSApp.windows.filter({ $0.isVisible && ($0.canBecomeMain || $0.title.contains("拖入授权引导")) }).enumerated() {
                guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: directory.appendingPathComponent("window-\(index).png"))
                }
            }
            let remote = ImageRenderer(content: RemoteDiagram(selection: .constant(.select), active: [], voiceHeld: false))
            remote.scale = 2
            if let image = remote.nsImage, let tiff = image.tiffRepresentation,
               let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appendingPathComponent("remote.png"))
            }
            print("UI previews saved (own views only)")
        } catch { fputs("UI preview failed: \(error.localizedDescription)\n", stderr) }
    }
}
