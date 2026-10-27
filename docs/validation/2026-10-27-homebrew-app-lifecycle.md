# Homebrew 远端源码与应用生命周期验证

日期：2026-10-27。用户明确授权提交、脱敏、公开仓库/tap、推送和 CI，以及删除现有应用、清空本应用设置后从远端源码安装。沿用 [public 源码仓库](https://github.com/realDGD/Remote2Prompt)。用户随后明确要求源码、配方和 CI 均放在同一仓库，因此最终 tap 直接指向该仓库，独立 tap 试运行不作为最终入口。无驱动、证书、钥匙串、TCC 或默认音频设备变更。

## 实现与本机首轮结果

- Formula 负责独立 CLT 的 52 项核心与 40 项适配器检查、Release 构建、bundle 验证及源码标记；配套 Cask 校验标记，安装本机编译的 app 到 `/Applications/Remote2Prompt.app`。
- `.gitignore` 补充 app/dmg/pkg；生成 tap、归档、工具和原始日志仍留在 ignored 目录。公开前受跟踪快照和全部可达历史扫描、Gitleaks、actionlint、文档检查通过。
- 0.1.1 固定源码 `b5f6afde9c2008082cc306ebaf8602a90e7cbd29`，归档 SHA-256 为 `a68ef068de69ecd516b3125dfaf1ebab3079d355f77443cc31e28944851855c8`。实际从 GitHub tap 下载、在 Homebrew 沙箱中源码编译安装成功；未使用 bottle。
- Cask 实际安装本体，`brew test realdgd/remote2prompt/remote2prompt` 通过，检查 keg 与应用程序中的代码一致、无界面自检和版本。
- 写入合成偏好与缓存标记，执行 Cask `--zap` 卸载再卸载 Formula；确认应用程序本体、Caskroom 版本、启动命令、opt 链接、合成偏好和缓存均被清除。未运行全局 autoremove。
- 卸载旧版本时先检查无运行应用和待恢复日志；删除已核对 Bundle ID 的开发 app、手工应用程序链接及旧本地 tap，只清空本应用偏好、支持文件、缓存和保存状态。

## CI 中发现的工具链差异

源码 [首轮 CI](https://github.com/realDGD/Remote2Prompt/actions/runs/40499836672) 和 tap [首轮 CI](https://github.com/realDGD/homebrew-remote2prompt/actions/runs/40499938936) 的 ARM runner 使用 Swift 6.1.2，拒绝在 `main.swift` 内使用异步 `@main`；本机 Swift 6.4 没有报错。M3 新增异步退出检查后首次暴露这一差异。

将检查入口改名为 `MacChecks.swift`，由 SwiftPM 使用标准 `@main` 入口解析；不删除或跳过测试、不换完整 Xcode。新源码版本为 0.1.2；本机 92 项检查再次通过。修复后的云端结果、最终固定源码和清洁安装结果随实际完成追加，不将首次本机成功当作跨版本通过。

## 验证边界

安装与卸载不验证输入监控弹窗、真实遥控器语音、目标输入法、默认输入抢占恢复或最低 macOS 14。临时签名更新后可能需要重新关联授权；本次不重置系统隐私记录。项目尚未选择许可证，没有发布 Tag、Release、二进制或音频驱动。
