# Audio health, recovery and mapping presets implementation plan

> Execution: inline in this session under the user's project conventions; no repeated design approval, forced workflow chain or subagents.

**Goal:** 保留 Audio Queue，补齐有界健康检查、故障恢复及休眠清理，并按用户明细填入常用动作、统一原生菜单控件。

**Architecture:** 输出适配器报告真实设备、运行和播放进度，串行所有者判定停滞；语音运行时拥有有限恢复预算和会话代次。恢复只重建可用链路，不重开已经取消的语音。通过注入播放、传输、目录与时钟验证生产协调器，真机结果独立记录。

**Tech Stack:** Swift 6 / SwiftPM, macOS 14+, Audio Queue / CoreAudio / CoreBluetooth, SwiftUI + AppKit, standalone CLT.

**Spec:** 用户本轮需求，以及 docs/product.md、docs/architecture.md、docs/testing.md。

## Global constraints

- 默认 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`，不运行 xcodebuild 或修改 xcode-select。
- 不重置 TCC、创建证书、安装驱动、保存录音/原始包/设备身份；保留现有设置。
- 松开/取消/失效先释放合成触发键，再恢复输入；空闲和恢复 ready 不接管输入或自动开麦。
- 自定义映射、语音和输入优先仍默认关闭。常用动作只补空位，按明细20项，不覆盖已有配置。
- 分阶段提交；CLI和模拟结果不等同真实遥控器、微信和系统休眠验收。

## Review focus

- 后端空闲时未 running 是正常状态，不能不断重建；有待播放数据却停滞才报错。
- 旧配置、旧健康快照、恢复任务和播放回调不能复活已结束或已替换的会话。
- 配置“成功”后很快再失败不能重置全部恢复预算，避免无限抖动。
- 休眠时关闭 HID/BLE/输出；唤醒只恢复链路，等待新的物理语音按下。
- 新默认包含长按和双击，单击判定延迟随之变化；音量键明确为字符加减而非系统音量。

### Task 1: 常用动作和菜单

Files: AppConfiguration.swift, MappingActionCell.swift, MappingsPage.swift, SetupWizard.swift, ShortcutCaptureView.swift, core mapping/setup checks.
Interfaces: `fillBasicNavigationBindings()` 保持名称；补齐12click/1doubleClick/7longPress，普通动作或明确虚拟键码与修饰键。菜单统一显示 invocation 的标题，键盘录入和清除入口保留。

- [ ] 为全部20项的键码/修饰键、幂等与已有动作保留增加检查。
- [ ] 按用户明细实现；更新向导、提示和符号显示。
- [ ] 使用原生有边框 Menu，移除分离的纯文本快捷键按钮与自绘箭头。
- [ ] CLT检查、隔离预览点击菜单/录入/清除，提交。

### Task 2: 输出健康与有限恢复

Files: LoopbackWriter.swift, AudioQueueLoopbackPlayback.swift, LoopbackProgress.swift, new output health/recovery policy, RemoteAudioRuntime.swift, RemoteVoiceBluetooth.swift, adapter checks.
Interfaces: `LoopbackWriter.checkHealth(completion:)`，`RemoteVoiceTransport` 注入协议；运行时允许注入 writer、transport、catalog、clock，普通检查关闭自动timer。

- [ ] 健康快照覆盖选中UID、设备存活、转换错误、应运行状态、消费/播放时钟停滞；空闲不误报。
- [ ] 故障先取消会话/释放触发与恢复输入，再重建链路；最多3次、退避0.5/1/2秒，健康10秒才重置预算，手动retry显式重置。
- [ ] 统一传输初始化8秒截止与恢复所有权，消除无限扫描和两层重连计时器。
- [ ] 生产运行时+模拟传输/后端覆盖断流、重建失败、反复抖动、晚到回调和取消；提交。

### Task 3: 休眠与唤醒

Files: RemoteMappingRuntime.swift, RemoteAudioRuntime.swift, lifecycle policy/checks, owning Notes.
Interfaces: `RemoteAudioRuntime.suspend()` / `resume()`，映射运行时对应系统事件入口；监听 willSleep/didWake，并以实际权限/设备重新确认接管。

- [ ] suspend取消所有恢复/配置代次，释放触发，停止HID/BLE/输出；睡眠期间配置和轮询不重开资源。
- [ ] resume重新枚举与校验，恢复ready不代表开始语音；重复事件、睡眠中晚到完成均安全。
- [ ] 模拟睡眠/唤醒、恢复中再次睡眠、退出后唤醒；提交。

### Task 4: 集成回归与交付证据

Files: explicit MacChecks hardware diagnostics, docs/testing.md, new validation record, plan/Notes.

- [ ] CLT `make check` 和公开边界检查；无改动时不重复构建。
- [ ] 显式静音回归：长时播放、突发欠载、快速开始/结束/取消、设备快照恢复、资源清理。
- [ ] 用户已确认可配合：安装版/测试版长时间真实收音、快速重按、RC003断连重连、实际睡眠/解锁；逐项记录是否执行和结果。
- [ ] Homebrew保持单Cask远端源码构建，安装/发布按已有授权范围处理；最终状态与未覆盖项准确汇报。

## Execution ledger

- Baseline: b6e9b68, clean main, installed0.2.6. Prior final CI40671959048 verified3/3. No new installation, permissions or defaults changes at plan creation.
- Ruling: user's listed bindings total20 (12/1/7); use detailed list including power-long Escape rather than dropping a specified binding to match the stated19.
