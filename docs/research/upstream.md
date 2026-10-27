# 参考项目核查

核查日期：2026-10-27。以下记录支持本次初始化的决策，不把上游未来变化当作本项目当前能力。

## DeepSeek Harness

- [AGENTS.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/AGENTS.md) 为开发入口，进一步链接到当前架构、局部指南和任务技能；本项目采用渐进阅读，不复制其包管理、插件架构与测试规模。
- [.agents/notes/README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/README.md) 将 Note 分为 `proposed`、`implemented`、`rejected`，并按 feature/architecture/process 等类别分层，记录长期决策理由和替代方案。没有集中 `INDEX.md`。
- 本项目沿用路径和核心格式，采用单一中文正文；不引入大型双语 sidecar、翻译流水线或冻结归档哈希清单。

核查到的文件 blob：AGENTS `69dbd7d69eb978392336ea2136ff855738c6625d`，Note 规则 `518851d6723f83866ac46375d5cd7e89c7efeef1`。这些是文件 blob 标识，不是整个仓库的 commit。

## remote-mic-app

- [README](https://github.com/HD838A/remote-mic-app/blob/main/README.md) 说明 Mac 端以 SwiftUI 实现，遥控器按住传输音频，通过兼容回环设备供输入法采集。
- [#435](https://github.com/HD838A/remote-mic-app/issues/435) 要求默认关闭的虚拟输入优先开关，遥控器在线时防止 AirPods/USB 抢占，并在最后断连后恢复最近的非虚拟输入。核查时 open、无评论。
- [#433](https://github.com/HD838A/remote-mic-app/issues/433) 要求左右 Control 单键语音触发。核查时 open、无评论。
- [VoiceKeyMode.swift](https://github.com/HD838A/remote-mic-app/blob/main/Sources/RemoteMic/VoiceKeyMode.swift) 只有 Fn、左右 Command、左右 Option，`init?(standaloneModifier:)` 对左右 Control 返回 nil。文件 blob 为 `0b4a21ebd0903caf9d23743fdbd15d1bef8d9df3`。普通快捷键编辑器支持 Control 不等于语音触发支持 Control。
- [TECHNICAL.md](https://github.com/HD838A/remote-mic-app/blob/main/TECHNICAL.md) 说明 ATVV、音频和 HID 职责；本项目仅用于技术路线调查，尚未据此完成硬件实现。

本次没有复制上游 Swift 实现、品牌或图标，没有拉入 MiRemoteV/BlackHole 二进制。复用代码或派生驱动是后续独立决策，来源记录见 [THIRD_PARTY_NOTICES](../../THIRD_PARTY_NOTICES.md)。
