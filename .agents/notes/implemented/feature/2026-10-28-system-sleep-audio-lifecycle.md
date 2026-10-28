# Agent Note: System sleep audio lifecycle

Status: implemented

## Problem

原willSleep只停止映射和自动接管；BLE查找、音频输出及配置/健康完成可能跨过睡眠，旧的按住状态也可能在重新打开HID后表现为新按下。

## Decision

`RemoteMappingRuntime` 的willSleep先标记暂停，再调用 `RemoteAudioRuntime.suspend()`。活动语音先释放触发并结束输入事务，再停止HID、租约、BLE与输出。暂停期间跳过权限轮询、音频枚举、健康检查和重试；未完成配置与旧连接事件由各自代次作废。

收到didWake后重新枚举并核验权限/HID，不信任睡前缓存的遥控器数量。恢复配置只建立输出与连接，不能自动打开麦克风。`FreshVoicePressGate` 要求每个来源先报告语音键松开，再允许新的语音按下；唤醒后的首个报告若仍按住，会等待松开。语音按住期间失去HID所有权也撤销这项许可。

这里只接入系统睡眠/唤醒，不声称已覆盖锁屏、解锁、后台维护唤醒和快速用户切换；剩余范围见[原提案](../../proposed/feature/2026-10-28-sleep-aware-recovery.md)。

## Alternatives considered

- 只停止普通按键：留下音频资源和晚到完成。
- 唤醒后继续旧语音：不能证明用户仍打算录音，也会误用旧输入快照。
- 唤醒后只要求手动重连：保留有限自动重建，但先核验当前资源并要求新按下。

## Consequences

没有新设置或配置迁移。普通检查运行真实音频运行时和模拟资源，覆盖重复暂停/恢复、配置中睡眠、退避中睡眠、睡眠中关功能、退出后唤醒，以及每来源松开门控。原生通知、实际睡眠、真实首尾音与输入法须另做真机验收，不能从模拟结果推定。
