# 架构

## 模块

- `Remote2PromptCore`：配置、映射、手势、语音键会话、ATVV 数据格式、IMA/DVI 解码及输入优先策略，不依赖 UI、蓝牙、CoreAudio 或系统事件发送。
- `Remote2PromptMac`：设备与权限、原生按键租约、系统动作、CoreBluetooth、回环设备与音频输出。
- `Remote2Prompt`：SwiftUI/AppKit 原生设置、配置保存和操作引导。
- `Tests/Remote2PromptChecks`、`Tests/Remote2PromptMacChecks`：不依赖 XCTest 的检查入口。macOS 模拟检查注入设备服务与事件出口，不向桌面发送按键。
- `scripts/` 与 `packaging/homebrew/`：独立 CLT 构建、bundle/仓库检查及源码 Cask 生成；公开 tap 只有根目录 `Casks/remote2prompt.rb`。Cask 在源码内编译、记录签名来源，将 app 本体移入 Applications 并清理构建缓存；标准 artifacts 拥有 app 和命令的卸载，不再保留 Formula/keg app。
- `.agents/notes/`：持久决策；`.agents/plans/`：实施清单；`.agents/skills/`：项目检查与 Note 工作流。

## 配置与界面

`ConfigurationStore` 在 MainActor 上保存整个配置，存储键保持 `configuration.v1`，应用标识为 `dev.remote2prompt.app`。数据 schema 为 3：新增独立 `voiceEnabled` 和默认关闭的 `remoteAudioEnabled`。读取 schema 1/2 保留原设置；原映射已开则迁移语音触发为开，不自动启用遥控器音频。未知版本、重复绑定及无效快捷键拒绝加载，保留原始数据并暂停编辑。

原生四页设置使用 `NavigationSplitView`。映射页左侧常驻遥控器，右侧语音卡置顶，普通键按三组显示三列；点击示意图定位对应行，快捷键录入与清除为直接入口。录入器只处理当前窗口，候选确认前不改配置。遥控器图由 SwiftUI 几何绘制，不包含品牌图片。`SetupWizard` 使用临时检测模式，复用 HID 链路而不执行普通映射或语音触发；仅完成时合并选择，取消恢复原状态。`SetupInputCheck` 限定本次阶段与同一来源的成对事件，断连或停止清除结果，不证明音频或输入法可用。

SDK 27 的裸 `@State` 依赖 CLT 不附带的 SwiftUIMacros；`ViewState<Value>` 显式引用公开 `SwiftUI.State<Value>` 包装器。不能未经独立 CLT 验证改回裸宏。

`ConfigurationTransfer` 拥有可移植 JSON 格式及大小、schema 和映射校验；UI 使用原生文件面板与替换确认，移除设备身份并关闭导入能力。`SetupWizard` 的四步草稿与可选检查分开，跳过不产生硬件成功证据。`MenuAudioInputs` 直接观察两个音频所有者，复用既有输入目录和显式 `userSelection` 请求；手动切换不创建语音所有权，语音/恢复期间互斥。

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

## 语音会话临时输入

`AudioInputPriority` 仅为活动语音事务捕获按下前的输入 UID，空闲观察不建立事务。按住时目标仍需已知驱动 UID/声道验证；恢复精确使用快照中的设备，包括其他虚拟或未知输入，只有原设备不可用才选实体回退。`record` 不因按住期间的外部抢占改写快照；松开后的新选择独立保存，必要时补偿确认窗口内的旧延迟写入。旧事务未完成的快速重按延续返回基线。

`CoreAudioInputSystem` 拥有系统和设备属性 listener。写入前重新解析可用输入、验证优先目标并比较来源；只写 DefaultInputDevice。`InputPriorityCoordinator` 将活动来源从设备 ready 改为活动语音，分离请求、确认和恢复。读回窗为 1 秒；重试和抢占写入间隔至少 0.5 秒，同一意图三次失败后暂停；真实按下/结束边界不等待旧的限频时间。状态只在新读回有效且无 pending 时允许语音开始。

`AudioInputPriorityRuntime.beginVoiceSession` 读取新快照并等待确认后回调，配置和音频 ready 本身不会接管；`endVoiceSession` 恢复。`RemoteAudioRuntime.prepareInput` 接入该门禁，等待期间以 `VoiceStartBuffer` 有界保留最多 32000 个单声道 PCM 样本。确认后才发送锁定的触发键、输出早到音频并启动协议；取消清除缓冲，代际阻止旧完成回调复活语音。

只有 HID 按下能开始会话，ATVV open 不能补开或重试已结束的会话。物理松开保留原有尾音与有界排空，完成后先释放实际持有的触发键，再结束输入事务。失效、向导、休眠和退出撤销活动来源，正常退出为已接受写入和恢复保留 3.5 秒。未知结果或无恢复设备时不伪报成功；停止后的回调不能清掉最终错误。

所有 UID、返回快照和所有权只在进程内，不写录音、输入文字或原始设备标识日志。CoreAudio 没有原子 compare-and-set，已接受请求不能撤回，确认窗口外的驱动延迟、强制结束和系统崩溃仍不保证恢复。当前生产音频限制一个所有者，真实遥控器与目标输入法验证独立记录。当前理由见 [语音输入事务决策](../.agents/notes/implemented/feature/2026-10-27-voice-input-transaction.md)，旧在线优先方案保存在归档 Note。

工具链与分层理由见 [CLT 决策](../.agents/notes/implemented/architecture/2026-10-27-swift-clt-foundation.md)。
