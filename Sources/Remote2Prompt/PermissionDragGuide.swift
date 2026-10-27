import AppKit
import SwiftUI

/// Application help panel, never a simulated macOS authorization dialog.
@MainActor
final class PermissionDragGuide {
    static let shared = PermissionDragGuide()
    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let value = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 245), styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
            value.title = "Remote2Prompt · 拖入授权引导"
            value.level = .floating
            value.hidesOnDeactivate = false
            value.isReleasedWhenClosed = false
            panel = value
        }
        guard let panel else { return }
        let placement = position()
        panel.contentView = NSHostingView(rootView: DragGuideContent(pointsRight: placement.pointsRight))
        panel.setFrameOrigin(placement.origin)
        panel.orderFrontRegardless()
    }

    private func position() -> (origin: CGPoint, pointsRight: Bool) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first?.processIdentifier
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        if let window = windows.first(where: { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 }),
           let bounds = window[kCGWindowBounds as String] as? NSDictionary,
           let frame = CGRect(dictionaryRepresentation: bounds) {
            let displayTop = NSScreen.screens.map { $0.frame.maxY }.max() ?? visible.maxY
            let y = max(visible.minY + 12, min(visible.maxY - 257, displayTop - frame.midY - 120))
            if frame.minX - 352 >= visible.minX { return (CGPoint(x: frame.minX - 352, y: y), true) }
            if frame.maxX + 352 <= visible.maxX { return (CGPoint(x: frame.maxX + 12, y: y), false) }
            return (CGPoint(x: visible.minX + 12, y: max(visible.minY + 12, visible.maxY - 257)), true)
        }
        return (CGPoint(x: visible.minX + 20, y: visible.midY - 120), true)
    }
}

private struct DragGuideContent: View {
    let pointsRight: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("把应用图标拖进系统设置").font(.headline)
            HStack(spacing: 20) {
                if !pointsRight { arrow }
                DraggableApplicationIcon().frame(width: 64, height: 64)
                    .accessibilityLabel("拖动 Remote2Prompt 当前应用到输入监控列表")
                if pointsRight { arrow }
            }.frame(maxWidth: .infinity)
            Text("拖到“隐私与安全性 → 输入监控”的应用列表，再由你打开 Remote2Prompt 开关。")
                .font(.callout)
            Text("这是应用操作引导。授权由 macOS 完成；也可使用系统列表下方的“＋”添加。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 340, height: 245)
    }
    private var arrow: some View {
        Image(systemName: pointsRight ? "arrow.right" : "arrow.left")
            .font(.system(size: 34, weight: .semibold)).foregroundStyle(Color.accentColor)
    }
}

private struct DraggableApplicationIcon: NSViewRepresentable {
    func makeNSView(context: Context) -> ApplicationDragView { ApplicationDragView() }
    func updateNSView(_ nsView: ApplicationDragView, context: Context) {}
}

private final class ApplicationDragView: NSView, NSDraggingSource {
    private let url = Bundle.main.bundleURL
    private lazy var appIcon = NSWorkspace.shared.icon(forFile: url.path)
    override func draw(_ dirtyRect: NSRect) { appIcon.draw(in: bounds.insetBy(dx: 2, dy: 2)) }
    override func mouseDown(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: appIcon)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
