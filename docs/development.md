# 构建与安装

## 工具链

macOS 14+，安装包含 Swift 6 的 Command Line Tools。根目录的 `Package.swift` 是唯一工程定义；没有 `.xcodeproj`、私有包或网络依赖。`scripts/toolchain.sh` 为当前进程设置 `DEVELOPER_DIR`，默认使用独立 CLT，不修改系统的开发者目录。

脚本使用 CLT 随附的 SwiftPM 默认构建系统。Formula 设置 `REMOTE2PROMPT_HOMEBREW_BUILD=1`，把 SwiftPM 缓存限制在构建目录并关闭其子进程的嵌套 sandbox-exec；Homebrew 自身的构建沙箱仍生效。普通构建不关闭 SwiftPM 沙箱。

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools xcrun swift --version
make test
make build
./scripts/verify-app.sh
```

默认 Release 产物为 `dist/Remote2Prompt.app`，只包含当前架构。`CONFIGURATION=debug make build` 可生成调试包。脚本将 `VERSION` 写入 Info.plist，以临时签名生成可运行 bundle；临时签名不等于 Developer ID、公证或可公开分发的正式包。

必须先退出从目标路径运行的 app 再重建；构建脚本会拒绝覆盖运行中的应用。临时签名的指定要求绑定代码摘要，更新构建可能使原有 TCC 授权不再匹配。运行时用 Security API 检测磁盘与进程代码不一致并暂停映射，避免把旧进程权限误当作新构建状态。不要通过修改隐私数据库或放宽签名要求绕过授权。

macOS 27 将“辅助功能”权限页改名为“设备控制和数据访问”，旧的 Privacy_Accessibility deep link 仍指向该页。输入监听未允许时直接使用 IOHIDRequestAccess 请求并打开设置，已允许时只提供设置入口；macOS 不保证重复弹窗或自动列出条目。监听检查返回 granted 也可能来自设备控制授权，不能据此确认输入监控列表中的独立条目。运行时以实际 HID 打开和报告接收结果验证设备可用性；失败则恢复原生映射并停止。

交互授权验证时仅保留一个构建路径。临时 Homebrew 安装使用同一 Bundle ID，曾影响系统对授权目标的选择；先完成源码安装验证并清理临时副本，再冻结 `dist` 构建进行权限与硬件验收。不要为触发首次弹窗擅自重置 TCC 或改动隐私数据库。

`make run` 会打开设置窗口。菜单栏可重开窗口；关闭窗口不会退出进程。执行程序支持 `--version`、`--self-check`；`--smoke-test` 启动真实 AppKit/SwiftUI 窗口，确认存在后自行退出，不访问硬件。

## 本地 Homebrew 路径

没有远程地址时，运行 `make homebrew`，生成：

```text
dist/homebrew/
  remote2prompt-<version>-<digest>.tar.gz   固定本次内容的源码归档
  tap/                                   仅含本地 Formula 的生成 Git 仓库
    Formula/remote2prompt.rb
```

生成器仅归档显式允许的源码、脚本和文档，排除 `.git`、`.build`、`dist` 和本地环境文件。Formula 使用归档的 `file://` URL 与 SHA-256，不访问未知远程仓库。tap 的自动提交只发生在忽略的生成目录，不提交本项目源码，也不修改用户 Git 身份。

```sh
make homebrew
brew tap --custom-remote remote2prompt/local "$PWD/dist/homebrew/tap"
brew install --build-from-source remote2prompt/local/remote2prompt
brew test remote2prompt/local/remote2prompt
remote2prompt --version
remote2prompt
```

Formula 将应用放在 keg 的 `libexec/`，提供 `remote2prompt` 启动命令，不自动复制到 `/Applications`，不安装音频驱动。需要“应用程序”入口时，可按 README 自行建立链接。已有同名路径时先确认归属，不覆盖其他应用。

改动源码后再次生成和安装：

```sh
make homebrew
git -C "$(brew --repo remote2prompt/local)" pull --ff-only
brew reinstall --build-from-source remote2prompt/local/remote2prompt
```

本地 tap 引用 `dist/homebrew` 内的归档；清理生成文件会使该 tap 无法重新取回旧源码。重装前重新执行 `make homebrew` 并更新 tap。卸载与清理：

```sh
brew uninstall remote2prompt/local/remote2prompt
brew untap remote2prompt/local
```

若曾手动创建 `/Applications/Remote2Prompt.app` 软链接，卸载后仅删除该软链接。保留的本机偏好不随 Homebrew 卸载删除。

## 公开发布前

必须先明确真实仓库地址、许可证、Bundle ID 和版本，再将 [Formula 模板](../packaging/homebrew/remote2prompt.rb.in) 的生成来源换为固定 Tag/归档 URL，核对 SHA-256。公开 tap 不能使用本机 `file://` 路径。Homebrew Formula 的源码构建与 Cask 的预编译分发是两条路径；当前不创建公开 tap、Tag、Release 或自动更新服务。
