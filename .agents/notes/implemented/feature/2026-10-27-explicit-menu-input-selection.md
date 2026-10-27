# Agent Note: Explicit menu input selection

Status: implemented

## Problem

菜单栏需要显示和选择系统声音输入，但不能把用户的一次选择误当成语音会话接管，也不能让它和按住/松开后的恢复事务争抢系统输入。

## Decision

菜单栏复用 `AudioInputPriorityRuntime`、`InputPriorityCoordinator` 和同一个 CoreAudio 所有者的设备目录，不建立第二套监听或默认设备写入。只在明确点选设备时发出 `userSelection` 请求，重新读取源和目标，验证目标仍存在并读回确认；单次请求最多等待一秒，不自动抢回用户选择。设备 UID 不写日志。

语音接管、待确认、恢复和向导期间不允许菜单切换。菜单将系统默认输入与遥控器的虚拟麦克风目标分开列出；后者仍只接受已有兼容回环设备，不安装驱动，不改变系统输出。

## Alternatives considered

- 菜单单独创建 CoreAudio 控制器：容易出现监听重复及默认输入争抢，未采用。
- 直接将点选等同 `restore`：会混淆所有权与返回基线，未采用。
- 开关关闭时停止所有设备观察：节约少量资源，但菜单无法跟踪系统输入；保留只读观察，状态不变时不发布。

## Consequences

新增六项模拟检查覆盖被动观察、当前设备、失效目标、源竞态、延迟/拒绝/超时和语音恢复互斥；核心 63 项与 macOS 适配器 59 项检查通过，CLT Release 构建及 bundle 验证通过。真实菜单显示和系统设备切换仍须与安装后原生交互记录区分；模拟检查未向真实系统写入默认输入。
