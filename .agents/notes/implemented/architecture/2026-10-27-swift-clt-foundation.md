# Agent Note: SwiftPM、CLT 与原生应用分层

Status: implemented

## Problem

项目需要原生 macOS 左栏设置，又必须在没有完整 Xcode 的环境中构建，并让设备和音频策略能够独立验证。

## Decision

使用 Swift 6 / SwiftPM，最低系统为 macOS 14，应用由 SwiftUI 与 AppKit 组成。纯核心、macOS 适配器和原生应用分别在独立 target 中；核心及 macOS 适配器检查为独立 executable target，通过 `make test` 运行，不依赖 XCTest。

构建脚本默认在当前进程中选择 `/Library/Developer/CommandLineTools`，以 `swift build` 生成可执行文件，再构造并临时签名 `.app`。Homebrew 从固定本次内容的源码归档构建；公开远程尚未建立时，生成本地 tap，不猜测远程 URL。

构建使用 CLT 随附的 SwiftPM 默认驱动，避免依赖已弃用的 native 驱动选项。Homebrew 构建由外层沙箱隔离，Formula 仅为这一路径关闭 SwiftPM 子进程嵌套沙箱，并将缓存放入构建目录；否则实测的嵌套 sandbox-exec 会被 macOS 拒绝。普通开发构建保持 SwiftPM 沙箱。

HID、系统按键、原生映射恢复、ATVV 蓝牙音频、PCM 回环输出及默认输入优先适配器已接入。核心只返回意图并处理显式确认，系统副作用集中在 macOS 适配 target；输入优先默认关闭，实际硬件验收独立记录。应用标识符当前为 `dev.remote2prompt.app`，稳定发布前需复核。

当前 SDK 27 的裸 `@State` 会选择 CLT 未附带的宏插件，因此界面使用 `ViewState<Value>` 别名显式选中现有公开属性包装器。构建不加载完整 Xcode 内的插件。

## Alternatives considered

**Xcode 工程和 xcodebuild。** 原生开发便利，但不能满足仅安装 CLT 的构建要求。

**SwiftPM 加 XCTest。** 常见测试方式，但独立 CLT 不提供完整的 XCTest 框架；本项目用无依赖检查 executable 保持同一工具链。

**Cask 分发预编译二进制。** 适合正式签名应用分发，但不满足通过 Homebrew 从源码编译的目标。

## Consequences

本地开发构建默认临时签名，其识别规则绑定代码哈希。构建脚本支持 `CODE_SIGN_IDENTITY` 使用已有证书，另提供本地默认关闭的 `VOIREMOTE_STABLE_ADHOC_IDENTITY=1`，语义参考无线麦的开发构建。后者只匹配应用标识，没有签名者约束；用户后续明确选择在Homebrew源码构建中试用，源码与公开Cask已接入；安装迁移和真实授权保留单独记录。公开二进制分发仍需独立确定稳定签名及公证方案。

签名集中在`scripts/sign-app.sh`，本地普通构建仍默认哈希身份。`scripts/check-signing-identity.sh`用不启动的副本检查更新、来源信息重签、错误身份和内容完整性。用户后续选择的Homebrew固定身份试验见[决定](2026-10-29-certificate-free-upgrade-identity.md)，离线匹配不等于实际TCC授权保留。

构建、测试和本地源码安装共用一个 Package，无额外包管理依赖。应用包、版本和签名由脚本维护；原创图标由系统 CoreGraphics/ImageIO 在 CLT 中生成并用 iconutil 打包，不依赖 Xcode 资产编译器。后续资源也必须通过脚本显式打包。临时签名和单机编译不能替代公证、Intel 或最低系统验收。
