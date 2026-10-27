# 来源与第三方组件

当前源码是独立编写的 Swift 应用骨架，没有外部 Swift Package 依赖、随包驱动、第三方二进制或品牌图片。Apple 系统框架由系统提供，不随应用复制。

开发组织方式参考 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（MIT），本项目重新编写精简的中文开发约定，没有复制 Harness 的运行时实现或脚本。

产品功能与 issue 行为参考 [HD838A/remote-mic-app](https://github.com/HD838A/remote-mic-app)，上游声明 macOS App 和驱动为 `GPL-3.0-only`，Logo 与图标具有独立授权条件。当前不包含其实现、品牌资产或驱动；后续任何代码复用必须先评估并履行相应许可，不能把重新命名视为独立实现。

MiRemoteV/BlackHole 仅作为可选回环设备的兼容目标；本项目不分发、不替换、不删除它们，也不宣称已有真机兼容证据。

M1 的 HID usage、VID/PID、report 1 布局及语音键 F5 行为参考上游 RemoteButtons.swift 与 RemoteVoiceFunctionMapper.swift 进行协议核查；实现独立编写，未复制上游状态机、键盘执行器或恢复日志实现。按设备原生键接管使用 Apple 的公开 [TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html) API。

本项目自身的分发许可证尚未由维护者确定；当前不添加推测的 LICENSE 或在 Formula 中声明未经确认的许可证。建立公开发布前确定许可证并更新本文件及 Formula。
