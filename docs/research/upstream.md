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
- [SettingsView.swift](https://github.com/HD838A/remote-mic-app/blob/main/Sources/RemoteMic/SettingsView.swift)（blob `2b9bf41615f1f41faca6527820e44ebfe00671f9`）提供设置结构、权限请求与设置入口的行为参考。用户选择仅保留按键映射、连接与语音、权限与隐私、关于，不加入组合动作、统计或回眸。
- [Onboarding 产品规范](https://github.com/HD838A/remote-mic-app/blob/main/feature/first-run-onboarding/PRODUCT_SPEC.md)（blob `560d38515aa120529473abd2b13e0226186bf57e`）强调生产链路、真实事件、配置暂存、旧结果失效。VoiRemote 当前只实现 M1 按键向导，支持取消与重跑，不复制其完整语音测试流程或不可跳过政策，不宣称已完成音频或识别验收。
- [HIDRemoteMonitor.swift](https://github.com/HD838A/remote-mic-app/blob/main/Sources/RemoteMic/HIDRemoteMonitor.swift) 的授权方法同样直接调用 `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`。没有独立于 macOS 权限状态、可强制重弹输入监控系统授权框的替代实现。
- 完整请求链核对到上游 commit `59260d5501e2d6e932966d2f2988c362b784487c`：SettingsView 的权限动作进入 [BridgeAppModel.swift](https://github.com/HD838A/remote-mic-app/blob/59260d5501e2d6e932966d2f2988c362b784487c/Sources/RemoteMic/BridgeAppModel.swift#L3896)，调用 HID 请求后直接打开 Privacy_ListenEvent。HIDRemoteMonitor 的 wrapper 仅调用 IOHIDRequestAccess；没有额外系统弹窗实现。PermissionStatusProbe / HIDPermissionPoll 将周期性状态查询移到串行后台队列，避免主线程阻塞；本项目该查询仍在 MainActor，属于另一个需改进的运行时边界，不能把它推断为未弹窗根因。
- [build-app.sh](https://github.com/HD838A/remote-mic-app/blob/59260d5501e2d6e932966d2f2988c362b784487c/scripts/build-app.sh#L933) 在 ad-hoc 分支显式写入 `designated => identifier`。VoiRemote 原默认规则为 `cdhash`，每次代码变化导致身份改变。本机已安装 `/Applications/SayAll.app` 的实际规则则包含 Apple 证书链及团队，属于 Developer ID 稳定签名，不能与上游开发模式混为一谈。稳定规则可避免身份漂移，但不证明修复了系统首次授权弹窗。

本次没有复制上游 Swift 实现、品牌或图标，没有拉入 MiRemoteV/BlackHole 二进制。复用代码或派生驱动是后续独立决策，来源记录见 [THIRD_PARTY_NOTICES](../../THIRD_PARTY_NOTICES.md)。


## 2026-10-28 持续音频实现对照

本次固定核对上游提交 `2ce3ec65b02b2746109da267bc9a6eee04ec516b`，仅阅读协议与实现，没有复制其代码。

- [蓝牙收流](https://github.com/HD838A/remote-mic-app/blob/2ce3ec65b02b2746109da267bc9a6eee04ec516b/Sources/RemoteMic/XiaomiBluetoothBridge.swift)：订阅 ATVV 控制与音频，确认能力后按帧解码；同步通知重设解码状态，记录收包、解码和中断计数。
- [播放输出](https://github.com/HD838A/remote-mic-app/blob/2ce3ec65b02b2746109da267bc9a6eee04ec516b/Sources/RemoteMic/AudioOutput.swift)：采用 AVAudioEngine 和 AVAudioPlayerNode，串行配置，先连接 player/mixer 再绑定设备并验证输出；使用 dataPlayedBack 回调计数，排空请求区分正常、超时和中断，并用代次拒绝旧完成。配置变化异步进入引擎队列，重新检查健康状态再通知上层恢复。
- [解码协议](https://github.com/HD838A/remote-mic-app/blob/2ce3ec65b02b2746109da267bc9a6eee04ec516b/Sources/RemoteMic/ATVVProtocol.swift)：RC003 高半字节优先 IMA ADPCM，120 字节对应 240 个16 kHz样本；另有滤波与增益处理。

本项目0.2.6当前使用独立 Audio Queue，并在欠载后刷新转换器、给新缓冲指定未来时间；这是当前实现取舍，并非上游的播放后端。不能因为本机旧引擎恢复失败，就推断上游引擎方案本身不可用。按会话记录交付进度、区分消费与实际播放、旧回调隔离及异步设备恢复，均值得继续保持。

上游还定义 microphoneExtend，但已查到的代码搜索只包含定义及调试/一分钟超时记录，未见生产调用；不能据此认定几秒失声需要添加保活定时器。键盘输入法选择与系统默认麦克风也属于不同状态，不能将 PreferredInputSourceMonitor 直接当作麦克风恢复实现。

本轮保留Audio Queue，将上游的串行健康校验、绑定核验、取消/排空代次与恢复所有权原则应用到当前后端；增加播放进度和收包停滞检测。上游还读取并修复所选回环输入/输出静音与音量；本项目仅周期读取，明确静音或零音量报告错误，不自动改用户音量，也不将上游0.2阈值直接套用。源码独立实现，未复制上游代码。
