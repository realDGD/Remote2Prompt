# 0.2.1 菜单简化与远端源码安装

日期：2026-10-28。用户再次授权源码提交、公开仓库、CI、删除旧构建、清空本应用设置与远端 Homebrew 源码安装。复用现有 public 仓库 [realDGD/VoiRemote](https://github.com/realDGD/VoiRemote)，不创建重复仓库或独立 tap，不恢复已删除的自动任务。

## 发布范围

菜单栏两组设备改为原生 Section 与 inline Picker，去掉嵌套菜单；设备选择、语音事务和禁用条件保持原有逻辑。版本为 0.2.1。研究中已复现的输入初始化恢复缺口仍是 proposed，未混入本次菜单更新。

更新所属分发 Agent Note，修正独立 tap 仓库已删除的事实；gitignore 额外排除 ZIP、tar.gz 和 tgz 生成归档，沿用构建、原始日志、配置导出及签名材料的忽略规则。不加入设备身份、原始 HID、录音或私人路径。

## 交付清单

- [x] `make check`：核心 69/69、适配器 59/59，独立 CLT Release/bundle、文档及脱敏通过；`ruby scripts/check-publication.rb --history` 覆盖全部可达历史，忽略规则样例核对通过。
- [x] 源码提交推送，固定该提交的远端归档 SHA-256，配方单独提交推送。
- [x] 核对现有 CI 配置并触发新配方检查，包含仓库/历史/Gitleaks/actionlint 及 arm64/Intel 的 CLT 源码安装、brew test、卸载清理；最终文档 HEAD 的实际结果由交付时核对 [Actions](https://github.com/realDGD/VoiRemote/actions/workflows/ci.yml)，不为补填结果循环触发提交。
- [x] 旧应用正常退出，确认原生按键恢复记录，移除旧 app、Formula 和本应用设置；不保留开发构建 app。
- [x] 从同仓库远端 tap 构建并安装本体到 `/Applications/VoiRemote.app`，运行 brew test，通过。
- [x] 安装版本 0.2.1、源码校验标记、实际目录、代码与 keg 一致、严格签名及设置清洁均通过。

## 固定来源

源码提交 `1f91c0e0defa05896e4dea356df007160fb8d700` 已推送，包含菜单简化及 0.2.1 版本。生成器从 GitHub 实际下载该提交归档，SHA-256 为 `5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686`。配方引用该不可变来源，研究提案和本地实验不作为已实现能力发布。

配方提交为 `a60c3d7ab7b5264876f89f43ba6efe0fb48bf707`。本机 tap checkout 以显式 GitHub 来源快进更新，安装前实际核对两个配方的版本、完整源码 SHA 和归档校验和；未从本地 tap 或移动的 main 构建。独立生成的本地 tap 仅做打包语法验证，没有用来安装。远端归档另检查 154 个条目，未包含本地实验、构建、日志、录音或签名材料。

## 清洁安装实测

1. 旧版 0.2.0 运行时未发现待恢复的原生映射记录；Cask `uninstall --zap` 确认应用正常退出，然后移除 Applications 本体及本应用设置。旧 Formula 单独精确卸载。
2. 核对 Bundle ID 和无运行进程后删除 `dist/VoiRemote.app`；独立界面预览 app 不存在。刷新本应用偏好域，未备份或迁移旧设置。
3. 运行 `brew install --build-from-source realdgd/voiremote/voiremote`，Homebrew 沙箱内核心 69/69、适配器 59/59、独立 CLT 构建及 bundle 验证通过。Formula 编译安装约 1 分 35 秒，位于 `Cellar/voiremote/0.2.1`。
4. 运行 `brew install --cask realdgd/voiremote/voiremote-app`，复制本机编译结果并安装到 `/Applications/VoiRemote.app`。随后 `brew test realdgd/voiremote/voiremote` 退出成功，覆盖配置自检、版本、源码校验标记、应用程序本体与 keg 的一致性。
5. 额外核对 Bundle ID、0.2.1 版本、非软链接、执行文件摘要一致及 `codesign --verify --deep --strict`，均通过；CLI `--version` 与 `--self-check` 通过。首次普通启动前，生产偏好、ByHost 偏好、Application Support、缓存和保存状态均不存在，旧开发 app 也不存在。

本次没有修改系统隐私记录、蓝牙配对、证书或音频驱动。原始构建和安装输出保留在被忽略的本机目录，不提交公开仓库。

## 原生与硬件边界

此前原生 Computer Use 返回 Mac 锁屏，菜单展开、勾选和键盘导航尚未目视验收。CI 和 brew test 不等同这项验收，也不证明遥控器语音、目标输入法或真实默认输入恢复成功。本轮不创建证书、不重置 TCC、不安装或移除音频驱动。
