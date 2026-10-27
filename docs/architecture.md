# 架构

## 当前源码

```text
Sources/
  Remote2PromptCore/        配置格式、按键模型、语音键会话、输入优先策略
  Remote2Prompt/            SwiftUI/AppKit 入口、左栏设置、本机配置保存
Tests/Remote2PromptChecks/  无 XCTest 的核心行为检查可执行程序
Resources/                 应用 Info.plist
scripts/                   CLT 构建、验证、文档检查、本地 tap 生成
packaging/homebrew/        源码 Formula 模板
.agents/notes/             持久决策及尚未完成的提案
.agents/plans/             实施清单与交接
.agents/skills/            两个本项目工作流技能
```

`Remote2PromptCore` 不发送系统事件，不连接设备，不读写系统音频。`AudioInputPriority.reconcile` 接收最新快照并返回可选目标 UID，返回意图不等于写入成功。`VoiceSession` 返回按键事件意图，系统适配器尚未实现。配置 schema 为 1，缺失字段使用安全默认值，未知版本、格式错误和重复绑定拒绝加载；应用保留原始数据并暂停编辑。

`ConfigurationStore` 在 MainActor 上通过 UserDefaults 保存整个配置，键为 `configuration.v1`，应用标识符为 `dev.remote2prompt.app`。当前应用只读取辅助功能与输入监控授权状态，不发起授权请求。SwiftUI `NavigationSplitView` 和分组 `Form` 构成原生设置；菜单栏入口重开同一窗口。

SDK 27 另外声明了 `@State` 宏，但当前独立 CLT 不附带 SwiftUIMacros 插件。`ViewState<Value>` 显式引用公开的 `SwiftUI.State<Value>` 属性包装器，保留旧 SDK 语义并避免依赖 Xcode 中的宏插件；不要直接改回裸 `@State` 而未在独立 CLT 下验证。

## 后续系统适配器

以下是计划中的职责，尚未作为空模块加入 Package：

- **设备适配器**：CoreBluetooth 管理 ATVV 语音通道，IOKit 管理限定设备的 HID 普通键；拥有发现、订阅、重连与取消任务。外设连接不等于 ready。
- **音频适配器**：经过验证的解码器输出 PCM，通过 AVAudioEngine/CoreAudio 送入明确选定的回环设备；拥有队列排空、溢出、失效与停止。
- **输入设备协调器**：监听 CoreAudio 设备列表和默认输入，转换成 UID 快照交给策略；串行写入后读取验证，处理失败、限频和 listener 清理。不得在渲染回调中做设备枚举或系统输入切换。
- **动作执行器**：将映射和语音事件转换为 CoreGraphics/系统媒体动作；拥有辅助功能检查、左右修饰标记、合成事件标记和成对释放。不创建全局键盘记录器。
- **运行时协调器**：串行处理设备 ready、语音开始/结束、音频排空、设置修改、权限变化和退出。通过协议注入适配器以测试顺序和清理。

先保持一个 Swift Package 和两个源码 target；当适配器真正产生独立依赖或构建需求时再拆分。不要为尚未接入的功能堆砌空 target、假设备或演示成功状态。

为什么采用此分层与工具链，见 [CLT 与应用分层决策](../.agents/notes/implemented/architecture/2026-10-27-swift-clt-foundation.md)。
