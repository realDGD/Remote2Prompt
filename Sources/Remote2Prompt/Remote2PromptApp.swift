import AppKit
import Remote2PromptCore
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
        Remote2PromptApp.main()
    }
}

struct Remote2PromptApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var store = ConfigurationStore()

    var body: some Scene {
        Window("Remote2Prompt", id: "settings") {
            SettingsView()
                .environmentObject(store)
        }
        .defaultSize(width: 900, height: 650)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Remote2Prompt", systemImage: "mic.badge.plus") {
            MenuContents()
        }
    }
}

private struct MenuContents: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Remote2Prompt · 开发预览")
        Divider()
        Button("打开设置…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Divider()
        Button("退出 Remote2Prompt") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else {
                    fputs("UI smoke failed: settings window is not visible\n", stderr)
                    exit(1)
                }
                print("UI smoke passed: settings window is visible")
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
