# 空闲运行与失败恢复审查

核查日期：2026-10-28，基于 0.2.0 源码 `d33e921`，文档基线 `af116f4`。这是不依赖解锁的后续探索，未修改生产运行逻辑、安装版或设置。安装版原生 UI 与真实 RC003 验收仍单独保留。

## 可复现的实测

运行 `./scripts/probe-input-runtime.sh`，使用独立 CLT Release 编译实际的 `AudioInputPriorityRuntime`、`InputPriorityCoordinator` 及核心模块，注入固定的 `ProbeInputs`。不创建应用包、不实例化 `CoreAudioInputSystem`，也不访问真实设备、权限、音频或系统默认输入。构建产物在被忽略的 `.build/probes/input-runtime/`。

| 场景 | 实际结果 | 结论边界 |
| --- | --- | --- |
| 全部能力关闭，运行主 RunLoop 6.2 秒 | 新增 3 次目录快照、0 次状态发布、0 次模拟写入 | 输入目录仍约每 2 秒刷新；相同状态没有重复发布。不是整机 CPU、耗电或实际 CoreAudio 调用耗时测量。 |
| shutdown 后释放运行时，再运行 2.2 秒 | 完成回调返回、系统变更回调移除、弱引用归零、额外读取 0 次 | 该同步模拟路径的 timer 与回调清理有效；不证明整个 App 或驱动没有泄漏。 |
| 1000 次创建、配置、按下、松开、关闭循环 | 每次恰好 2 次模拟写入，均恢复原模拟输入；保留运行时 0 个 | 验证即时读回的正常释放路径；不覆盖真实驱动延迟、异步通知风暴或目标输入法。 |
| 首次监听初始化失败，随后让模拟系统恢复，调用菜单刷新入口 | 重新启动 0 次；仍为 failed，目录为空 | **已复现的失败恢复缺口**，不是推测。 |
| 同一失败运行时调用现有 retry 入口 | 重新启动 1 次，目录 2 项，phase 为 disabled | 系统可恢复，但菜单刷新没有走到恢复入口；disabled 是配置默认关闭的正常状态。 |

探针用 `precondition` 校验清理、关闭不写与恢复后的目录等不变量；输出中的菜单刷新缺口作为诊断观察，**不以该命令退出成功表示该缺口已修复**。未来修复后应更新对应回归断言及本记录。

## 已复现：菜单刷新不能恢复首次初始化失败

[菜单](../../Sources/Remote2Prompt/MenuAudioInputs.swift) 的“刷新输入设备”调用 [运行时](../../Sources/Remote2PromptMac/AudioInputPriorityRuntime.swift) 的 `refreshInputs()`，后者只调用 `coordinator.refresh()`。[协调器](../../Sources/Remote2PromptMac/InputPriorityCoordinator.swift) 首次 `start()` 失败后没有置 `running`，而 `refresh()` 首先要求 `running`，因此手动刷新和周期刷新都不会重新注册监听。

隔离复制运行时，只在 `refreshInputs()` 内先调用现有幂等 `coordinator.start()`，再调用 `refresh()`，用同一探针重新编译：菜单刷新重新启动 1 次、目录 2 项、phase 为 disabled；原有空闲、1000 次循环和关闭检查结果保持一致。**这份候选修改仅在被忽略的实验目录验证，尚未接入生产源码。** 方案与需要补的故障回归见 [提案](../../.agents/notes/proposed/bug-fix/2026-10-28-input-catalog-start-recovery.md)。

不能简单把菜单刷新替换为 `retry()`：后者还会重置写入失败次数和意图。刷新目录不应顺便放宽语音事务的失败上限。

## 源码风险与优化机会

以下是源码路径审查，不能与上面的实测混写为已发生的硬件问题。

| 项目 | 源码证据 | 后续验证与约束 |
| --- | --- | --- |
| 映射关闭时仍有检查 | [RemoteMappingRuntime](../../Sources/Remote2PromptMac/RemoteMappingRuntime.swift) 创建 1 秒 timer；refresh 检查代码身份并请求权限快照，回调查询 HID 数量，之后才判断映射/语音/向导是否开启。 | 标称每小时 3600 次 timer 回调是按间隔推算，不是实测系统调用次数；权限探针会合并并发请求。可评估事件驱动与低频兜底，不能取消启用期间的权限撤销与原生映射保护。 |
| 两个音频目录轮询 | 输入优先运行时与 [RemoteAudioRuntime](../../Sources/Remote2PromptMac/RemoteAudioRuntime.swift) 各有 2 秒 timer；前者已有 CoreAudio 变更监听。 | 本轮只测到前者的模拟快照次数。需分别量化查询耗时，再评估共享目录/变更通知；动作前仍须新鲜读回，菜单也不能长期显示陈旧设备。 |
| 关闭语音后仍可能保持回环引擎 | 音频运行时的 routeChanged、refreshDevices 可调用 prepareOutput，不以 wanted 为前提；[LoopbackWriter](../../Sources/Remote2PromptMac/LoopbackWriter.swift) 配置时启动 engine/player。关闭路径停止 BLE，没有同步关闭 writer。 | 这是测试音可用的现有设计，不能直接判为错误。可评估显式测试音临时打开、结束排空关闭，以及语音就绪状态分层；未测引擎实际 RSS/功耗，不宣称节省值。 |
| PCM 入队之前没有明确总量限制 | LoopbackWriter.append 先把持有 samples 的闭包送入串行 queue，32000 样本上限在闭包执行后才检查；pending 只计已调度音频。 | 队列被阻塞时，等待闭包未包含在该上限内；这是源码可见的上界缺口，尚未复现真实内存增长。下一步应注入停滞消费者，验证入口计数、取消代次和溢出语义；不能静默丢音或以平均 RSS 掩盖上界。 |
| BLE 发现无截止时间 | [RemoteVoiceBluetooth](../../Sources/Remote2PromptMac/RemoteVoiceBluetooth.swift) 的 discover 扫描没有期限，8 秒 timeout 从 connect 才开始。 | 与第一轮调研一致，不作为重复的新发现；接续睡眠/锁屏生命周期提案，使用虚拟时钟验证扫描和退避。 |

## 本轮没有覆盖

没有运行安装版 UI、真实系统输入切换、蓝牙录音或实际语音工具。没有测量整个应用的内存/能耗，没有证明全部监听器在所有异常退出路径释放。现有 0.2.0 的 CLT/Homebrew 安装和既有 CI 结果不因本探针扩大为这些能力的验收。
