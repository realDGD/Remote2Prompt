# Agent Note: Single source Cask

Status: proposed

## Problem

用户要求只保留一个 Homebrew 项，仍以 CLT 编译源码、安装到 Applications、卸载一起清理，减少两份 app。旧 Formula+Cask 满足生命周期，却同时保留 keg 和 Applications 本体，操作与存储都重复。

## Proposal

以单 Cask `remote2prompt` 从固定 GitHub commit 与 SHA-256 归档构建；structured preflight 运行依赖已封闭的 SwiftPM 检查和 CLT 构建。来源信息写入 app 资源后重新临时签名，标准 app artifact 移动唯一 app 到 Applications，binary artifact 管理启动命令。postflight 清理自身构建缓存，Caskroom 的 app 只保留受 Homebrew 管理的链接，不是另一份 app。

普通卸载移除 app、命令与 staged 记录；加 --zap 清本应用设置，系统权限与驱动不在范围内。旧双项用户先正常退出并检查恢复记录，再卸载旧 Cask/Formula。安装验证必须从 HTTPS 重新 tap 下载，不使用本地 checkout 或 file URL。此方案用于本项目第三方 tap，不声称满足官方 homebrew/cask 的预编译分发准入条件。

## Alternatives considered

- Formula 自己向 Applications 写入或手工软链接：缺少对称的标准卸载生命周期，不采用。
- 仅保留下载二进制的普通 Cask：不能满足源码构建。
- 保留两个包并把 Formula 隐藏：仍是两个安装项与两份 app，不能解决用户问题。

## Acceptance criteria

远端新用户安装只有一个 Cask，无配套 Formula；实际 CLT 编译，签名内来源标记匹配。Applications 是真实 app，Caskroom 无第二个 app 目录与 .build；CLI 通过受管理链接定位。arm64/Intel CI 与本机实际安装、卸载、zap、重新安装通过，旧版不会留下悬空链接。

## Risks

这不是 Cask 常规的预编译下载方式，首次安装需要 Swift 6 CLT 和编译时间。brew test 只支持 Formula，改用安装后只读来源/签名/自检与实际卸载验收，不伪报 brew test 成功。Homebrew structured steps 的 sandbox 必须实际验证；失败前不迁移为 implemented。来源：[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)、[brew test](https://docs.brew.sh/Manpage#test-options-installed_formula-)。
