# 架构

## 当前源码

```text
Sources/
  Remote2PromptCore/        配置格式、按键模型、语音键会话、输入优先策略
  Remote2Prompt/            SwiftUI/AppKit 入口、左栏设置、本机配置保存
  Remote2PromptMac/         HID、按设备原生键租约、系统事件发送、运行时协调
Tests/Remote2PromptChecks/  无 XCTest 的核心行为检查可执行程序
Resources/                 应用 Info.plist
scripts/                   CLT 构建、验证、文档检查、本地 tap 生成
packaging/homebrew/        源码 Formula 模板
.agents/notes/             持久决策及尚未完成的提案
.agents/plans/             实施清单与交接
.agents/skills/            两个本项目工作流技能
```

`Remote2PromptCore` 不发送系统事件，不连接设备，不读写系统音频。`AudioInputPriority.reconcile` 接收最新快照并返回可选目标 UID，返回意图不等于写入成功。`VoiceSession` 返回按键事件意图，由 macOS 适配器发送。配置 schema 为 2，读取 schema 1 时保留原有设置并迁移；新增按键 TV 与可选的任意快捷键。未知版本、格式错误、重复绑定及不完整快捷键拒绝加载，应用保留原始数据并暂停编辑。

`XiaomiRemote` 解析 report 1 中三个 little-endian 16-bit usage，支持 6 字节及带 ID 前缀的 7 字节格式。`ButtonGestures` 用外部传入的单调时钟区分即时单击、0.30 秒双击、0.55 秒长按；普通可重复动作在 0.45 秒后每 0.08 秒重复，迟到的计时器不补发积压动作。语音 usage 0x3E 不进入普通手势。

`ConfigurationStore` 在 MainActor 上通过 UserDefaults 保存整个配置，存储键保持 `configuration.v1` 以读取旧配置，数据内的 schema 为 2，应用标识符为 `dev.remote2prompt.app`。权限请求仅由用户点击界面按钮触发。SwiftUI `NavigationSplitView` 和分组 `Form` 构成原生设置；菜单栏入口重开同一窗口。

`SetupWizard` 使用运行时的临时检测模式，复用原生键租约和 HID 回调，但不调用动作执行器。`SetupInputCheck` 只保存本次检测的临时来源和成对事件，来源不写入设置；断连、停止或重新检测会使结果失效。向导只在完成时合并所选设置，退出后按原配置恢复接管。普通按键与语音按键的检测不证明音频或目标输入法可用。

SDK 27 另外声明了 `@State` 宏，但当前独立 CLT 不附带 SwiftUIMacros 插件。`ViewState<Value>` 显式引用公开的 `SwiftUI.State<Value>` 属性包装器，保留旧 SDK 语义并避免依赖 Xcode 中的宏插件；不要直接改回裸 `@State` 而未在独立 CLT 下验证。

## 系统适配器

HID、系统动作与按键运行时已接入；音频相关职责仍为规划：

- **设备适配器**：`HIDRemoteMonitor` 管理限定设备的原始键盘报告与热插拔，`NativeKeyLease` 拥有原生键抑制与恢复。CoreBluetooth/ATVV 留待 M2。HID 连接不等于音频 ready。
- **音频适配器**：经过验证的解码器输出 PCM，通过 AVAudioEngine/CoreAudio 送入明确选定的回环设备；拥有队列排空、溢出、失效与停止。
- **输入设备协调器**：监听 CoreAudio 设备列表和默认输入，转换成 UID 快照交给策略；串行写入后读取验证，处理失败、限频和 listener 清理。不得在渲染回调中做设备枚举或系统输入切换。
- **动作执行器**：`SystemActionSender` 将映射和语音键事件转换为 CoreGraphics/系统媒体动作，负责辅助功能检查、左右修饰标记、合成事件标记和释放。录入器仅接收当前窗口事件。
- **运行时协调器**：`RemoteMappingRuntime` 串行处理按键、设备接口变化、设置修改、权限丢失、休眠和退出。语音按住期间暂停普通映射，避免组合键副作用。音频开始、排空和结束的协调留待 M2。

当前新增 `Remote2PromptMac` target，使 macOS 适配器可以由独立检查程序注入模拟设备服务与事件出口，检查不向真实桌面发送按键。HID 输入和映射清理的理由见 [设备租约决策](../.agents/notes/implemented/architecture/2026-10-27-device-scoped-key-lease.md)。音频适配器、ATVV 和默认输入协调器仍未实现。

为什么采用此分层与工具链，见 [CLT 与应用分层决策](../.agents/notes/implemented/architecture/2026-10-27-swift-clt-foundation.md)。
