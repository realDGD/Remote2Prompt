# Remote2Prompt

[![CI](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml/badge.svg)](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml)

面向 macOS 的原生遥控器语音与按键工具，以 Swift 编写，采用左栏设置，通过 Command Line Tools 构建，支持 Homebrew 从源码安装。

当前是**按键与语音链路开发预览**：已接入 HID、原生键接管与恢复、普通手势、快捷键、独立语音触发，以及 ATVV → IMA/DVI ADPCM → 16 kHz PCM → 所选回环设备的代码链路。**真实遥控器说话、目标输入法识别及完整故障回归尚未验收，代码接入不等于语音输入已验证成功。** 当前结果见 [本轮验证](docs/validation/2026-10-27-settings-and-voice.md)，历史见 [M1 记录](docs/validation/2026-10-27-m1.md)。

## 使用

先在系统蓝牙中配对遥控器，运行设置向导，或在“权限与隐私”页请求设备控制授权。不要同时运行另一款遥控器映射软件。

“按键映射”常驻左侧遥控器示意，点击按键可定位右侧设置。语音键置顶，直接设置开关与触发键；普通键按方向导航、常用按键、设备控制分组，单击、双击、长按三列同时编辑。键盘图标直接录入快捷键，点击已有快捷键可重录，清除按钮直接移除动作；录入候选确认后才保存。底部显示最近输入与发送请求，不保存输入文字。

映射页的“启用语音触发”独立于普通映射。选择 Fn 或左右 Control/Command/Option，在输入法中设置同一触发键。需要遥控器声音时，选择已安装的 MiRemoteV 2ch / BlackHole 2ch，再开启“接收遥控器语音音频”，在输入法中选择同一回环设备作为麦克风。音频仅在内存处理，应用不安装驱动。

“系统输入切换”默认关闭。开启后，平时不干预系统麦克风；按下语音键时记住当时输入并切到所选回环，确认切换后才触发输入法；松开并排空尾音后恢复按下前的设备。按住期间 AirPods/USB 抢占不会改写恢复目标；松开后的新系统选择会被尊重。原设备若已断开，仅回退到可用实体输入并显示提示。不修改默认输出。实现与验证边界见 [语音会话切换记录](docs/validation/2026-10-27-voice-input-session.md)。

系统不再弹输入监控提示时，“打开输入监控设置…”会打开真实设置，并显示可拖动的当前应用图标与箭头。需要用户拖入列表并开启；操作引导不会代替系统授权。未弹系统框的完整根因仍待确认。

设置保留按键映射、连接与语音、权限与隐私、关于四页，不含组合动作、统计和回眸。向导只检测按键，检测期间暂停日常动作，取消保留原配置；完成时可补齐空的导航映射，不覆盖已有动作。向导不证明音频或目标输入法成功。

## 开发

运行要求 macOS 14+；构建需要包含 Swift 6 的独立 Command Line Tools（例如 Xcode 16 对应版本或更新版本）。不需要完整 Xcode、外部 Swift 包或本地签名证书。默认构建当前架构；Intel 和最低系统仍需单独验收。

```sh
xcode-select --install       # 已有 CLT 时跳过
make test
make build                  # dist/Remote2Prompt.app
make run
make check
```

脚本默认 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`，不修改全局工具链选择。检查入口为 `make test`，不依赖 XCTest。当前保持不需要证书的临时签名，未做 Developer ID 签名、公证或发布。

重建前退出目标 app；脚本拒绝覆盖正在运行的应用。临时签名随二进制变化，更新后可能需要重新授权；应用检测到运行代码与磁盘不同会停止接管并提示重开。

## Homebrew 源码安装

源码仓库为 [realDGD/Remote2Prompt](https://github.com/realDGD/Remote2Prompt)，同一仓库根目录的 `Formula/`、`Casks/` 提供源码 tap。首次安装：

```sh
brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git
brew install --build-from-source realdgd/remote2prompt/remote2prompt
brew install --cask realdgd/remote2prompt/remote2prompt-app
brew test realdgd/remote2prompt/remote2prompt
open /Applications/Remote2Prompt.app
```

Homebrew 7 若提示来源未信任，按提示分别执行 `brew trust --formula realdgd/remote2prompt/remote2prompt` 和 `brew trust --cask realdgd/remote2prompt/remote2prompt-app` 后重试。

Formula 从固定 commit、SHA-256 的源码归档使用独立 CLT 编译；配套 Cask 将本机编译的应用本体安装到 `/Applications/Remote2Prompt.app`，不是手工软链接，也不下载预编译 app。`remote2prompt` 启动命令优先打开与本次编译一致的应用程序副本。更新先执行 Formula 的 `brew upgrade --build-from-source`，再执行 Cask 的 `brew upgrade --cask`。

完整卸载（加 `--zap` 清除本应用设置；去掉则保留）：

```sh
brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt-app
brew uninstall --formula realdgd/remote2prompt/remote2prompt
```

Cask 管理应用程序中的本体，Formula 管理源码产物和启动命令；卸载需两条命令。系统隐私授权和音频驱动不随设置清除。开发者仍可 `make homebrew` 生成本地 tap。构建、升级、卸载与发布操作详见 [构建与安装](docs/development.md)。

## 当前进度

| 功能 | 状态 |
| --- | --- |
| 原生四页设置、菜单栏、设置向导 | 已接入；向导真实完成需硬件验收 |
| 三列映射、录入预览/清空/确认、RC003 示意 | 已实现，原生交互检查边界见本轮记录 |
| 单击/双击/长按、重复、任意快捷键 | 已接入 HID 和执行器，真机回归待完成 |
| 独立语音触发、Fn 与左右 Control/Command/Option | 已接入成对事件及音频排空后释放，目标输入法待验收 |
| RC003 音频与虚拟设备 | 已接入协议/解码/回环输出代码；实际枚举本机 MiRemoteV 2ch，真实声音与 RC001 待验收 |
| 按住切到遥控器、松开恢复原输入 | 已接入按下快照、确认后触发、尾音排空恢复及失败清理；真实切换待验收 |
| Homebrew 源码安装与 CI | 固定源码 tap 与应用生命周期配方已接入；CI 覆盖 arm64/Intel CLT、安装和卸载，实际结果见 Actions |

## 公开维护

仓库保留分阶段提交。`make privacy-check` 检查当前受跟踪源码，`ruby scripts/check-publication.rb --history` 同时检查全部可达文件历史；构建、原始诊断、录音和签名材料由 `.gitignore` 排除。不要把真实设备标识或未经脱敏的日志贴入仓库与 issue。

[CI](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml) 运行文档、全历史脱敏、凭据扫描、工作流语法、两种架构 CLT 构建和 Homebrew 源码安装；不访问真实遥控器或验证系统权限。详见 [公开维护记录](docs/validation/2026-10-27-publication.md)。当前尚未选择开源许可证，也未发布二进制或驱动。

## 开发入口

- [产品需求与验收](docs/product.md)
- [架构](docs/architecture.md) / [路线图](docs/roadmap.md)
- [构建与安装](docs/development.md) / [验证](docs/testing.md)
- [开发约定](AGENTS.md) / [Agent Notes](.agents/notes/README.md)
- [来源与第三方组件](THIRD_PARTY_NOTICES.md)

开发方式参考 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)，产品行为参考 [remote-mic-app](https://github.com/HD838A/remote-mic-app) 及 [#435](https://github.com/HD838A/remote-mic-app/issues/435)、[#433](https://github.com/HD838A/remote-mic-app/issues/433)。参考不表示复制源码、品牌或驱动。
