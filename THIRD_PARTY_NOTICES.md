# 来源与第三方组件

当前源码是独立编写的 Swift 应用骨架，没有外部 Swift Package 依赖、随包驱动、第三方二进制或品牌图片。Apple 系统框架由系统提供，不随应用复制。

开发组织方式参考 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（MIT），本项目重新编写精简的中文开发约定，没有复制 Harness 的运行时实现或脚本。

产品功能与 issue 行为参考 [HD838A/remote-mic-app](https://github.com/HD838A/remote-mic-app)，上游声明 macOS App 和驱动为 `GPL-3.0-only`，Logo 与图标具有独立授权条件。当前不包含其实现、品牌资产或驱动；后续任何代码复用必须先评估并履行相应许可，不能把重新命名视为独立实现。

MiRemoteV/BlackHole 仅作为可选回环设备的兼容目标；本项目不分发、不替换、不删除它们，也不宣称已有真机兼容证据。

M1 的 HID usage、VID/PID、report 1 布局及语音键 F5 行为参考上游 RemoteButtons.swift 与 RemoteVoiceFunctionMapper.swift 进行协议核查；实现独立编写，未复制上游状态机、键盘执行器或恢复日志实现。按设备原生键接管使用 Apple 的公开 [TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html) API。

设置布局与向导的真实事件门槛参考上游 SettingsView.swift 及 first-run-onboarding/PRODUCT_SPEC.md 的产品行为，采用本项目四页与 M1 按键检测范围。遥控器示意图、向导、临时检测状态机及界面代码独立编写，仅使用系统 SF Symbols，没有复制上游图像、实现或完整语音向导。

2026-10-28 的设置分栏核对参考 [CodexBar PreferencesView](https://github.com/steipete/CodexBar/blob/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBar/Settings/PreferencesView.swift) 与同目录 SettingsSidebarSizing 的原生 NavigationSplitView / Form 组合。没有复制其窗口桥接、历史导航实现、图标或其他资产。

2026-10-28 的向导调整参考上游 `feature/first-run-onboarding/README.md` 的准备、设置与现场检查顺序。上游不允许跳过；本项目依用户要求独立实现可跳过的四步原生流程，不复制其视图、截图或实现。

本轮语音适配独立实现 ATVV 的公开协议事实：AB5E 服务/特征 UUID、能力包、麦克风开关命令、RC003 高半字节优先的 IMA/DVI ADPCM、同步 predictor/index 和 16 kHz PCM。协议事实经上游 TECHNICAL.md、ATVVProtocol.swift 与 XiaomiBluetoothBridge.swift 核对；未复制上游蓝牙状态机、解码器实现或音频执行器。IMA/DVI 的标准步长与索引表是编码格式数据。MiRemoteV2ch_UID / BlackHole2ch_UID 仅用于识别已安装的回环设备，仍不分发或安装驱动。

本项目自身的分发许可证尚未由维护者确定；当前不添加推测的 LICENSE 或在 Formula 中声明未经确认的许可证。建立公开发布前确定许可证并更新本文件及 Formula。
