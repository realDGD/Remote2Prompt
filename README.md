# Remote2Prompt

面向 macOS 的原生遥控器语音与按键工具，以 Swift 编写，采用左栏设置界面，通过 Command Line Tools 构建，并支持 Homebrew 从源码安装。

当前版本是 **可编译的应用骨架**：具备菜单栏入口、原生设置窗口、按键方案编辑和本机保存，以及独立的语音会话与输入优先级策略。**尚未接入蓝牙/HID、音频解码、虚拟麦克风写入和系统按键发送，不能用于实际遥控器语音输入。**

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
| 按键单击/双击/长按方案编辑与保存 | 已实现配置；执行器待开发 |
| Fn、左右 Control/Command/Option 语音触发 | 已实现配置与成对事件策略；系统事件发送待开发 |
| 遥控器在线优先虚拟输入，断开恢复实体输入 | 已实现纯策略；CoreAudio 监听与切换待开发 |
| 小米遥控器 2 / 2 Pro 接入与音频链路 | 待开发、待真机验收 |
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
