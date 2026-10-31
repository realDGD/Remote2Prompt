# 0.2.0 远端源码清洁安装

日期：2026-10-28。沿用单一 public 仓库 [realDGD/VoiRemote](https://github.com/realDGD/VoiRemote)，未创建第二个 tap 仓库。

## 固定来源

- 源码版本：`0.2.0`，commit `d33e92182e04f8e49d8f1ab7795220041ba03641`。
- 配方提交：`e4b1fa82a521ab2687b0a12bba8c6be4445acfa1`，同仓库根目录 `Formula/`、`Casks/`。
- GitHub 源码归档 SHA-256：`d85563605a7a22d2bdfb377b3842c099422b3f835d9d75ea0fbaa3788dd4fc6a`，生成器实际下载计算。
- 公开前：核心 69/69、适配器 59/59，独立 CLT Release/bundle；全部可达历史脱敏、Gitleaks 36 个提交无泄漏、actionlint、文档检查通过。后续文档提交继续检查。

## 清理和安装

1. 核对旧应用身份及恢复记录：待恢复原始映射为零。
2. `brew uninstall --cask --zap realdgd/voiremote/voiremote-app`：Homebrew 确认旧应用正常退出，移除 Applications 本体，清理本应用偏好、支持文件、缓存与保存状态。
3. 精确卸载旧 Formula；移除已验证身份且未运行的 `dist/VoiRemote.app` 与独立预览 app，刷新本应用偏好域。没有清理其他应用、驱动、系统蓝牙配对或 TCC。
4. tap checkout 从 `https://github.com/realDGD/VoiRemote.git` 快进到新配方；从固定远端源码归档运行 `brew install --build-from-source realdgd/voiremote/voiremote`。
5. Formula 沙箱中检查 69/69 与 59/59，通过 CLT 构建及 bundle 验证，安装到 `Cellar/voiremote/0.2.0`；记录构建时间约 1 分 33 秒。
6. `brew install --cask realdgd/voiremote/voiremote-app` 将该编译产物安装到 `/Applications/VoiRemote.app`，然后 `brew test realdgd/voiremote/voiremote` 通过。

## 安装后核对

应用程序路径是实际目录而非软链接；Bundle ID、0.2.0 版本、严格签名验证通过，应用执行文件与 keg 中编译产物逐字节一致，源码 SHA 标记匹配。启动前确认本应用偏好不存在，未迁移旧设置。

安装版 `--check-input-catalog` 通过：3 项输入、18 个 listener 清理，默认输入/输出未变化，不采集音频。`brew test` 证明安装和无界面配置自检，不证明真实遥控器语音。

## CI 与界面边界

配方提交的 [CI](https://github.com/realDGD/VoiRemote/actions/runs/40539025053) **3/3 通过**：仓库/历史/凭据与工作流检查、arm64 和 Intel 的 CLT 检查，两个架构均完成固定远端源码的 Formula/Cask 安装、brew test、Applications 卸载与设置清理。它覆盖固定的 0.2.0 代码与配方；后续文档提交有各自 CI，不将这次结果冒充未来提交结果。

本机 Mac 在安装后已锁屏，原生安装版菜单和首次窗口检查暂未执行，已请求用户回到电脑后解锁；没有绕过锁屏。此前独立预览的向导、文件面板和按键显示结果见[交互记录](2026-10-28-usability.md)。未重新授权系统权限、未安装音频驱动、未做真机说话或真实默认输入写入。
