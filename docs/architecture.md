# 架构

## 模块

- `Remote2PromptCore`：配置、映射、手势、语音键会话、ATVV 数据格式、IMA/DVI 解码及输入优先策略，不依赖 UI、蓝牙、CoreAudio 或系统事件发送。
- `Remote2PromptMac`：设备与权限、原生按键租约、系统动作、CoreBluetooth、回环设备与音频输出。
- `Remote2Prompt`：SwiftUI/AppKit 原生设置、配置保存和操作引导。
- `Tests/Remote2PromptChecks`、`Tests/Remote2PromptMacChecks`：不依赖 XCTest 的检查入口。macOS 模拟检查注入设备服务与事件出口，不向桌面发送按键。
- `scripts/` 与 `packaging/homebrew/`：独立 CLT 构建、bundle/仓库检查与本地源码 tap。
- `.agents/notes/`：持久决策；`.agents/plans/`：实施清单；`.agents/skills/`：项目检查与 Note 工作流。

## 配置与界面

`ConfigurationStore` 在 MainActor 上保存整个配置，存储键保持 `configuration.v1`，应用标识为 `dev.remote2prompt.app`。数据 schema 为 3：新增独立 `voiceEnabled` 和默认关闭的 `remoteAudioEnabled`。读取 schema 1/2 保留原设置；原映射已开则迁移语音触发为开，不自动启用遥控器音频。未知版本、重复绑定及无效快捷键拒绝加载，保留原始数据并暂停编辑。

原生四页设置使用 `NavigationSplitView`。映射页为所有键同时显示三列，录入器只处理当前窗口，候选确认前不改配置。遥控器图由 SwiftUI 几何绘制，不包含品牌图片。`SetupWizard` 使用临时检测模式，复用 HID 链路而不执行普通映射或语音触发；仅完成时合并选择，取消恢复原状态。`SetupInputCheck` 限定本次阶段与同一来源的成对事件，断连或停止清除结果，不证明音频或输入法可用。

SDK 27 的裸 `@State` 依赖 CLT 不附带的 SwiftUIMacros；`ViewState<Value>` 显式引用公开 `SwiftUI.State<Value>` 包装器。不能未经独立 CLT 验证改回裸宏。

## 设备、权限与事件

发现阶段只读 IORegistry 属性，不实例化 HID user client。接管时 `HIDRemoteMonitor` 才打开限定 VID/PID 的原始键盘报告通道。`XiaomiRemote` 解析三个 little-endian 16-bit usage，支持 report 1 的 6/7 字节布局，语音 0x3E 不进入普通手势。`ButtonGestures` 使用外部单调时间：双击 0.30 秒、长按 0.55 秒；可重复动作 0.45 秒后每 0.08 秒重复，不补发积压。

`NativeKeyLease` 按服务与所属源写入、验证和恢复原生映射。恢复日志 v2 记录本次源范围，兼容旧 v1；仅开启语音时只接管语音键，普通映射开而语音关时不接管语音键。日志在设备写入前原子保存；外部软件后来的修改保留。理由见 [设备租约决策](../.agents/notes/implemented/architecture/2026-10-27-device-scoped-key-lease.md)。

`PermissionProbe` 在串行后台队列处理同步 TCC 查询与请求，主线程交付状态，不堆积轮询。监听已允许不等于独立输入监控条目，可能来自设备控制授权。只在用户请求时调用公开授权 API；失败时可打开真实设置，并以原生可拖动 app URL、图标和箭头辅助人工添加，不伪造系统授权框。相同状态不持续发布，避免无意义地重建整个设置页。

`SystemActionSender` 成对发送普通键、媒体键和独立修饰键，持有物理冲突检查与释放。释放时重建本次修饰键家族的真实物理状态，清掉快照中可能残留的合成标记，保留另一侧及其他修饰键。`RemoteMappingRuntime` 统一处理 HID、设置、权限、断连、休眠和退出；语音持有期间暂停普通映射。

## 音频代码链路

`RemoteVoiceBluetooth` 管理单个 RC003 候选，订阅 Audio/Control 通知并确认支持 16 kHz 的能力后才 ready；初始化超时 8 秒，失败后 3 秒重建连接。旧连接的 delegate 被清理，不跨连接处理回调。只连接明确设备名或匹配 ATVV 服务的已限定候选；不记录外设 UUID、地址或完整数据。

核心 `RemoteVoiceDecoder` 处理高半字节优先的 IMA/DVI、分片和 predictor/index 同步，拒绝异常尺寸。解码检查使用合成固定样例，不包含真实录音。

`LoopbackDevices` 以已知 UID 加双向声道验证识别 MiRemoteV 2ch / BlackHole 2ch。瞬时 AudioDeviceID 仅存在适配器，配置保存 UID。`LoopbackWriter` 在串行队列中拥有 AVAudioEngine，只绑定明确选中的回环设备。没有回退扬声器或写系统默认输入/输出的路径，设备失效或队列溢出时停止。

`RemoteAudioRuntime` 拥有路由、协议连接和会话代际。开始前确认音频与 HID 接管准备，再发送触发键；结束保留 120 ms 尾部通知，排队 PCM 播放完成后释放，排空最长等待 1 秒。取消、断连或失效立即清理。快速重按会中断旧排空，新会话等协议 start 后接收数据，避免旧音频混入。测试音在内存生成，只写所选回环，真实语音优先并取消测试音。

以上为代码接入事实，不能替代实际说话、首尾音、低延迟及目标输入法验收。

## 系统默认输入优先

`AudioInputPriority` 使用 UID 快照，明确区分实体、虚拟与未知输入；只有经过驱动 UID/声道验证的回环可被优先选择。请求包含来源、目标、用途和序号；只有当前请求读回匹配后才取得恢复所有权。初始已选虚拟输入不属于本应用所有，失败请求不取得所有权，失败恢复保留重试依据。恢复优先最近实际观察到的实体 UID，再按 UID 稳定排序回退，未知、虚拟及聚合输入不参与实体回退。

`CoreAudioInputSystem` 拥有默认输入、设备列表和设备属性监听，停止时成对移除；回调携带生命周期代际且只触发新快照，不信任过时通知内容。AudioDeviceID 仅在该适配器中解析，写入前重新查找目标并比较当前输入 UID；唯一系统写入口固定为 DefaultInputDevice。CoreAudio 没有原子 compare-and-set，最后检查与系统写入之间的外部竞争无法被绝对排除。

`InputPriorityCoordinator` 在 MainActor 串行管理观测、待确认和所有权：接受写入不等于成功，最多等 1 秒读回；任意两次写入至少间隔 0.5 秒，同一意图失败三次后暂停，支持明确重试。`AudioInputPriorityRuntime` 拥有合并唤醒和 2 秒只读补偿轮询；配置关闭时仍保留必要的恢复观察。原生设置消费状态，分别显示实际、最近请求、最近确认和恢复目标，不把请求当作已生效。

`RemoteMappingRuntime` 仅在显式优先开关、音频初始化成功、HID 接管、权限及非向导模式同时满足时传入就绪来源。音频写入/解码失效撤销 ready，断连、休眠、权限失效及停止均进入恢复。当前生产音频仍限一个所有者，多来源最后断开的语义已用模拟集合检查，尚未验收多只真实遥控器。

正常退出为已发出的切换及恢复保留 3.5 秒异步确认预算，然后清理 listener、计时器和订阅。无恢复工作时直接退出；延后退出的确认使用 AppKit 模态运行循环，避免 GCD 退出路径相互等待。没有实体目标或恢复失败时不伪报成功。所有权与最近实体 UID 只在本次进程内保存，强制结束、系统崩溃及超出确认窗的驱动延迟不保证恢复；不在下次启动凭默认设备猜测旧所有权。理由和验证边界见 [输入优先决策](../.agents/notes/implemented/feature/2026-10-27-prefer-virtual-input.md)。

工具链与分层理由见 [CLT 决策](../.agents/notes/implemented/architecture/2026-10-27-swift-clt-foundation.md)。
