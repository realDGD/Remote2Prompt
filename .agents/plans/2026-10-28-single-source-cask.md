# Single source Cask implementation plan

**Goal:** 一个 Homebrew 安装项，固定远端源码、独立 CLT 编译、应用程序本体、成套卸载，不保留第二份 app。

**Architecture:** 单 Cask `voiremote` 在 preflight 编译源码；标准 app artifact 移动 app 并保留受管理链接。postflight 清理 SwiftPM 构建缓存，binary artifact 管理启动命令。源代码与配方仍分阶段提交，同一 public 仓库维护。

**Tech Stack:** SwiftPM、macOS 14+ CLT、Homebrew Cask structured steps、Bash/Ruby。

**Spec:** 本线程用户要求；现有产品与构建约束见 [product](../../docs/product.md)、[development](../../docs/development.md)。按用户约定本线程直接实施，不启动自动子 agent、额外审批或强制 TDD。

## Global Constraints

- 不使用 xcodebuild、证书、驱动或 TCC 修改，不改产品行为。
- 所有安装测试从 GitHub HTTPS tap 和固定 commit 归档开始；本地 checkout 只做代码/生成/静态检查，不能作为安装来源。
- Cask 不支持 brew test；以安装版本、签名、来源标记、配置自检、单份 app 和卸载清理验收替代。
- 自动任务保持删除。

## Review Focus

源码根目录与 sandbox 写权限；编译失败不覆盖已有 app；不同 appdir 下启动器定位；卸载后无 CLI/悬空链接/残留 app；旧双项迁移不丢失待恢复的 HID 映射。

## Tasks

### 1. 构建与验收入口

Files: `scripts/build-cask.sh`、`scripts/verify-homebrew-install.sh`、`packaging/homebrew/voiremote`、`packaging/homebrew/voiremote.rb.in`、`scripts/prepare-homebrew.rb`。

Interfaces: build-cask 接受 `VERSION COMMIT SHA256`，输出 `dist/VoiRemote.app` 和签名内 `HomebrewSource.plist`；verify-homebrew-install 接受相同参数及可选 appdir，只读验收。

- [x] 实现参数校验、核心/适配器检查、CLT 构建、来源签名与 bundle 验证；CLI 经 staged app 链接定位实际 app。
- [x] 单 Cask 模板无 Formula 依赖，处理 GitHub 归档根路径；postflight 只清理自身 `.build`/`.swiftpm`。
- [x] 静态生成、Ruby/Bash 语法和无效参数检查；CLT make check（69/69、59/59）；源码 `ee59f4e` 已提交推送。

### 2. 远端配方与 CI

Files: `Casks/voiremote.rb`、移除旧 Formula/Cask、`.github/workflows/ci.yml`、README、development、testing、检查技能。

- [x] 生成固定已发布源码的 Cask，移除旧配方；更新单项安装/卸载与旧版迁移命令。
- [x] 配置 CI 从 HTTPS 远端 tap 安装，两架构验证来源、单 app、CLI、自检、卸载与 zap；不以 checkout/file URL 安装。
- [x] 推送配方后，本机移除旧双项、untap，按新用户命令从远端重新 tap/install。

### 3. 生命周期与交付

- [x] 核对只有一个 Cask，无 Formula/legacy Cask；Applications 真实本体，Caskroom 无第二个 app，构建缓存清理。
- [x] 实际卸载并核对 app/CLI/设置/记录清理，再从远端安装作为最终版本；另验证启动器链接链与带空格 appdir。
- [x] Note 迁移为 implemented 并归档旧 Note，提交交付记录；最终 HEAD CI 由交付时核实并记入本机检查点，不循环补填 CI 提交。
