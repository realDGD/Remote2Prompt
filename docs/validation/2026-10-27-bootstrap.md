# M0 验证记录

日期：2026-10-27（Asia/Makassar）。本记录针对本地应用骨架，M0 的本机验证已完成。

## 环境

Apple Silicon arm64，macOS 27.2（26B123）；独立工具链 `/Library/Developer/CommandLineTools`，Swift 6.4，macOS 27 SDK，Homebrew 7.0.11。系统默认 `xcode-select` 指向 Xcode，但本项目脚本在进程内显式使用 CLT，不修改全局选择。

## 已执行

- `DEVELOPER_DIR=/Library/Developer/CommandLineTools /usr/bin/make check`：通过。包括 22/22 核心检查、CLT Release 构建、Info.plist/版本/执行权限/签名检查、应用无界面自检，以及 19 个 Markdown 文件的仓库检查。递归 make 也从独立 CLT 路径执行。
- `dist/Remote2Prompt.app/Contents/MacOS/Remote2Prompt --smoke-test`：通过，真实设置窗口可见后正常退出。
- 原生 UI 检查：侧栏连接、按键映射、语音与音频页面可切换；左右 Control 均出现在触发键菜单中。选择右 Control，退出重开后仍保留，随后恢复默认 Fn。目视检查了当前系统暗色下的连接与语音页面；未穷举所有尺寸、主题和键盘导航。
- 本地 tap 的 `brew install --build-from-source`、更新归档后的 `brew reinstall --build-from-source` 与 `brew test`：通过。最终默认 SwiftPM 驱动的源码重装用时约 44 秒。该次测试归档为 `remote2prompt-0.1.0-315c0c1e1db0.tar.gz`，SHA-256 为 `315c0c1e1db090af313407586b931165f5e86bca657813d4843692c38d33c763`；后续仅更新本文档和清单，重新生成归档的摘要会不同。
- 安装在 Homebrew keg 中的应用也通过 `verify-app.sh`（签名、版本和自检）。验证后卸载临时安装并移除测试 tap；保留仓库中的 `dist/Remote2Prompt.app` 和本地 tap 生成器。
- 两个项目技能通过 `skill-creator/scripts/quick_validate.py`。校验器的 PyYAML 在隔离 uv 环境使用，不是应用或构建依赖。
- 文档检查的负例验证：状态与路径不一致的 Note、失效的本地 Markdown 链接都被拒绝，临时样例已删除。

## 构建中发现的问题

SDK 27 的裸 `@State` 选择了独立 CLT 未附带的 SwiftUIMacros 插件。现用 `ViewState<Value>` 显式引用公开属性包装器，构建不加载 Xcode 插件。Homebrew 的外层沙箱拒绝 SwiftPM 再启动嵌套 sandbox-exec；现仅在 Formula 路径关闭该嵌套层并使用构建目录缓存，外层 Homebrew 沙箱保持启用。

当前 SwiftPM 默认驱动在完整编译时会输出 CLT 中不存在的 `Developer/Library/Frameworks` 等链接搜索目录警告；编译、签名、运行及安装检查均成功，未为消除此工具链警告改用已弃用的 native 驱动。

## 未覆盖

Intel、macOS 14、真实遥控器和输入法、CoreAudio 设备写入、音频驱动安装、正式签名与公证均未验证。远程仓库、公开 tap、Tag 和 Release 尚未创建。
