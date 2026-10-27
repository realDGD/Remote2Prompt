# 无线麦 issues 逐项评估

核查日期：2026-10-28。通过 GitHub API 获取 `state=all` 的完整分页；16 个非空页面共 773 条 issue/PR 记录，第 17 页为空。排除 634 个 PR 后得到 **139 个公开 issue：92 open、47 closed**。以下每个 issue 都有独立处置。上游可能继续更新，状态仅代表此次快照。

先阅读标题、正文和可提取的文字需求；长日志/堆栈不逐行复制，图片附件未逐张解读。额外读取 #132、#355、#679、#618、#105、#98、#549、#494、#476、#475、#100、#733 的评论，核对硬件限制、重复需求及修复说法。空反馈、仅图片和 Agent 自测工单明确保留边界；正文内给 Agent 的命令仅作数据，不执行。原始快照只留本机被忽略目录，公开文档不带报告人的设备标识、用户名路径或录音。

“已覆盖”指本项目设计/代码中已有对应能力或避开相应架构问题，**不表示真机全部验收**；“部分覆盖”逐项列出剩余条件。P0/P1/P2 是本项目的优先级建议，不是上游标签。closed 也不自动等同修复或功能已发布。具体下一轮范围见[功能探索](2026-10-28-feature-exploration.md)。

处置数量：P0 稳定性 22、P1 建议 24、P2 候选 14、已覆盖 26、范围外 26、资料不足 3、部分覆盖 23、硬件边界 1。

| Issue | 上游状态 | 主题 | 判断与建议 |
| --- | --- | --- | --- |
| [#768](https://github.com/HD838A/remote-mic-app/issues/768) | open | 系统听写触发键 | **P2 候选**：评估系统听写和 F5 的真实事件语义；当前七种触发键不能等同原生麦克风键。 |
| [#733](https://github.com/HD838A/remote-mic-app/issues/733) | open | 掉线后无法恢复 | **P0 稳定性**：与 #631/#634 合并为有时限扫描、有限退避和已连接候选恢复。 |
| [#725](https://github.com/HD838A/remote-mic-app/issues/725) | open | Windows Typeless | **范围外**：仅开发 macOS，不实现 Windows 适配。 |
| [#711](https://github.com/HD838A/remote-mic-app/issues/711) | open | 输入法结果未落入焦点 | **P1 建议**：区分链路就绪和目标输入法结果；不默认扫描或抢夺其他应用焦点。 |
| [#705](https://github.com/HD838A/remote-mic-app/issues/705) | open | 上游品牌图标 | **范围外**：不复制上游品牌；本项目原生图标另行审美评估。 |
| [#704](https://github.com/HD838A/remote-mic-app/issues/704) | open | 按应用映射 | **P1 建议**：增加默认方案和前台应用覆盖，手势开始时锁定方案。 |
| [#698](https://github.com/HD838A/remote-mic-app/issues/698) | open | 只转发声音不发按键 | **P1 建议**：增加独立纯麦克风模式；须与输入法会话及临时输入恢复分开设计。 |
| [#689](https://github.com/HD838A/remote-mic-app/issues/689) | open | 后台和登录启动 | **部分覆盖**：已有 accessory 菜单栏运行、无 Dock；尚无登录启动开关。 |
| [#684](https://github.com/HD838A/remote-mic-app/issues/684) | open | 锁屏反复亮屏 | **P0 稳定性**：暂停锁屏/睡眠后的扫描和重连；不把所有系统唤醒归因应用。 |
| [#679](https://github.com/HD838A/remote-mic-app/issues/679) | open | 固件上限前提示 | **P1 建议**：可选无声且不抢焦点的接近 60 秒提示，计时以真实音频开始为准。 |
| [#678](https://github.com/HD838A/remote-mic-app/issues/678) | closed | 自身 AX 查询死锁 | **已覆盖**：未实现跨应用焦点扫描；未来增加时必须排除自身并限制查询时长。 |
| [#675](https://github.com/HD838A/remote-mic-app/issues/675) | open | 隐藏 Dock 图标 | **已覆盖**：应用采用 LSUIElement 和 accessory；不另增反向命名开关。 |
| [#658](https://github.com/HD838A/remote-mic-app/issues/658) | open | 预设空格动作 | **部分覆盖**：自定义录入可设空格；建议加入直达预设，降低查找成本。 |
| [#657](https://github.com/HD838A/remote-mic-app/issues/657) | open | 韩语与英文界面 | **P2 候选**：识别语言由外部输入法决定；界面本地化与工具兼容矩阵单独评估。 |
| [#656](https://github.com/HD838A/remote-mic-app/issues/656) | open | 图标审美 | **范围外**：上游品牌反馈不直接迁移为本项目功能。 |
| [#634](https://github.com/HD838A/remote-mic-app/issues/634) | open | 闲置断线重连 | **P0 稳定性**：唤醒后重建、扫描窗及退避需要真机；避免持续连接风暴。 |
| [#631](https://github.com/HD838A/remote-mic-app/issues/631) | open | 扫描永久停滞 | **P0 稳定性**：本项目 discover 扫描也缺少独立期限，列为优先改进而非声称已修。 |
| [#619](https://github.com/HD838A/remote-mic-app/issues/619) | open | 华为遥控器 | **P2 候选**：需要具体型号与协议证据；不得仅扩大设备名匹配。 |
| [#618](https://github.com/HD838A/remote-mic-app/issues/618) | open | 电量显示 | **P1 建议**：接入可用的标准电量服务，显示更新时间和未知状态。 |
| [#615](https://github.com/HD838A/remote-mic-app/issues/615) | open | 文字未进入输入框 | **P1 建议**：并入 #711 的工具兼容和分层诊断；不读取用户输入文字。 |
| [#614](https://github.com/HD838A/remote-mic-app/issues/614) | open | macOS 12 Intel | **范围外**：维持 macOS 14+，Intel 由 CI 验证，不降低系统版本。 |
| [#602](https://github.com/HD838A/remote-mic-app/issues/602) | open | 向导错误拒绝可用链路 | **已覆盖**：向导可跳过检查，且只称按键检查，不强制外部输入法提交文字。 |
| [#601](https://github.com/HD838A/remote-mic-app/issues/601) | open | 睡眠反复唤醒 | **P0 稳定性**：并入锁屏/休眠保护及长时间待机验证。 |
| [#596](https://github.com/HD838A/remote-mic-app/issues/596) | open | 主线程音频引擎阻塞 | **部分覆盖**：引擎已在串行后台队列；CoreAudio 目录仍同步读取，需延迟监测。 |
| [#595](https://github.com/HD838A/remote-mic-app/issues/595) | open | Windows 后台失效 | **范围外**：不实现 Windows；保留后台普通键的 macOS 回归场景。 |
| [#594](https://github.com/HD838A/remote-mic-app/issues/594) | open | Windows 静默自启 | **范围外**：平台不适用；macOS 登录启动建议另列。 |
| [#584](https://github.com/HD838A/remote-mic-app/issues/584) | open | 真正持续按住键 | **P1 建议**：当前重复触发不等同 keyDown 保持；另设计成对释放模式。 |
| [#581](https://github.com/HD838A/remote-mic-app/issues/581) | closed | 重新配对后的 Windows 故障 | **范围外**：不迁移 Windows 实现；配对归属问题用于帮助文档。 |
| [#568](https://github.com/HD838A/remote-mic-app/issues/568) | open | 睡眠后系统卡顿 | **P0 稳定性**：增加多次开合盖和长期资源计数验收，不能凭低 RSS 排除。 |
| [#549](https://github.com/HD838A/remote-mic-app/issues/549) | open | 重复修饰键序列 | **资料不足**：评论确认具体按键和目标应用仍不明确；不能当作普通组合键支持。 |
| [#544](https://github.com/HD838A/remote-mic-app/issues/544) | open | 回环路由长期失效 | **P0 稳定性**：验证选定 UID 绑定与故障恢复；分清音频写出和输入法焦点。 |
| [#528](https://github.com/HD838A/remote-mic-app/issues/528) | closed | 隐藏两类图标 | **部分覆盖**：Dock 默认隐藏，菜单栏保留可恢复入口；暂不隐藏唯一入口。 |
| [#527](https://github.com/HD838A/remote-mic-app/issues/527) | open | 语音尾部延迟 | **部分覆盖**：已有尾音及排空；真实 Bluetooth 与输入法端到端时延仍待验收。 |
| [#514](https://github.com/HD838A/remote-mic-app/issues/514) | open | 后台唤醒 | **P0 稳定性**：并入睡眠保护，不通过关闭整个系统蓝牙解决。 |
| [#513](https://github.com/HD838A/remote-mic-app/issues/513) | open | 锁屏/解锁保护 | **P0 稳定性**：统一生命周期门禁；后台唤醒不等同解锁，不自动反复请求配对。 |
| [#497](https://github.com/HD838A/remote-mic-app/issues/497) | open | 多用户争用麦克风 | **P1 建议**：非活动登录会话暂停资源接管，切回后重新验证设备。 |
| [#496](https://github.com/HD838A/remote-mic-app/issues/496) | closed | Apple TV 遥控器 | **P2 候选**：新增硬件需独立适配及许可核查，不与 RC003 混同。 |
| [#494](https://github.com/HD838A/remote-mic-app/issues/494) | closed | 冗余权限轮询 | **部分覆盖**：进程级单一 PermissionProbe 已防堆积；仍需实测查询次数与撤权延迟。 |
| [#492](https://github.com/HD838A/remote-mic-app/issues/492) | open | 首次配置术语难懂 | **P1 建议**：补充外部输入法与虚拟麦克风的短说明，允许先跳过，不强迫装指定输入法。 |
| [#486](https://github.com/HD838A/remote-mic-app/issues/486) | open | 蓝牙 HID 唤醒 | **P0 稳定性**：区分系统蓝牙与应用扫描，提供设备级暂停，不承诺阻止所有唤醒。 |
| [#485](https://github.com/HD838A/remote-mic-app/issues/485) | open | 单击产生双动作 | **部分覆盖**：已有重复报告和原生租约策略；加入真实多输入框回归。 |
| [#476](https://github.com/HD838A/remote-mic-app/issues/476) | closed | 事件 tap 泄漏 | **已覆盖**：原生设备租约不用全局事件 tap；窗口录入监控仍须对称清理。 |
| [#475](https://github.com/HD838A/remote-mic-app/issues/475) | closed | 虚拟设备静音/低音量 | **P1 建议**：先只读检查兼容回环并提示；自动修复须显式选择，绝不改实体设备音量。 |
| [#472](https://github.com/HD838A/remote-mic-app/issues/472) | open | 一键清空输入框 | **范围外**：涉及多步破坏性动作，当前不做组合动作；不替用户自动全选删除。 |
| [#463](https://github.com/HD838A/remote-mic-app/issues/463) | open | 电量陈旧 | **P1 建议**：与 #618 合并，记录采样新鲜度，断连后不显示旧值为实时电量。 |
| [#458](https://github.com/HD838A/remote-mic-app/issues/458) | open | 录音完成外部接口 | **P2 候选**：可评估无内容会话事件；当前无存档、无转写/MCP，不引入音频和选区外泄。 |
| [#456](https://github.com/HD838A/remote-mic-app/issues/456) | open | 重跑向导无法退出 | **已覆盖**：任意步骤可跳过配置退出，草稿仅确认保存，已做原生交互验证。 |
| [#454](https://github.com/HD838A/remote-mic-app/issues/454) | open | Homebrew 分发 | **已覆盖**：同仓库 Formula 源码编译及 Cask 安装本体，远端清洁安装和 brew test 已执行。 |
| [#453](https://github.com/HD838A/remote-mic-app/issues/453) | closed | MCP helper 权限 | **范围外**：不包含 MCP helper；现有 bundle 自检继续检查主程序权限。 |
| [#452](https://github.com/HD838A/remote-mic-app/issues/452) | open | 没有 Fn 的键盘 | **已覆盖**：左右 Control/Command/Option 独立可选并显示符号。 |
| [#446](https://github.com/HD838A/remote-mic-app/issues/446) | closed | 长期触控板卡顿 | **P0 稳定性**：没有对应全局抑制架构，但仍需资源与睡眠压力回归。 |
| [#444](https://github.com/HD838A/remote-mic-app/issues/444) | closed | 个人中心布局 | **范围外**：无个人中心、统计或会员页面。 |
| [#443](https://github.com/HD838A/remote-mic-app/issues/443) | open | 向导强制说话 | **已覆盖**：可跳过检查；向导不要求说话或收集测试文字。 |
| [#441](https://github.com/HD838A/remote-mic-app/issues/441) | open | 后台扫描干扰睡眠 | **P0 稳定性**：当前睡眠只停止映射，不完整停音频连接所有者；列为后续优先缺口。 |
| [#440](https://github.com/HD838A/remote-mic-app/issues/440) | open | 前台应用自动方案 | **P1 建议**：与 #704/#98 合并；默认回退和按下快照不可缺。 |
| [#439](https://github.com/HD838A/remote-mic-app/issues/439) | open | 新系统输入法落字 | **P1 建议**：建立版本兼容矩阵和只读诊断，不把模拟按键成功当文字成功。 |
| [#438](https://github.com/HD838A/remote-mic-app/issues/438) | open | 已连接设备未发现 | **P0 稳定性**：已有 retrieveConnectedPeripherals 路径，仍需闲置与唤醒验收及扫描超时。 |
| [#437](https://github.com/HD838A/remote-mic-app/issues/437) | closed | 状态图标变化 | **P1 建议**：菜单栏明确区分关闭、未连接、就绪、说话、错误；不能只靠颜色。 |
| [#435](https://github.com/HD838A/remote-mic-app/issues/435) | open | 虚拟输入优先 | **已覆盖**：按用户修订为按住时接管、排空后精确恢复；非上游持续在线优先，真机仍待验收。 |
| [#433](https://github.com/HD838A/remote-mic-app/issues/433) | open | 左右 Control 单键 | **已覆盖**：独立左右键已接入；目标输入法兼容性仍需真机。 |
| [#422](https://github.com/HD838A/remote-mic-app/issues/422) | closed | Dock 隐藏 | **已覆盖**：默认 accessory；无需每次进设置隐藏。 |
| [#421](https://github.com/HD838A/remote-mic-app/issues/421) | open | 指定应用聚焦 | **P2 候选**：明确用户触发时再评估；不做通用 AX 学习扫描。 |
| [#415](https://github.com/HD838A/remote-mic-app/issues/415) | open | 组合动作图标 | **范围外**：不提供组合动作；普通按键图标保持语义清晰。 |
| [#414](https://github.com/HD838A/remote-mic-app/issues/414) | open | 快捷键简写 | **已覆盖**：快捷键用原生修饰符顺序与符号，左右语音键同时保留文字。 |
| [#413](https://github.com/HD838A/remote-mic-app/issues/413) | closed | Dock 开关无效 | **已覆盖**：采用系统 accessory 策略，避免有开关但不生效。 |
| [#412](https://github.com/HD838A/remote-mic-app/issues/412) | closed | 原生窗口菜单 | **部分覆盖**：使用原生 Window 场景；仍需安装版键盘隐藏/最小化实际检查。 |
| [#411](https://github.com/HD838A/remote-mic-app/issues/411) | open | 遥控器高亮遮挡 | **已覆盖**：常驻绘制且选中标记局限按键；原生预览已检查。 |
| [#410](https://github.com/HD838A/remote-mic-app/issues/410) | open | 默认方案与宏不一致 | **P2 候选**：当前单一映射来源无该冲突；未来方案应统一继承和清空含义。 |
| [#407](https://github.com/HD838A/remote-mic-app/issues/407) | closed | 音量与加减混淆 | **已覆盖**：动作写“增大/减小音量”，不以键盘加减代替系统媒体动作。 |
| [#406](https://github.com/HD838A/remote-mic-app/issues/406) | closed | 自定义设备名称 | **P2 候选**：可只在本地展示设备友好名，避免写日志或导出标识。 |
| [#401](https://github.com/HD838A/remote-mic-app/issues/401) | open | 强制阻止休眠 | **已覆盖**：不创建防休眠断言；仍需验证音频与 BLE 生命周期的间接影响。 |
| [#398](https://github.com/HD838A/remote-mic-app/issues/398) | closed | 保存名称截断 | **范围外**：无宏命名编辑器；未来输入与保存校验必须一致。 |
| [#397](https://github.com/HD838A/remote-mic-app/issues/397) | open | 输入框学习失败 | **P2 候选**：不现成迁移 AX 学习；以明确应用适配和超时边界替代泛扫描。 |
| [#395](https://github.com/HD838A/remote-mic-app/issues/395) | closed | 遥控器多键组合 | **范围外**：当前不做组合动作或多键和弦；语音键独立。 |
| [#394](https://github.com/HD838A/remote-mic-app/issues/394) | open | 多方案快速切换 | **P1 建议**：先提供少量手动方案与菜单选择，再添加按应用覆盖；不以反复导入替代方案。 |
| [#393](https://github.com/HD838A/remote-mic-app/issues/393) | open | 按下/松开发单击 | **P2 候选**：可选边缘策略需保留双击/长按一致性，默认即时响应不变。 |
| [#388](https://github.com/HD838A/remote-mic-app/issues/388) | open | 防止系统休眠 | **范围外**：与轻量遥控器定位无直接关系，不加入常驻防休眠模块。 |
| [#386](https://github.com/HD838A/remote-mic-app/issues/386) | closed | 系统上一首/下一首 | **P1 建议**：加入真正媒体事件，不能用应用私有快捷键假装全局切歌。 |
| [#385](https://github.com/HD838A/remote-mic-app/issues/385) | open | Fn 被识别成 F5 | **P0 稳定性**：真机核对原生抑制及目标输入法触发事件，先诊断再改映射。 |
| [#382](https://github.com/HD838A/remote-mic-app/issues/382) | open | 连续单击延迟 | **部分覆盖**：无额外手势配置时即时执行，需真机测量而非主观延迟判断。 |
| [#377](https://github.com/HD838A/remote-mic-app/issues/377) | open | 触发键难以纠正 | **已覆盖**：语音键置顶，当前键可见可改；向导提醒工具设置相同键。 |
| [#366](https://github.com/HD838A/remote-mic-app/issues/366) | closed | CI 私有依赖 | **已覆盖**：无外部 Swift 包或私有依赖，双架构独立 CLT CI 可从公开源码构建。 |
| [#356](https://github.com/HD838A/remote-mic-app/issues/356) | open | 睡眠恢复门禁错序 | **P0 稳定性**：统一系统/屏幕/会话状态，恢复一次；不能把一次 didWake 等同全部恢复。 |
| [#355](https://github.com/HD838A/remote-mic-app/issues/355) | closed | RC003 60 秒限制 | **硬件边界**：上游真机与维护者确认固件限制；本项目未独立复验，不承诺软件突破。 |
| [#347](https://github.com/HD838A/remote-mic-app/issues/347) | open | 轻量后台与尾音 | **部分覆盖**：本身无 ASR/历史且窗口可关闭；尾音排空已接入，纯麦克风模式尚缺。 |
| [#344](https://github.com/HD838A/remote-mic-app/issues/344) | open | 开始/结束点按快捷键 | **P1 建议**：独立触发模式适配 toggle 工具，不能与按住修饰键混为一项。 |
| [#338](https://github.com/HD838A/remote-mic-app/issues/338) | open | 按来源选择麦克风 | **部分覆盖**：遥控器按住切回环、松开恢复已接入；不监听本机 Fn，不支持多遥控器混音。 |
| [#337](https://github.com/HD838A/remote-mic-app/issues/337) | closed | 低内存仍系统卡顿 | **P0 稳定性**：长稳验收同时看 WindowServer、监听数和响应；不能只优化自身内存。 |
| [#334](https://github.com/HD838A/remote-mic-app/issues/334) | open | 外接键盘冲突 | **P1 建议**：按设备限定、物理修饰键冲突与租约读回需要带蓝牙键盘复验。 |
| [#331](https://github.com/HD838A/remote-mic-app/issues/331) | closed | 空白反馈 | **资料不足**：无可执行需求，不猜测功能。 |
| [#329](https://github.com/HD838A/remote-mic-app/issues/329) | closed | 重连丢触发模式 | **已覆盖**：配置与设备连接分离保存，重连不改语音选择；加真机持久性检查。 |
| [#321](https://github.com/HD838A/remote-mic-app/issues/321) | open | TV 绑定丢失 | **部分覆盖**：TV 在同一映射 schema 中无特殊宏层，仍需真实 TV 报告验收。 |
| [#313](https://github.com/HD838A/remote-mic-app/issues/313) | closed | 应用映射规则 | **P1 建议**：并入统一方案与前台应用覆盖，不增加第二套配置入口。 |
| [#308](https://github.com/HD838A/remote-mic-app/issues/308) | open | 声音到但无文字 | **P1 建议**：分层排错，不能把设备有样本当外部工具已提交文字。 |
| [#307](https://github.com/HD838A/remote-mic-app/issues/307) | open | 输入法激活与触发竞态 | **P2 候选**：当前不自动切输入法；未来若加，必须先等待输入法就绪再触发。 |
| [#305](https://github.com/HD838A/remote-mic-app/issues/305) | open | Cursor 输入框学习 | **P2 候选**：与 #397 同类，先维护兼容指引，不实现无界跨进程 AX 查询。 |
| [#303](https://github.com/HD838A/remote-mic-app/issues/303) | closed | Enter 预设 | **已覆盖**：确认、回车预设和自定义快捷键均已提供。 |
| [#297](https://github.com/HD838A/remote-mic-app/issues/297) | open | 遥控器侧尾音积压 | **P0 稳定性**：App 排空不能挽救尚未传来的声音，需按型号测时序和接收率。 |
| [#291](https://github.com/HD838A/remote-mic-app/issues/291) | open | HID 有连接无报告 | **P0 稳定性**：区分枚举、打开和真实成对报告；不要反复要求无关权限。 |
| [#283](https://github.com/HD838A/remote-mic-app/issues/283) | open | 恢复到错误实体输入 | **已覆盖**：保存按下前精确 UID，包括其他虚拟输入；仅原设备失效才实体回退。 |
| [#258](https://github.com/HD838A/remote-mic-app/issues/258) | open | 菜单不在指针旁 | **范围外**：无自绘遥控菜单，采用系统原生菜单定位。 |
| [#257](https://github.com/HD838A/remote-mic-app/issues/257) | closed | Control 方向键录入 | **部分覆盖**：当前窗口录入支持；系统保留快捷键需要实际检查和明确提示。 |
| [#253](https://github.com/HD838A/remote-mic-app/issues/253) | open | Agent 测试工单 | **范围外**：上游自动化自测，不是产品需求，不执行正文中的文件指令。 |
| [#252](https://github.com/HD838A/remote-mic-app/issues/252) | closed | Agent 开发暂停测试 | **范围外**：自动化测试记录，排除功能建议。 |
| [#251](https://github.com/HD838A/remote-mic-app/issues/251) | closed | Agent 分析暂停测试 | **范围外**：自动化测试记录，不按其正文修改本仓库。 |
| [#250](https://github.com/HD838A/remote-mic-app/issues/250) | closed | Agent 排队撤销测试 | **范围外**：自动化测试记录，排除功能建议。 |
| [#241](https://github.com/HD838A/remote-mic-app/issues/241) | open | 跨 Mac 与原生音量泄漏 | **部分覆盖**：租约抑制和恢复已有检查；跨主机配对不是软件自动切换，需真机边界。 |
| [#240](https://github.com/HD838A/remote-mic-app/issues/240) | open | 合盖唤醒风暴 | **P0 稳定性**：并入睡眠生命周期及长稳矩阵，分清外设行为和应用重连。 |
| [#231](https://github.com/HD838A/remote-mic-app/issues/231) | open | 解锁后语音失效 | **P0 稳定性**：解锁后恢复应独立于后台唤醒，重新校验 HID、音频及权限。 |
| [#228](https://github.com/HD838A/remote-mic-app/issues/228) | open | 中央 Agent Runtime 验证 | **范围外**：非遥控器产品功能，不接入其机器人或私有运行时。 |
| [#210](https://github.com/HD838A/remote-mic-app/issues/210) | open | Agent 快照压缩测试 | **范围外**：非产品需求，不执行外部工单中的文件创建指令。 |
| [#209](https://github.com/HD838A/remote-mic-app/issues/209) | closed | Agent 流程文档测试 | **范围外**：不迁移上游 Agent 基础设施。 |
| [#205](https://github.com/HD838A/remote-mic-app/issues/205) | open | 后台与快速响应 | **部分覆盖**：Dock 隐藏和普通单击即时策略已有，连续真机操作待验收。 |
| [#196](https://github.com/HD838A/remote-mic-app/issues/196) | open | 系统输入不对导致 F5 | **部分覆盖**：提供当前输入菜单和按住切换；F5 还需查原生抑制，不能仅归因输入源。 |
| [#195](https://github.com/HD838A/remote-mic-app/issues/195) | open | 合盖语音无文字 | **P0 稳定性**：作为外接显示器/合盖的真实 HID、音频和输入法联合验收。 |
| [#190](https://github.com/HD838A/remote-mic-app/issues/190) | closed | Fn 方向键显示错误 | **部分覆盖**：使用录入事件与修饰符标准显示；特殊硬件需排除系统附带标记。 |
| [#171](https://github.com/HD838A/remote-mic-app/issues/171) | closed | TV 泄漏符号 | **部分覆盖**：已接原生 usage 抑制与读回，不能以 UI 设置成功代替真机无泄漏。 |
| [#169](https://github.com/HD838A/remote-mic-app/issues/169) | open | 旧 macOS 支持 | **范围外**：维持 macOS 14+，不扩展至 10.15。 |
| [#167](https://github.com/HD838A/remote-mic-app/issues/167) | open | 外接显示器无语音 | **P0 稳定性**：与 #195 联合验收，区分未开始、无音频和无文字。 |
| [#149](https://github.com/HD838A/remote-mic-app/issues/149) | open | 浏览器前进后退 | **部分覆盖**：可自定义浏览器快捷键；P2 可加直达预设，不模拟触控板滑动。 |
| [#140](https://github.com/HD838A/remote-mic-app/issues/140) | open | 自定义语音触发 | **P2 候选**：当前只支持七种按住触发键，F 键及点按模式另行建模。 |
| [#139](https://github.com/HD838A/remote-mic-app/issues/139) | open | 特定应用吞 Fn tap | **P2 候选**：当前没有 tap 模式；未来按应用做真实兼容验收，不承诺通用注入。 |
| [#137](https://github.com/HD838A/remote-mic-app/issues/137) | closed | 遥控器影响物理方向键 | **已覆盖**：按源租约避免全局同键码抑制；失败时释放，仍需物理键盘回归。 |
| [#132](https://github.com/HD838A/remote-mic-app/issues/132) | closed | 松手后持续收音 | **范围外**：上游维护者确认缺少可靠硬件语义；不假装纯 UI 开关能支持。 |
| [#119](https://github.com/HD838A/remote-mic-app/issues/119) | closed | 隐藏 Dock | **已覆盖**：默认 accessory，无需额外配置。 |
| [#118](https://github.com/HD838A/remote-mic-app/issues/118) | open | 长按变连发与键盘失效 | **部分覆盖**：重复与真正保持分开；当前方向键重复，任意按住动作仍缺。 |
| [#117](https://github.com/HD838A/remote-mic-app/issues/117) | closed | 物理方向键失效 | **已覆盖**：不使用跨设备同键码全局过滤，取消释放已有检查。 |
| [#106](https://github.com/HD838A/remote-mic-app/issues/106) | closed | 退格失效 | **部分覆盖**：已有 backspace 动作与连发策略，真实应用中需验收。 |
| [#105](https://github.com/HD838A/remote-mic-app/issues/105) | closed | HID 被其他工具独占 | **P1 建议**：识别 exclusive access 并提示 Karabiner 设备级设置，而非重复申请权限。 |
| [#103](https://github.com/HD838A/remote-mic-app/issues/103) | open | 泛性能建议 | **资料不足**：没有可复现细节；以可测缓存和资源压力检查为准。 |
| [#102](https://github.com/HD838A/remote-mic-app/issues/102) | open | 反馈附诊断信息 | **P1 建议**：用户主动导出脱敏摘要，仅含版本/平台/阶段，不附原始日志或标识。 |
| [#101](https://github.com/HD838A/remote-mic-app/issues/101) | closed | 卸载误删驱动漏 app | **已覆盖**：Cask 管理 app、Formula 管理源码产物；清理只针对本应用，不删驱动。 |
| [#100](https://github.com/HD838A/remote-mic-app/issues/100) | closed | 更新后权限与旧 app | **部分覆盖**：检测运行代码身份、固定安装路径并提示重开；无证书构建不能保证授权继承。 |
| [#99](https://github.com/HD838A/remote-mic-app/issues/99) | closed | iOS 发现失败 | **范围外**：不开发 iOS、Nearby 或手机客户端。 |
| [#98](https://github.com/HD838A/remote-mic-app/issues/98) | closed | 前台应用覆盖 | **P1 建议**：评论称上游已实现；本项目尚无，仍应按全局回退和手势快照独立实现。 |
| [#95](https://github.com/HD838A/remote-mic-app/issues/95) | closed | Karabiner 占用 | **P1 建议**：与 #105 合并为明确设备占用提示，不读取第三方私有配置。 |
| [#83](https://github.com/HD838A/remote-mic-app/issues/83) | closed | 应用与驱动分离安装 | **已覆盖**：源码 app 不捆绑驱动，已有兼容驱动可选；安装和卸载各自独立。 |
| [#58](https://github.com/HD838A/remote-mic-app/issues/58) | closed | 工单提交测试 | **范围外**：测试记录，无产品功能。 |
| [#52](https://github.com/HD838A/remote-mic-app/issues/52) | closed | 独立 Option 录入 | **部分覆盖**：语音支持左右 Option；普通动作的单修饰键保持模式尚需单独设计。 |
