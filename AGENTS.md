# Remote2Prompt 开发约定

Remote2Prompt 是 macOS 原生遥控器语音与按键工具。先读 [README](README.md)、[产品需求](docs/product.md) 和 [架构](docs/architecture.md)；当前实施范围见 [路线图](docs/roadmap.md)。

## 工作方式

- 按用户的全局约定判断任务规模。普通任务直接推进；只有明确的大工程才按需采用 Superpowers。不要自动启动整套流程、强制 TDD、子 agent 或审批。
- 延续用户已确定的需求和授权。对可逆的实施选择自行判断；只询问真正影响需求、权限或风险的缺失信息。
- 按有意义、可验证的阶段多次 commit，不把全部工作攒成一次提交；提交授权不等于推送或发布授权。
- 借鉴 DeepSeek Harness 的渐进阅读、Agent Notes 和相关检查，不引入其 Cordis/TypeScript、全覆盖率或双语同步要求。
- 当前能力以代码和已执行的验证为准；规划、纯策略测试、UI 启动、真实遥控器验收必须区分。

## 工程约束

- 仅面向 macOS 14+，Swift 6 / SwiftPM，原生 SwiftUI + AppKit 左栏设置；不加入 iOS、Electron 或 Web 设置界面。
- 构建和自动检查必须能用独立 Command Line Tools 完成。默认 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`，不运行 `xcodebuild`，不修改全局 `xcode-select`。
- `Sources/Remote2PromptCore/` 保持独立于 SwiftUI、蓝牙、CoreAudio 和系统事件发送；系统适配器拥有资源和清理，UI 只消费状态和设置。
- 音频输入优先开关和按键映射默认关闭。语音键即时开始/结束，独立于普通键的单击、双击和长按判定。
- 退出、断连、权限失效或会话取消必须释放已发送的合成按键。左右 Control 分别为独立选项，不能退化成组合键。
- 音频设备按 UID 保存，瞬时 AudioDeviceID 只存在于适配器。默认不修改系统输入或输出；优先策略只允许在用户开启后接管输入。
- 不记录语音内容、完整 HID 数据、蓝牙地址、外设 UUID 或输入文字；硬件日志使用脱敏固定样例。
- 不复用参考项目的代码、品牌或驱动二进制而遗漏授权。接入外部源码前更新 [来源说明](THIRD_PARTY_NOTICES.md)。

## Agent Notes 与文档

- 仅为持久决策写 Note：问题、决定、替代方案、代价。格式与状态迁移见 [.agents/notes/README.md](.agents/notes/README.md)。机械修改和小范围界面调整无需 Note。
- 未来或部分实现放 `proposed/`，真正接入后才移到 `implemented/`，同时改写为当前事实。测试过策略不等于功能已完成。
- 当前规则写在所属文档；Note 保存理由；实施清单写在 `.agents/plans/`。不建立重复的集中 Note 索引。
- 文档以中文为主，代码标识符和 Note 格式标记使用英文；无需自动翻译。
- 仓库技能：维护 Note 时读 [r2p-agent-note](.agents/skills/r2p-agent-note/SKILL.md)，完成改动时读 [r2p-check](.agents/skills/r2p-check/SKILL.md)。小改动不额外启动正式规划。
- `CLAUDE.md` 是本文件的软链接，只修改 `AGENTS.md`。

## 验证与交付

```sh
make test         # 不依赖 XCTest 的核心与 macOS 适配器模拟检查
make build        # CLT Release 应用包
make check        # 核心检查、构建、bundle 检查、文档检查
make docs-check   # 仅文档和仓库约定改动
make homebrew     # 生成本地源码归档及 tap；不自动安装或发布
```

只运行与改动相称的检查；相同代码通过后不为提交重复全量执行。具体硬件验收见 [testing.md](docs/testing.md)。报告只列实际执行的结果及未覆盖项。没有远程仓库时不编造 URL，不推送、不发布、不自动改动 `/Applications` 或音频驱动。
