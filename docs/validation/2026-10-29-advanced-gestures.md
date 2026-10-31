# 普通按键高级配置验证

日期：2026-10-29。本轮仅本地开发，已安装0.2.7、生产设置、系统输入与权限保持原状。没有推送、修改公开tap或重新安装。

## 语义与上游差异

比较无线麦固定源码 `b76ac7fc17fb3a77a29281d632820055494008d8` 的真实普通HID路径，而非仅看独立识别器。参考文件：[HIDRemoteMonitor](https://github.com/HD838A/remote-mic-app/blob/b76ac7fc17fb3a77a29281d632820055494008d8/Sources/RemoteMic/HIDRemoteMonitor.swift)、[RemoteButtonGestureRecognizer](https://github.com/HD838A/remote-mic-app/blob/b76ac7fc17fb3a77a29281d632820055494008d8/Sources/RemoteMic/RemoteButtonGestureRecognizer.swift)、[RemoteButtons](https://github.com/HD838A/remote-mic-app/blob/b76ac7fc17fb3a77a29281d632820055494008d8/Sources/RemoteMic/RemoteButtons.swift)。不包含其特殊短语/面板接管。

| 场景 | 无线麦该版本 | VoiRemote本轮 |
| --- | --- | --- |
| 只有单击映射 | 普通HID路径按下即执行 | 同样即时执行 |
| 双击/长按 | 300/550ms，次级手势使单击等待 | 同样默认300/550ms，可调整 |
| 第二下持续按住 | 可转为长按 | 默认保留；逐键开启双击后按住连发后锁定双击 |
| 长按与连发 | 次级手势路径不做普通单击连发 | 同样不提前连发单击；可独立开启长按动作连发 |
| 单击自动连发 | 物理键和动作共同限定；350ms后，方向/音量100ms、返回50ms | 动作判断；默认450/80ms，可逐键关闭或显式开启 |
| 自定义方向/退格 | 无修饰时可重复 | 补齐无修饰自定义方向/退格的自动重复 |
| 部分释放过滤 | 某些非连发原始路径有600ms稳定释放处理 | 未照搬；具体抖动须按本机报告验证 |

长按决定执行哪一列，连发决定该动作是否重复。配置长按时，阈值前不会先执行单击，以免产生无法撤销的副作用；开启长按连发后，阈值到达先执行一次，再按连发间隔重复。只有双击、没有长按时，明确开启单击连发可让第一次持续按住在连发等待后锁定为单击，不再补发或等待双击。

双击后按住连发是逐键选项，默认关闭。开启后第二次按下立即执行双击动作，达到连发等待后继续重复；松开不补发，不再转为长按。因此短双击的触发点也提前到第二次按下，界面明确说明。没有此选项时，双击仍在第二次松开执行。

Karabiner提供可借鉴的层次：[to_if_held_down](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-held-down/)用于按住阈值，[to_if_alone](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-alone/)在松开时发送瞬时事件且可被其他输入取消，[to.repeat](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/repeat/)控制保持按下的系统重复；[延迟动作示例](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-delayed-action/)可组合双击。它没有要求所有双击第二下按住都重复。本项目仍由Swift执行成对软件动作，未引入其驱动、JSON或代码；物理键盘其他输入不会照其to_if_alone规则取消普通遥控器单击。

## 配置与调度

schema5新增四个全局毫秒值和稀疏逐键策略。范围：双击100–1000、长按150–3000、连发等待100–3000、间隔30–1000ms。旧schema1–4缺省读取保留原时序和次级优先级，新增长按/双击连发关闭；无修饰自定义方向/退格自动连发属于本轮行为补齐。便携导入保留参数并关闭能力。

手势锁定首次按下时的映射和参数。运行时修改映射/时序/逐键策略取消待执行普通手势；语音保持独立即时生命周期。普通计时改为最早deadline的一个单次主运行循环计时器，取消/重排有代次门禁，无手势时不安排普通扫描；不据此宣称整机内存或CPU测量已改善。

## 已执行

- `make check`：98/98核心、99/99适配器检查，独立CLT Release构建、bundle验证、文档及已跟踪内容脱敏通过；使用Command Line Tools，不使用Xcode。
- 核心检查包含旧配置迁移、本地/便携往返、无效时序和重复逐键策略拒绝、自定义导航、长按/双击重复、默认第二下转长按、第一下按住锁定、来源隔离、取消、迟到不补积压、最早deadline及空闲无deadline。
- 独立预览bundle使用隔离配置并禁用硬件。原生Computer Use实际展开/收起高级配置，核对300/550/450/80ms；将双击改为400再步进到410，并恢复300；勾选确认键两种连发、切到返回键设置不连发、切回确认验证独立保留，再恢复确认键默认。选中语音键时普通策略隐藏并说明不适用。
- 目视检查当前窗口中遥控器、三列编辑和下方高级区共同可见，映射区可独立滚动。未要求用户观察或操作；验证后退出独立预览。

## 未覆盖

未执行真实RC003按键、合成系统按键或目标软件实际动作；新单次计时器的真实HID调度、精确边界与抖动、按住断连/休眠和不同固件仍待验收。原生预览不等于这些硬件路径通过。没有验收最小窗口、Intel/macOS14、多屏或完整键盘导航。无新增发布或安装结果。
