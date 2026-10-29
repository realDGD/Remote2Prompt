# Agent Note: Single source Cask

Status: implemented

## Problem

用户要求只保留一个 Homebrew 项，仍以 CLT 编译源码、安装到 Applications、卸载一起清理，减少两份 app。旧 Formula+Cask 满足生命周期，却同时保留 keg 和 Applications 本体，操作与存储都重复。

## Decision

以单 Cask `remote2prompt` 从固定 GitHub commit 与 SHA-256 归档构建；structured preflight 运行依赖已封闭的 SwiftPM 检查和 CLT 构建。来源信息写入 app 资源后重新临时签名，标准 app artifact 移动唯一 app 到 Applications，binary artifact 管理启动命令。postflight 清理自身构建缓存，Caskroom 的 app 只保留受 Homebrew 管理的链接，不是另一份 app。0.2.14开发源码的初次/最终签名与策略声明采用用户选择的[固定身份试验](2026-10-29-certificate-free-upgrade-identity.md)，当前公开Cask与安装版尚未迁移，不把源码接入说成系统授权已保留。

普通卸载移除 app、命令与 staged 记录；加 --zap 清本应用设置，系统权限与驱动不在范围内。旧双项用户先正常退出并检查恢复记录，再卸载旧 Cask/Formula。安装验证必须从 HTTPS 重新 tap 下载，不使用本地 checkout 或 file URL。此方案用于本项目第三方 tap，不声称满足官方 homebrew/cask 的预编译分发准入条件。

## Alternatives considered

- Formula 自己向 Applications 写入或手工软链接：缺少对称的标准卸载生命周期，不采用。
- 仅保留下载二进制的普通 Cask：不能满足源码构建。
- 保留两个包并把 Formula 隐藏：仍是两个安装项与两份 app，不能解决用户问题。

## Consequences

本机已先卸载旧双项并 untap，再从公开 HTTPS 仓库重新克隆 tap、安装 0.2.2。实际 Homebrew sandbox 内核心 69/69、适配器 59/59、CLT 构建通过；安装后来源标记、严格签名、自检、CLI、无 Formula/旧 Cask、无第二份 app 和 .build 检查通过。实际 uninstall --zap 清除了 app、命令、Caskroom 与合成偏好，完整结果及重新安装记录见[验证](../../../../docs/validation/2026-10-28-single-source-cask.md)。

首次安装需要 Swift 6 CLT 和编译时间，Homebrew 仍保留普通源码归档缓存与安装元数据。brew test 只支持 Formula，本项目改用安装期检查、安装后来源/签名/配置自检与实际卸载验收，不伪报 brew test 成功。此第三方 tap 的方式依赖 structured steps 的 sandbox 支持；未验证的最低系统、UI 和硬件边界仍单列。

后续0.2.9继续沿用同仓库单Cask，从公开HTTPS新克隆tap和固定源码清洁安装，不保留原设置；98/99安装期检查、首次启动自检、单app来源与签名验证通过。安装版自动显示首次向导；`brew test`实际返回无Formula而非成功。该轮真实记录见[发布与首次安装](../../../../docs/validation/2026-10-29-source-release.md)。

旧双项决定作为[历史](../../archived/architecture/2026-10-27-source-tap-app-lifecycle.md)归档。来源：[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[brew test](https://docs.brew.sh/Manpage#test-options-installed_formula-)。
