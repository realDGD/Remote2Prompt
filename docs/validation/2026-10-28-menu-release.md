# 0.2.1 菜单简化与远端源码安装

日期：2026-10-28。用户再次授权源码提交、公开仓库、CI、删除旧构建、清空本应用设置与远端 Homebrew 源码安装。复用现有 public 仓库 [realDGD/Remote2Prompt](https://github.com/realDGD/Remote2Prompt)，不创建重复仓库或独立 tap，不恢复已删除的自动任务。

## 发布范围

菜单栏两组设备改为原生 Section 与 inline Picker，去掉嵌套菜单；设备选择、语音事务和禁用条件保持原有逻辑。版本为 0.2.1。研究中已复现的输入初始化恢复缺口仍是 proposed，未混入本次菜单更新。

更新所属分发 Agent Note，修正独立 tap 仓库已删除的事实；gitignore 额外排除 ZIP、tar.gz 和 tgz 生成归档，沿用构建、原始日志、配置导出及签名材料的忽略规则。不加入设备身份、原始 HID、录音或私人路径。

## 交付清单

- [x] `make check`：核心 69/69、适配器 59/59，独立 CLT Release/bundle、文档及脱敏通过；`ruby scripts/check-publication.rb --history` 覆盖全部可达历史，忽略规则样例核对通过。
- [ ] 源码提交推送，固定该提交的远端归档 SHA-256，配方单独提交推送。
- [ ] 核对新配方 CI 的仓库检查及 arm64/Intel 源码安装检查。
- [ ] 旧应用正常退出，确认原生按键恢复记录，移除旧 app、Formula 和本应用设置；不保留开发构建 app。
- [ ] 从同仓库远端 tap 构建并安装本体到 `/Applications/Remote2Prompt.app`，运行 brew test。
- [ ] 核对安装版本、源码校验标记、实际目录、代码与 keg 一致、严格签名及设置清洁。

## 原生与硬件边界

此前原生 Computer Use 返回 Mac 锁屏，菜单展开、勾选和键盘导航尚未目视验收。CI 和 brew test 不等同这项验收，也不证明遥控器语音、目标输入法或真实默认输入恢复成功。本轮不创建证书、不重置 TCC、不安装或移除音频驱动。
