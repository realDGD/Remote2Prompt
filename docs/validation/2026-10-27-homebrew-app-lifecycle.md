# Homebrew 远端源码与应用生命周期验证

日期：2026-10-27。用户明确授权提交、脱敏、公开仓库/tap、推送和 CI，以及删除现有应用、清空本应用设置后从远端源码安装。沿用 [public 源码仓库](https://github.com/realDGD/VoiRemote)。用户随后明确要求源码、配方和 CI 均放在同一仓库，因此最终 tap 直接指向该仓库，独立 tap 试运行不作为最终入口。无驱动、证书、钥匙串、TCC 或默认音频设备变更。

## 实现与本机首轮结果

- Formula 负责独立 CLT 的 52 项核心与 40 项适配器检查、Release 构建、bundle 验证及源码标记；配套 Cask 校验标记，安装本机编译的 app 到 `/Applications/VoiRemote.app`。
- `.gitignore` 补充 app/dmg/pkg；生成 tap、归档、工具和原始日志仍留在 ignored 目录。公开前受跟踪快照和全部可达历史扫描、Gitleaks、actionlint、文档检查通过。
- 0.1.1 固定源码 `b5f6afde9c2008082cc306ebaf8602a90e7cbd29`，归档 SHA-256 为 `a68ef068de69ecd516b3125dfaf1ebab3079d355f77443cc31e28944851855c8`。实际从 GitHub tap 下载、在 Homebrew 沙箱中源码编译安装成功；未使用 bottle。
- Cask 实际安装本体，`brew test realdgd/voiremote/voiremote` 通过，检查 keg 与应用程序中的代码一致、无界面自检和版本。
- 写入合成偏好与缓存标记，执行 Cask `--zap` 卸载再卸载 Formula；确认应用程序本体、Caskroom 版本、启动命令、opt 链接、合成偏好和缓存均被清除。未运行全局 autoremove。
- 卸载旧版本时先检查无运行应用和待恢复日志；删除已核对 Bundle ID 的开发 app、手工应用程序链接及旧本地 tap，只清空本应用偏好、支持文件、缓存和保存状态。

## CI 中发现的工具链差异

源码 [首轮 CI](https://github.com/realDGD/VoiRemote/actions/runs/40499836672) 和 tap [首轮 CI](https://github.com/realDGD/homebrew-voiremote/actions/runs/40499938936) 的 ARM runner 使用 Swift 6.1.2，拒绝在 `main.swift` 内使用异步 `@main`；本机 Swift 6.4 没有报错。M3 新增异步退出检查后首次暴露这一差异。

将检查入口改名为 `MacChecks.swift`，由 SwiftPM 使用标准 `@main` 入口解析；不删除或跳过测试、不换完整 Xcode。新源码版本为 0.1.2；本机 92 项检查再次通过。修复后的云端结果、最终固定源码和清洁安装结果随实际完成追加，不将首次本机成功当作跨版本通过。

## 单仓库最终安装

用户补充“都放在一个仓库”，因此 `Formula/voiremote.rb`、`Casks/voiremote-app.rb`、源码与 `.github/workflows/ci.yml` 全部在 [VoiRemote](https://github.com/realDGD/VoiRemote) 维护。初次尝试的独立 tap 已停止工作流并归档，没有继续作为安装来源；未不可逆删除仓库。安装 tap 的实际 origin 为本源码仓库。

- 0.1.2 固定源码 `a1ca490dbdb112d70b34bb74610b03ca869ba9f4`；归档 SHA-256 为 `0ea4992a42beb5e96fcfd70af981f169946b93025923ed0b9867abf9e9753a7a`。后续 `f8aba59` 提交将此归档固定进根目录配方。
- 移除旧 tap checkout，使用显式源码仓库 URL 重新 tap，并仅信任该 Formula/Cask；没有对整个第三方来源放宽信任。
- `brew install --build-from-source realdgd/voiremote/voiremote` 成功，用时 1 分 28 秒；运行 52/52 核心、40/40 适配器检查、CLT Release 和 bundle 验证。安装收据确认 `poured_from_bottle=false`、`built_as_bottle=false`。
- `brew install --cask realdgd/voiremote/voiremote-app` 成功；`/Applications/VoiRemote.app` 为真实 app 目录，非软链接。Formula 保留 Homebrew 管理的源码产物。
- 最终 `brew test realdgd/voiremote/voiremote` 成功，包括本体/源码产物代码一致、版本及无界面自检；`codesign --verify --deep --strict` 通过，签名仍为 adhoc，无 Team ID。
- 实际运行应用程序本体的 `--smoke-test`，窗口可见且正常自行退出；未访问 HID/蓝牙/音频。随后清空 AppKit 新生成的窗口布局偏好，确认偏好键数量为 0，无保存映射/连接设置和支持文件。没有保留旧设置，未重置 TCC。
- 仓库 `dist` 和历史 `.build` 中开发 app 已删除。最终保留 `/Applications` 的 Cask 本体与 Cellar 中 Formula 管理的构建结果；本机没有后台运行应用。

[同仓库 CI](https://github.com/realDGD/VoiRemote/actions/workflows/ci.yml) 同时验证候选源码的检查/构建和配方固定的真实远端源码安装、实际应用本体、`brew test`、卸载及合成偏好清理。ARM/Intel 云端结果按对应提交的 Actions run 判断，本机结果不替代云端结果；最终文档提交不改变配方固定的运行代码。

## 验证边界

安装与卸载不验证输入监控弹窗、真实遥控器语音、目标输入法、默认输入抢占恢复或最低 macOS 14。临时签名更新后可能需要重新关联授权；本次不重置系统隐私记录。项目尚未选择许可证，没有发布 Tag、Release、二进制或音频驱动。
