# Agent Note: 保留实际链接 SDK 的原生窗口行为

Status: implemented

## Problem

设置使用 `NavigationSplitView`，但标题栏和内容区的分隔线仍错位。原生 Form、调整列宽修饰符顺序及紧凑工具栏均未解决。在 CLT SDK 27.0 构建的应用中，Mach-O 却记录 `minos 14.0 / sdk 14.0`，窗口进入旧版兼容外观。Swift Build 上游 [#1887](https://github.com/swiftlang/swift-build/issues/1887) 描述相同的 SDK 元数据错误。

## Decision

`build-app.sh` 在链接阶段显式传入 `-platform_version macos`，分别使用 Info.plist 的最低系统版本和当前选定 CLT 查询得到的真实 SDK 版本。继续使用默认 SwiftPM 构建系统和独立 CLT，不要求完整 Xcode、不硬编码 SDK 27，也不根据运行系统版本猜测构建 SDK。

`verify-app.sh` 检查每个 Mach-O 架构的 platform、minos 和 sdk；最低版本必须与应用要求一致，SDK 必须与本次选定的 CLT 一致。该脚本用于当前工具链的构建验收，不能拿另一台机器的 SDK 去推断已安装包的构建来源。

## Alternatives considered

- 通过 padding、负偏移或自绘分隔线对齐：只能遮盖某个尺寸的外观，不能修复系统兼容模式，未采用。
- 将最低系统要求提高到当前系统：会丢失 macOS 14 支持，混淆运行要求与构建 SDK，未采用。
- 用 `vtool` 在构建后改写二进制：需要额外修改签名前产物；链接器已能写入正确元数据，因此不采用。
- 切换到旧 native 构建系统或完整 Xcode：为一个字段更换整套工具链不必要，仍保持 CLT 默认流程。

## Consequences

相同 SwiftUI 分栏在 SDK 字段修复后使用当前系统原生工具栏和连续分隔线，不需要手工接管窗口。最低运行版本仍为 14.0。UI 验收与自动检查见 [本轮记录](../../../../docs/validation/2026-10-28-native-settings-layout.md)；本机当前系统的预览不能代替 macOS 14、Intel 和真实遥控器验收。
