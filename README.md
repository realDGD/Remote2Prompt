# Remote2Prompt

面向 macOS 的原生遥控器语音与按键工具，以 Swift 编写，采用左栏设置，通过 Command Line Tools 构建，支持 Homebrew 从源码安装。

当前是**按键与语音链路开发预览**：已接入 HID、原生键接管与恢复、普通手势、快捷键、独立语音触发，以及 ATVV → IMA/DVI ADPCM → 16 kHz PCM → 所选回环设备的代码链路。**真实遥控器说话、目标输入法识别及完整故障回归尚未验收，代码接入不等于语音输入已验证成功。** 当前结果见 [本轮验证](docs/validation/2026-10-27-settings-and-voice.md)，历史见 [M1 记录](docs/validation/2026-10-27-m1.md)。

## 使用

先在系统蓝牙中配对遥控器，运行设置向导，或在“权限与隐私”页请求设备控制授权。不要同时运行另一款遥控器映射软件。

“按键映射”以普通键为行，单击、双击、长按三列同时显示。快捷键录入先显示候选，确认才保存，清空与取消独立。底部监控显示最近输入与发送请求，不保存输入文字。

“连接与语音”的“启用语音触发”独立于普通映射。选择 Fn 或左右 Control/Command/Option，在输入法中设置同一触发键。需要遥控器声音时，选择已安装的 MiRemoteV 2ch / BlackHole 2ch，再开启“接收遥控器语音音频”，在输入法中选择同一回环设备作为麦克风。应用不安装驱动、不切换系统默认输入或输出，音频仅在内存处理。

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

尚无远程仓库或公开 Release，先提供可复现的本地 tap：

```sh
make homebrew
brew tap --custom-remote remote2prompt/local "$PWD/dist/homebrew/tap"
brew install --build-from-source remote2prompt/local/remote2prompt
brew test remote2prompt/local/remote2prompt
remote2prompt
```

生成器输出源码归档、SHA-256 和本地 Formula。应用位于 `$(brew --prefix remote2prompt)/libexec/Remote2Prompt.app`；启动命令支持 `--version` 和 `--self-check`。安装检查与交互授权验证分开进行，避免相同 Bundle ID 的多个副本影响系统选择。

如需应用程序入口，可自行建立链接（仅在目标不存在时）：

```sh
ln -s "$(brew --prefix remote2prompt)/libexec/Remote2Prompt.app" /Applications/Remote2Prompt.app
```

详细重建、卸载与公开 tap 准备见 [构建与安装](docs/development.md)。

## 当前进度

| 功能 | 状态 |
| --- | --- |
| 原生四页设置、菜单栏、设置向导 | 已接入；向导真实完成需硬件验收 |
| 三列映射、录入预览/清空/确认、RC003 示意 | 已实现，原生交互检查边界见本轮记录 |
| 单击/双击/长按、重复、任意快捷键 | 已接入 HID 和执行器，真机回归待完成 |
| 独立语音触发、Fn 与左右 Control/Command/Option | 已接入成对事件及音频排空后释放，目标输入法待验收 |
| RC003 音频与虚拟设备 | 已接入协议/解码/回环输出代码；实际枚举本机 MiRemoteV 2ch，真实声音与 RC001 待验收 |
| 在线优先虚拟输入、断开恢复实体输入 | 纯策略已实现，CoreAudio 默认输入协调待开发 |
| Homebrew 源码安装 | 之前本地源码安装及 brew test 通过；本轮生成归档，公开 tap 待建立 |

## 开发入口

- [产品需求与验收](docs/product.md)
- [架构](docs/architecture.md) / [路线图](docs/roadmap.md)
- [构建与安装](docs/development.md) / [验证](docs/testing.md)
- [开发约定](AGENTS.md) / [Agent Notes](.agents/notes/README.md)
- [来源与第三方组件](THIRD_PARTY_NOTICES.md)

开发方式参考 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)，产品行为参考 [remote-mic-app](https://github.com/HD838A/remote-mic-app) 及 [#435](https://github.com/HD838A/remote-mic-app/issues/435)、[#433](https://github.com/HD838A/remote-mic-app/issues/433)。参考不表示复制源码、品牌或驱动。
