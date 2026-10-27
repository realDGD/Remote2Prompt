# Remote2Prompt 初始化与后续实施

**目标：** 建立 Harness 风格的持续开发仓库和 CLT 可编译的原生应用骨架，为真实遥控器首版保留明确需求及验收入口。

**技术与约束：** Swift 6、SwiftPM、macOS 14+、SwiftUI/AppKit，构建不依赖完整 Xcode。产品需求以 [product.md](../../docs/product.md) 为准。本轮按原生骨架执行；不以配置项或纯策略代码代替硬件实现。

**执行方式：** 当前会话直接实施。后续按任务规模采用流程，不要求自动调用 Superpowers、强制 TDD 或子 agent。设计理由保存在 Agent Notes。

## 本轮清单

- [x] 核查 Harness 的 AGENTS/Note 规则、参考项目与 #435/#433，记录来源和实际进度。
- [x] 创建 SwiftPM 核心及应用 target，保持系统副作用与核心策略分开。
- [x] 原生侧栏设置、菜单栏入口、按键/语音偏好编辑、版本化保存和错误保护。
- [x] `VoiceSession.begin/end/cancelAll`、左右 Control 键码与 `AudioInputPriority.reconcile` 纯策略。
- [x] 增加无 XCTest 的行为检查；验证设备抢占、恢复、多会话和配置兼容。
- [x] CLT Release 打包/签名/校验脚本、Make 入口、本地 Homebrew 源码归档与 Formula。
- [x] 建立 Note 生命周期、两项项目技能和文档检查；补齐 README/架构/路线图/验收矩阵。
- [x] 完成最终构建、UI 与本地 Homebrew 验证，按实际结果更新 [验证记录](../../docs/validation/2026-10-27-bootstrap.md)。

本轮按核心逻辑、原生应用、仓库规范与构建分发三阶段分别提交；后续继续按有意义的阶段多次 commit。

## 集成时优先检查

后续适配器要覆盖：CoreAudio 写入失败不能当成功、事件回调不能跨旧会话生效、目标按键必须释放、原生物理动作不能重复、未知配置版本不能被覆盖。接入实现后在对应阶段补充测试与硬件结果。

下一次开发从 [M1](../../docs/roadmap.md) 开始，先确认实际遥控器与 HID 行为，再实现按键接入；语音链路依赖真实设备、协议样例和回环设备，不能通过编译推断已可用。
