# 设置、权限与语音链路 Implementation Plan

本轮由当前 agent 直接执行。用户已指定继续工作、无需现场辅助；不另启设计审批或子 agent。采用 writing-plans 的分阶段拆分，遵守项目约定，不推送远端。

**Goal:** 完成三列映射、可确认的快捷键录入、RC003 示意图、真实授权请求及拖入授权引导，接入可用虚拟音频设备与遥控器语音链路。

**Architecture:** 纯核心拥有录入事务、协议/解码与会话策略；Mac 适配器拥有 HID、蓝牙、CoreAudio 和授权资源；SwiftUI 显示实时状态，不制造通过结果。

**Tech Stack:** macOS 14+、Swift 6、SwiftPM、独立 CLT、SwiftUI/AppKit、IOKit、CoreBluetooth、AVAudioEngine/CoreAudio。

**Spec:** 用户本轮五项需求及 [产品需求](../../docs/product.md)。参考图仅用于键位几何，不复制品牌资产。

## Global Constraints

- 保持 Homebrew + CLT，临时签名；不创建本地证书、不放宽识别规则、不 push。
- 不自建系统授权替代框。必要时打开真实设置页，并提供可拖动的当前应用图标和箭头；不代替用户授予权限。
- 不安装驱动、不重启 CoreAudio、不默认切换系统输入/输出。
- 不记录音频、输入文字、完整 HID 报告或蓝牙设备标识。
- 分阶段 commit；源码/模拟、系统 API、真实输入法与硬件结果分别记录。

## Review Focus

- 启动时设备枚举不应提前请求监听；输入监控的拒绝/未知/允许与辅助功能来源分开说明。
- 录入取消不写设置；清空只清候选；确认才保存；左右修饰键必须区分。
- 语音触发不依赖普通映射开关；断连、退出、权限失效和切换模式都需成对释放。
- 失效或被拔出的音频 UID 不能退回扬声器；测试音只能写明确选中的回环设备。
- 蓝牙初始化及通知订阅未完成、音频格式不支持时不能显示语音就绪；取消后不接受旧音频。

## 阶段

### 1. 权限取证与拖入授权引导

Files: `Sources/Remote2PromptMac/HIDRemoteMonitor.swift`, `IOHIDPermission.swift`, `RemoteMappingRuntime.swift`, 新建 `PermissionDragGuide.swift`，修改权限页。

- [ ] 用 IORegistry 元数据代替发现阶段的 HID Manager 实例化，避免未授权时打开 user client。
- [ ] 核对公开请求的返回状态与系统日志；不再把签名漂移当作未弹窗的唯一原因。
- [ ] 引导面板使用当前 app URL 和原生拖放，箭头指向真实设置窗口；不伪装成系统授权。
- [ ] CLT 构建、原生 UI 检查后提交；系统最终授权保留用户操作边界。

### 2. 三列映射与快捷键录入

Files: `MappingsPage.swift`, 新建 `RemoteDiagram.swift`, `ShortcutCaptureView.swift`；必要的核心录入策略与检查。

- [ ] 每行一个普通键，单击/双击/长按三列始终可见；紧凑菜单与快捷键摘要。
- [ ] 图示按用户图片重新绘制：顶排电源/语音、圆环导航、返回/主页/菜单左列、纵向音量/TV 右列。
- [ ] 录入实时显示候选，清空、取消、确认独立；快捷键名称覆盖字母/数字/功能键。
- [ ] 窗口最小尺寸、滚动、录入取消与确认验证后提交。

### 3. 语音触发与虚拟音频设备

Files: `AppConfiguration.swift`, `VoiceSession.swift`, `RemoteMappingRuntime.swift`, 新建音频设备/输出适配器，连接与语音页。

- [ ] 语音触发独立开关默认关闭；普通映射关闭时仍可独立使用；明确按住生命周期。
- [ ] 按 UID 枚举并选择 MiRemoteV 2ch / BlackHole 2ch，验证双向声道与设备身份，不自动选择或回退实体设备。
- [ ] 16 kHz PCM 写入指定回环输出，测试音与真实语音互斥；停止/排空/设备失效有清理。
- [ ] 自动策略检查、实际设备只读枚举与 CLT 构建后提交。

### 4. RC003 音频协议与接线

Files: 新建纯协议/IMA 解码和 CoreBluetooth 适配器、语音协调器；更新来源说明和 Note。

- [ ] 核对 ATVV 通道、初始化、帧长与同步格式；独立实现，不直接复制 GPL 源码。
- [ ] 固定合成样例验证半字节顺序、饱和、无效长度、分片和取消。
- [ ] 通知订阅与能力协商成功后才 ready；按下开始、尾音排空后释放；失败关闭并报告。
- [ ] 真机不在场时只报告已执行覆盖；目标输入法与实际音频不伪报完成。

### 5. 最终验证与交付

- [ ] `make test`、CLT build、bundle 验证、文档检查；本轮变更后必要的原生 UI 验证。
- [ ] 本地 Homebrew 归档/Formula 生成检查，避免交互授权测试期间安装同 Bundle ID 副本。
- [ ] 更新路线图、能力表和验证记录；分阶段本地提交，保持没有 push。
