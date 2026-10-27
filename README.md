# Remote2Prompt

面向 macOS 的原生遥控器语音与按键工具，以 Swift 编写，采用左栏设置界面，通过 Command Line Tools 构建，并支持 Homebrew 从源码安装。

当前版本是 **按键映射开发预览**：已接入小米遥控器 HID、设备原生键抑制与恢复、普通按键手势、任意快捷键和语音触发键发送。RC003 的系统枚举已确认，完整真机验收状态见 [M1 记录](docs/validation/2026-10-27-m1.md)。**遥控器音频、解码和回环设备写入尚未接入，不能用于实际遥控器语音输入。**

使用前在系统蓝牙中配对遥控器，在“权限”页请求设备控制授权，再在“按键映射”页配置并启用。可点击“补齐基本导航映射”填入空的方向、确认、返回、音量与电源单击动作；语音键独立即时发送所选 Fn 或左右修饰键。首次测试建议将语音触发键选为目标应用已配置的键。不要同时运行另一款遥控器映射软件。

## 开发

运行要求为 macOS 14+；构建需要包含 Swift 6 的 Command Line Tools（例如 Xcode 16 对应版本或更新版本）。不需要完整 Xcode 或外部 Swift 包。默认构建当前机器架构；Intel 和最低系统版本仍需单独验收。

```sh
xcode-select --install       # 已有 Command Line Tools 时跳过
make test
make build                  # dist/Remote2Prompt.app
make run                    # 构建并打开原生设置窗口
make check                  # 提交前完整的本项目检查
```

脚本默认使用 `/Library/Developer/CommandLineTools`，不修改系统工具链选择。如需指定另一套工具链，可给命令传入 `DEVELOPER_DIR`。当前测试入口为 `make test`，而非依赖 XCTest 的 `swift test`。

重建前先退出从 `dist/Remote2Prompt.app` 运行的应用。脚本拒绝覆盖正在运行的 app，以避免临时签名与权限状态不一致；应用若检测到自身已被更新，也会停止接管并提示重开。开发构建更换后可能需要重新授权。

## Homebrew 源码安装

项目还没有远程仓库或公开 Release，因此先提供可复现的**本地 tap**。无需填入虚构的 GitHub 地址：

```sh
make homebrew
brew tap --custom-remote remote2prompt/local "$PWD/dist/homebrew/tap"
brew install --build-from-source remote2prompt/local/remote2prompt
brew test remote2prompt/local/remote2prompt
remote2prompt
```

生成器会输出源码归档、SHA-256 和本地 Formula；Homebrew 用 CLT 编译，应用安装在 `$(brew --prefix remote2prompt)/libexec/Remote2Prompt.app`。`remote2prompt` 打开该应用，带 `--version` 或 `--self-check` 则运行无界面检查。

如需在“应用程序”中显示，可自行建立链接：

```sh
ln -s "$(brew --prefix remote2prompt)/libexec/Remote2Prompt.app" /Applications/Remote2Prompt.app
```

详细的重建、卸载及公开 tap 准备见 [构建与安装](docs/development.md)。当前包只有本地临时签名，未进行 Developer ID 签名、公证或发布。

## 产品目标与当前进度

| 功能 | 当前状态 |
| --- | --- |
| 原生左栏设置、菜单栏入口 | 已实现 |
| 按键单击/双击/长按、重复与任意快捷键 | 已接入 HID 与执行器；RC003 真机验收进行中 |
| Fn、左右 Control/Command/Option 语音触发 | 已实现 HID 即时成对发送；音频及目标输入法验收待 M2 |
| 遥控器在线优先虚拟输入，断开恢复实体输入 | 已实现纯策略；CoreAudio 监听与切换待开发 |
| 小米遥控器 2 / 2 Pro 音频链路 | 待 M2 开发；RC001 兼容性另行验收 |
| Homebrew 从源码编译安装 | 本地源码编译、安装及 brew test 已验证；公开 tap 待建立 |

## 开发入口

- [产品需求与验收](docs/product.md)
- [架构与模块职责](docs/architecture.md)
- [分阶段路线图](docs/roadmap.md)
- [构建与安装](docs/development.md)
- [验证与真机验收](docs/testing.md)
- [开发约定](AGENTS.md) / [Agent Notes 规则](.agents/notes/README.md)
- [来源与第三方组件](THIRD_PARTY_NOTICES.md)

开发方式参考 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)，产品行为参考 [remote-mic-app](https://github.com/HD838A/remote-mic-app) 及其 [#435](https://github.com/HD838A/remote-mic-app/issues/435)、[#433](https://github.com/HD838A/remote-mic-app/issues/433)。参考不表示复制其源码、品牌或驱动。
