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

macOS 27 将“辅助功能”权限页改名为“设备控制和数据访问”，旧的 Privacy_Accessibility deep link 仍指向该页。输入监听未允许时直接使用 IOHIDRequestAccess，未获允许时再调用 CGRequestListenEventAccess。未知状态的首次请求不立即打开设置抢走系统提示的焦点；原状态已拒绝时打开设置，另有独立设置入口。已允许时只提供设置入口；macOS 不保证重复弹窗或自动列出条目。监听检查返回 granted 也可能来自设备控制授权，不能据此确认输入监控列表中的独立条目。运行时以实际 HID 打开和报告接收结果验证设备可用性；失败则恢复原生映射并停止。

交互授权验证时仅保留一个构建路径。临时 Homebrew 安装使用同一 Bundle ID，曾影响系统对授权目标的选择；先完成源码安装验证并清理临时副本，再固定 `/Applications/Remote2Prompt.app` 进行权限与硬件验收。不要为触发首次弹窗擅自重置 TCC 或改动隐私数据库。

获用户明确授权后，可用 `tccutil reset ListenEvent dev.remote2prompt.app` 仅清理本应用输入监控选择；先退出应用，再重开相同构建。此命令成功仅证明重置请求成功，不证明系统弹窗恢复；当前机器的重试结果见 [M1 记录](validation/2026-10-27-m1.md)。不要扩大为全应用或其他权限重置。

### 开发签名选择

默认仍是临时签名，其 designated requirement 绑定本次代码哈希，代码变化后系统可能不再接受旧授权。可通过 `CODE_SIGN_IDENTITY='证书名称或指纹' make build` 使用本机已有的代码签名身份；保持同一身份可让系统识别后续版本。该选项不创建证书、不改钥匙串，也不自动签名公证或发布。

无线麦的源码开发构建为临时签名显式指定 `identifier` 识别规则，本项目提供相同语义的可选模式：`REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1 make build`。它只按 `dev.remote2prompt.app` 匹配、没有签名者约束，其他本地程序也能声明同一标识；因此默认关闭，仅在维护者明确接受这一身份边界后用于本地开发，不作为公开分发方案。当前测试应用尚未应用此选项。这些入口仅供后续明确选择；本轮保持默认临时签名，不创建证书、不改钥匙串，也不启用放宽的 identifier 规则。

改变签名方式后，已有授权可能仍须重新关联当前构建。稳定签名用于避免后续身份漂移，不等于保证系统首次弹窗出现；必须另行记录实际授权和按键结果。

`make run` 会打开设置窗口。菜单栏可重开窗口；关闭窗口不会退出进程。执行程序支持 `--version`、`--self-check`；`--smoke-test` 启动真实 AppKit/SwiftUI 窗口，确认存在后自行退出，不访问硬件。

## Homebrew 源码与应用安装

源码仓库为 [realDGD/Remote2Prompt](https://github.com/realDGD/Remote2Prompt)，同一仓库根目录维护 `Formula/` 和 `Casks/`。Formula 固定完整 commit 的归档 URL 和 SHA-256，不引用移动的 main，也不下载预编译二进制。

```sh
brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git
brew install --build-from-source realdgd/remote2prompt/remote2prompt
brew install --cask realdgd/remote2prompt/remote2prompt-app
brew test realdgd/remote2prompt/remote2prompt
open /Applications/Remote2Prompt.app
```

Homebrew 7 若提示第三方来源尚未信任，可用 `brew trust --formula realdgd/remote2prompt/remote2prompt` 与 `brew trust --cask realdgd/remote2prompt/remote2prompt-app` 仅信任这两个条目。旧版没有 `trust` 命令时无需执行；CI 自动检测这一差异。

Formula 先运行检查、CLT Release 构建及 bundle 验证，把 app 保存在 keg 的 `libexec/`。Cask 依赖 Formula，校验源码 SHA-256 标记后复制编译结果，通过标准 `app` artifact 安装本体到 `/Applications`，不是链接。启动命令在应用程序副本与编译结果一致时打开该副本；仅装 Formula 时仍可运行 keg 内应用。默认 Applications 路径下，`brew test` 会核对本体不是软链接、代码与本次构建一致，并运行无界面自检。

升级先更新 tap，再升级 Formula，最后升级 Cask：

```sh
brew update
brew upgrade --build-from-source realdgd/remote2prompt/remote2prompt
brew upgrade --cask realdgd/remote2prompt/remote2prompt-app
brew test realdgd/remote2prompt/remote2prompt
```

先退出应用，确认原生按键恢复完成后再清理设置。完整卸载：

```sh
brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt-app
brew uninstall --formula realdgd/remote2prompt/remote2prompt
brew untap realdgd/remote2prompt
```

普通 Cask 卸载移除应用程序本体；加 `--zap` 清理本应用偏好、ByHost 偏好、缓存、保存状态和 Application Support。Formula 卸载移除 keg 内构建结果和启动命令。不要用全局 `autoremove` 代替这两个精确目标，也不要删除尚有待恢复映射的恢复记录。系统 TCC 授权、音频驱动和其他应用不在清理范围。

### 本地生成与公开 tap 更新

`make homebrew` 仍提供开发用本地归档和 tap：

```sh
make homebrew
brew tap --custom-remote remote2prompt/local "$PWD/dist/homebrew/tap"
brew install --build-from-source remote2prompt/local/remote2prompt
brew install --cask remote2prompt/local/remote2prompt-app
brew test remote2prompt/local/remote2prompt
```

生成器仅归档显式允许的源码、脚本和文档，排除 `.git`、`.build`、`dist` 和本地环境文件。生成目录包含源码归档、Formula、Cask 和 tap README，全部忽略；CI 仅由本源码仓库维护。再次生成后需在安装的 tap checkout 执行 `git pull --ff-only`；不要同时安装本地和远端 Formula。清理 `dist` 会使本地 `file://` 来源失效，远端来源不受影响。

维护者公开新源码时先更新 `VERSION`，完成脱敏、检查和源码提交、推送，再生成固定该提交的 tap：

```sh
ruby scripts/prepare-homebrew.rb --remote "$(git rev-parse HEAD)" --tap realdgd/remote2prompt
```

远端模式要求干净工作树和完整 HEAD SHA，下载真实 GitHub 源码归档计算 SHA-256，输出到 `dist/homebrew-remote/tap`。人工审阅生成目录，不发布本地路径或日志；把生成的 `Formula/remote2prompt.rb` 和 `Casks/remote2prompt-app.rb` 复制到本源码仓库同名目录，审阅、提交并推送，等待同一仓库的 CI。源码提交和固定该提交的配方更新自然分为两次提交；不建立独立 tap 仓库。生成操作本身不推送、不安装。每次源码更新需要更新 tap；源码仓库之后的文档提交不会自动更改已固定的构建来源。

公开源码和 tap 尚未选择许可证；本流程不擅自声明开源授权、不生成 Release/Tag、不分发驱动，也不引入证书或公证。分发理由见 [Agent Note](../.agents/notes/implemented/architecture/2026-10-27-source-tap-app-lifecycle.md)。

## 持续集成

[工作流](../.github/workflows/ci.yml) 响应 main push、pull request 和手动触发。Linux job 检查文档、全部可达历史的本机信息、Gitleaks 凭据及 actionlint 语法；macOS 15 的 arm64 和 Intel job 明确设置独立 CLT，运行 `make check`，再验证本地 tap 生成器，以本仓库作为 tap checkout 下载配方固定的远端源码，在 Homebrew 沙箱中源码安装、用 Cask 安装应用程序本体、`brew test` 和卸载/设置清理。源码、配方与 CI 始终在同一仓库。

第三方 Action 固定提交，检查工具固定版本及 SHA-256，工作流仅使用读取内容权限，不上传二进制或原始诊断。CI 不请求输入监控、辅助功能、蓝牙或麦克风权限，不运行音频输出检查、GUI smoke 或遥控器验收。最低 macOS 14 和实际输入法仍需单独验证。

## 本轮诊断入口

`--list-loopback-devices` 只读列出兼容回环设备名称。`--smoke-test-guide` 以不访问 HID/蓝牙的模式检查设置与拖入帮助面板可见；配合 `--preview-directory /绝对路径` 可导出应用自己的视图预览，缓存图不代替完整原生交互检查。

macOS 检查程序的 `--loopback-output-smoke` 是单独、显式的硬件检查：仅向已识别回环设备写入 800 个静音样本，等待排空，并比较前后系统默认设备快照。普通 `make test` 不运行此硬件检查。

`Remote2Prompt --check-input-catalog` 只读检查真实输入目录、分类及 CoreAudio listener 注册/清理，比较前后默认设备并只输出数量，不打印 UID、设备名或地址，不切换设备、不读取音频。应用的输入优先功能须由用户开启，默认关闭；普通检查与 UI smoke 使用模拟或禁用硬件的运行时。M3 的真实默认输入切换须另行按硬件矩阵验收，不能以该诊断命令代替。

`./scripts/probe-input-runtime.sh` 是独立 CLT 模拟探针：编译实际输入协调器与运行时，全部注入固定模拟系统，观察 6.2 秒空闲、2.2 秒关闭后回调、1000 次即时会话循环与初始化失败恢复。不创建 app、不访问 CoreAudio 设备、不写真实系统输入；产物在 `.build/probes/input-runtime/`。它会报告已知的菜单恢复缺口，退出成功不表示该缺口已修复；结果边界见[运行时审查](research/2026-10-28-idle-runtime-audit.md)。不加入普通 CI 的计时验收。

## 独立设置预览

`./scripts/prepare-ui-preview.sh` 用同一 CLT 构建独立的 `.build/ui-preview/Remote2Prompt.app`，使用专用 Bundle ID 和配置域，不覆盖安装版，也不启动 HID、蓝牙、音频或默认输入写入。它支持实际原生点击与快捷键录入，配置仅用于本次检查，退出时清除。左栏底部明确标记“界面预览”。重建前先退出该预览；脚本拒绝覆盖正在运行或身份不符的副本。

预览副本的 `--smoke-test --preview-directory <输出目录>` 可导出自身视图并自动退出。截图缓存只用于布局检查，不能替代真实控件交互或硬件验收。预览中不要点击系统授权/系统设置入口进行授权测试；真实权限仍需使用固定的实际安装路径。
