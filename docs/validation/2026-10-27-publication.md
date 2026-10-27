# 公开维护与 CI 验证

日期：2026-10-27。仓库：[realDGD/Remote2Prompt](https://github.com/realDGD/Remote2Prompt)。本次用户明确授权编写 Note、补齐忽略规则、脱敏、本地提交、创建 public 仓库、push 和设置 CI。

## 公开内容与脱敏

公开前检查原有 14 个提交、172 个文件内容对象。Gitleaks 8.30.1 全历史扫描未发现凭据；个人目录、用户临时路径、硬件地址与非标准外设 UUID 扫描未命中。未跟踪构建、原始诊断、录音或签名材料。Git 作者为已核对的 GitHub noreply 邮箱。没有删除或重写原有分阶段提交，也没有上传本地工具、扫描原始报告或 ignored 文件。

`.gitignore` 增加本地诊断、录音、捕获、证书/私钥和编辑器状态。发布检查器覆盖当前受跟踪文件和全部可达历史的路径及文本，只打印位置与类别。合成负例验证了：干净快照通过；强制跟踪的环境文件和用户目录被拒绝；删除最新值后历史仍被拒绝；原始值不出现在错误信息中。负例仅保存在忽略的本地构建目录，未提交。

新增提交也须在推送前运行全历史脱敏和 Gitleaks；不把一次扫描当作后续自动推送的授权。

## 持续集成范围

[CI](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml) 在 Linux 上检查文档、全历史脱敏、Gitleaks 与 actionlint；macOS 15 的 arm64、Intel 分别通过独立 CLT 运行 `make check`，再用生成的本地 tap 在 Homebrew 沙箱中源码安装、`brew test`、应用自检及卸载。Action 固定提交，检查工具固定版本与 SHA-256，GitHub Token 只有读取内容权限，不保留 checkout 凭据、不创建发布资产。

本地 `make check` 通过：45/45 核心检查、20/20 macOS 模拟检查、独立 CLT Release、bundle/签名/版本自检、文档和当前源码脱敏。`make homebrew` 成功生成本地归档和 Formula；源码归档包含工作流，保持相对文档链接完整。工作流通过本地 actionlint 语法检查。云端实际结果以 Actions 中对应提交的 run 为准，本记录不提前宣称任何云端任务通过。

首次云端运行发现 CLT Swift 6.1.2 对测试入口的数组连续相加表达式推断超时，而本机 Swift 6.4 可以编译。修复为显式类型的数组加逐次 append(contentsOf:)，不删除测试、不提高超时或改用完整 Xcode；云端后续运行继续验证两种架构。

## 仍然独立的验收

CI 不访问真实遥控器，不操作系统隐私开关，不启动录音，不运行真实音频输出检查或 GUI smoke。因此系统输入监控弹窗、真实说话、目标输入法识别、最低 macOS 14 和驱动安装仍沿用[设置与语音记录](2026-10-27-settings-and-voice.md)中的未验收边界。

首次公开时没有选择开源许可证，没有发布二进制、Tag、Release 或公开 Homebrew tap，也没有创建本地证书。后续用户明确授权的固定远端源码安装和同仓库 tap 结果见 [应用生命周期验证](2026-10-27-homebrew-app-lifecycle.md)。
