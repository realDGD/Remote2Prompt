# Remote2Prompt

[![CI](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml/badge.svg)](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml)

面向 macOS 的原生遥控器语音与按键工具，以 Swift 编写，采用左栏设置，通过 Command Line Tools 构建，支持 Homebrew 从源码安装。

当前是**按键与语音链路开发预览**：已接入 HID、原生键接管与恢复、普通手势、快捷键、独立语音触发，以及 ATVV → IMA/DVI ADPCM → 16 kHz PCM → 所选回环设备的代码链路。**真实遥控器说话、目标输入法识别及完整故障回归尚未验收，代码接入不等于语音输入已验证成功。** 当前结果见 [本轮验证](docs/validation/2026-10-27-settings-and-voice.md)，历史见 [M1 记录](docs/validation/2026-10-27-m1.md)。

## 使用

先在系统蓝牙中配对遥控器，运行设置向导，或在“权限与隐私”页请求设备控制授权。不要同时运行另一款遥控器映射软件。

“按键映射”常驻左侧遥控器示意，点击按键可定位右侧设置。语音键置顶，直接设置开关与触发键；普通键按方向导航、常用按键、设备控制分组，单击、双击、长按三列同时编辑。每个动作字段统一左对齐，点击字段打开动作菜单，菜单中可清除动作；键盘图标直接录入快捷键，录入候选确认后才保存。底部显示最近输入与发送请求，不保存输入文字。

映射页的“启用语音触发”独立于普通映射。选择 Fn 或左右 Control/Command/Option，在输入法中设置同一触发键。需要遥控器声音时，开启“启用虚拟麦克风”，在出现的设备选项中选择已安装的 MiRemoteV 2ch / BlackHole 2ch，把遥控器麦克风声音送入所选设备供输入法识别；开关同时开启语音触发，并需在输入法中选择同一回环设备。该开关不安装虚拟设备。音频仅在内存处理，应用不安装驱动。

虚拟麦克风关闭时只显示开关和用途，开启后再显示设备、测试及系统输入切换；向导采用相同规则。关闭语音触发时，触发键收在“配置语音触发键”中，仍可先配置再启用。普通映射三列始终可编辑；关闭音频不会清空已有选择，也不会隐藏尚未完成的输入恢复或错误。

虚拟麦克风负责把本应用解码的遥控器声音传给输入法。BlackHole 是通用回环设备；MiRemoteV 是兼容版本，上游采用 USB transport 兼容方式让豆包等软件识别。两者选一个即可，“2ch”表示双声道，不要求同时安装或同时使用；来源见[无线麦说明](https://github.com/HD838A/remote-mic-app#许可与来源)。

菜单栏直接分组列出“系统输入”和“遥控器麦克风”的设备，用勾选标识当前选择，不再进入多层子菜单。系统输入点选后才切换，语音接管或恢复期间暂时禁用切换。“遥控器麦克风”选择遥控器声音的输出目标，不等同系统输入。修饰键使用 ⌃ Control、⌥ Option、⌘ Command，并保留左/右区别。

“系统输入切换”默认关闭。开启后，平时不干预系统麦克风；按下语音键时记住当时输入并切到所选回环，确认切换后才触发输入法；松开并排空尾音后恢复按下前的设备。按住期间 AirPods/USB 抢占不会改写恢复目标；松开后的新系统选择会被尊重。原设备若已断开，仅回退到可用实体输入并显示提示。不修改默认输出。实现与验证边界见 [语音会话切换记录](docs/validation/2026-10-27-voice-input-session.md)。

系统不再弹输入监控提示时，“打开输入监控设置…”会打开真实设置，并显示可拖动的当前应用图标与箭头。需要用户拖入列表并开启；操作引导不会代替系统授权。未弹系统框的完整根因仍待确认。

设置保留按键映射、连接与音频、权限与隐私、关于四页，不含组合动作、统计和回眸。向导分为准备、配置、检查、确认四步，支持“跳过配置”和“跳过检查”：前者不保存草稿，后者明确标记未检查并允许保存。向导期间暂停日常动作，保存时可补齐空的常用动作，不覆盖已有动作；按键检查不证明音频或目标输入法成功。

左栏底部的“导入与导出…”使用原生文件面板保存便携 JSON。导入会先显示替换摘要，确认后才替换映射和语音触发键；功能开关保持关闭，虚拟麦克风需重新选择。文件不包含系统权限、设备身份或恢复记录，最大 256 KB。

## 开发

运行要求 macOS 14+；构建需要包含 Swift 6 的独立 Command Line Tools（例如 Xcode 16 对应版本或更新版本）。不需要完整 Xcode、外部 Swift 包或本地签名证书。默认构建当前架构；Intel 和最低系统仍需单独验收。

```sh
xcode-select --install       # 已有 CLT 时跳过
make test
make build                  # dist/Remote2Prompt.app
make run
make check
```

脚本默认 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`，不修改全局工具链选择。检查入口为 `make test`，不依赖 XCTest。当前保持不需要证书的临时签名，源码与 tap 公开发布，未做 Developer ID 签名、公证或预编译应用分发。

重建前退出目标 app；脚本拒绝覆盖正在运行的应用。临时签名随二进制变化，更新后可能需要重新授权；应用检测到运行代码与磁盘不同会停止接管并提示重开。

## Homebrew 源码安装

只需一个源码型 Cask，源码与 tap 都在 [realDGD/Remote2Prompt](https://github.com/realDGD/Remote2Prompt)：

```sh
brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git
brew install --cask realdgd/remote2prompt/remote2prompt
remote2prompt --self-check
open /Applications/Remote2Prompt.app
```

安装会下载固定 commit、SHA-256 的源码归档，用 Swift 6 独立 CLT 运行核心/适配器检查并编译，不下载预编译 app，也不安装配套 Formula 或音频驱动。Cask 将 app 本体移入应用程序，清理构建缓存；Caskroom 只保留指向该 app 的受管理链接，没有第二份 app。`remote2prompt` 命令打开实际安装路径，也支持 `--version` 和 `--self-check`。

Homebrew 若提示来源未信任，执行 `brew trust --cask realdgd/remote2prompt/remote2prompt` 后重试。这里的 Cask 始终从源码编译，不使用只对 Formula 生效的 `--build-from-source` 或 `brew test`；安装时自动运行检查，安装后的完整来源/签名/单份 app 验收见[构建与安装](docs/development.md)。

更新与完整卸载（`--zap` 清本应用设置；去掉则保留设置）：

```sh
brew update
brew upgrade --cask realdgd/remote2prompt/remote2prompt
brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt
```

从旧双项版本迁移时，先退出应用并确认原生按键已恢复，再执行：

```sh
brew uninstall --cask realdgd/remote2prompt/remote2prompt-app
brew uninstall --formula realdgd/remote2prompt/remote2prompt
brew untap realdgd/remote2prompt
brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git
brew install --cask realdgd/remote2prompt/remote2prompt
```

旧 Cask 卸载可加 `--zap` 清设置；不清理系统隐私记录、蓝牙配对或驱动。所有安装验收均从公开 HTTPS tap 和远端源码开始，不使用本地 checkout 或 file URL。

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
