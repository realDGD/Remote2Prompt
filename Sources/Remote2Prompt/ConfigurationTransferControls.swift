import Remote2PromptCore
import Remote2PromptMac
import SwiftUI
import UniformTypeIdentifiers

private struct ConfigurationFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ConfigurationTransferControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    @ViewState private var importing = false
    @ViewState private var exporting = false
    @ViewState private var document = ConfigurationFile(data: Data())
    @ViewState private var candidate: AppConfiguration?
    @ViewState private var confirming = false
    @ViewState private var message: String?

    var body: some View {
        Menu {
            Button("导入配置…", systemImage: "square.and.arrow.down") { importing = true }
            Button("导出配置…", systemImage: "square.and.arrow.up") { prepareExport() }
                .disabled(store.persistenceError != nil)
        } label: { Label("导入与导出…", systemImage: "gearshape") }
        .menuStyle(.borderlessButton)
        .disabled(runtime.setupActive || runtime.audio.sessionActive)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let bytes = try handle.read(upToCount: ConfigurationTransfer.maximumBytes + 1) ?? Data()
                candidate = try ConfigurationTransfer.load(bytes)
                confirming = true
            } catch CocoaError.userCancelled { }
            catch { message = "无法导入配置：\(error.localizedDescription)" }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Remote2Prompt-config") { result in
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                message = "无法导出配置：\(error.localizedDescription)"
            }
        }
        .alert("替换当前配置？", isPresented: $confirming, presenting: candidate) { value in
            Button("取消", role: .cancel) { candidate = nil }
            Button("替换配置") {
                // Re-check because a voice session may start while the file panel is open.
                guard !runtime.audio.sessionActive, !runtime.setupActive else {
                    candidate = nil; message = "请先结束语音或设置向导，再导入配置。"; return
                }
                do { try store.replace(with: value); message = "配置已导入。请重新选择虚拟麦克风，并按需开启映射与语音。" }
                catch { message = "配置未替换：\(error.localizedDescription)" }
                candidate = nil
            }
        } message: { value in
            Text("将替换当前 \(store.configuration.bindings.count) 项映射，导入 \(value.bindings.count) 项映射和语音触发键。所有功能开关将关闭，虚拟麦克风需重新选择。系统权限和设备身份不在配置文件中。")
        }
        .alert("配置文件", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func prepareExport() {
        do { document = ConfigurationFile(data: try ConfigurationTransfer.export(store.configuration)); exporting = true }
        catch { message = "无法导出配置：\(error.localizedDescription)" }
    }
}
