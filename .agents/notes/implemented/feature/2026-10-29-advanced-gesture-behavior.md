# Agent Note: Advanced gesture behavior and repeat

Status: implemented

## Problem

旧识别器把“长按动作”和“动作连续执行”合并为互斥分支；双击第二下按住只能转成长按。用户要求区分手势与重复，并在遥控器与三列编辑区下方提供高级配置。schema5配置、识别器、Mac取消门禁和原生界面已接入。

## Decision

全局时序保留已有默认：双击300ms、长按550ms、单击/双击开始连发等待450ms、重复间隔80ms。界面使用有界毫秒数；非法值和重复逐键配置拒绝加载，不静默覆盖。schema1–4迁移保留旧时序与次级手势优先级，不开启长按/双击连发；无修饰自定义方向与退格现在和内置动作一样自动连发。便携导入保留参数但仍关闭能力。

每个普通按键有独立配置：单击重复为自动/关闭/开启；长按重复默认关闭；双击后按住重复默认关闭。自动只处理内置导航/退格/音量及无修饰的自定义方向/退格，不自动重复提交、撤销等快捷键；显式开启才允许其他动作重复。

- 已配置长按：不提前发送或重复单击；达到阈值执行长按，若开启长按重复则随后按间隔重复该长按动作。
- 只配置双击而无长按：默认保留原行为。明确开启单击重复后，第一下持续按到连发等待时间可锁定为单击连续执行，松开不再补单击。
- 开启双击后按住重复：第二下按下即执行双击动作，随后按等待/间隔重复；该段不再切为长按，松开不补双击。短双击因而提前到第二下按下执行，界面明确说明。
- 未开启双击后按住重复：沿用第二下可转长按的行为。
- 语音键保持独立即时生命周期，不使用上述普通键参数。

动作和参数在手势开始时锁定；修改映射、时序或重复策略撤销待执行普通手势。断连、关闭、向导、语音开始、睡眠和退出清理，旧任务不得补发。迟到刷新最多执行一次，不补发积压动作。

高级配置是整块映射区下方的默认折叠区，左侧全局时序，右侧跟随遥控器选中的普通按键。保留三列编辑和常驻图；提供分别恢复默认，不创建新设置页或JSON编辑器。

普通手势暴露最早deadline，Mac所有者只安排一个主运行循环单次计时器；无待判定/连发时不安排普通手势唤醒。改期和取消递增代次，旧回调不复活。该选择同时支持自定义时序和减少空闲扫描，不作为已测量的整体性能改善。

## Alternatives considered

- 无线麦普通HID路径的300/550ms判定、次级手势抑制单击可沿用；其固定物理键连发范围、600ms稳定释放和特殊面板接管不直接套用。
- 所有双击第二下自动连发会改变已有“第二下转长按”，例如确认键的⌘Return与⇧Return含义不同，因此只做逐键显式选项。
- 单击先重复、稍后再切长按，会让长按动作之前产生不可撤销的单击副作用，不采用。
- Karabiner的to_if_held_down、to_if_alone和to.repeat说明手势判定和重复是不同层。其to_if_alone在松开才发瞬时事件，且会被其他输入取消，不直接等同遥控器单击。这里只借鉴语义，不复制代码、引入驱动或JSON依赖；当前软件连发仍发送成对动作，区别于其保持keyDown的系统重复。

参考：[Karabiner按住](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-held-down/)、[单独短按](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-alone/)、[重复](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/repeat/)、[双击示例](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-delayed-action/)。

## Consequences

数值是判定阈值，系统调度会带来延迟。显式重复会反复执行用户选择的动作，界面应直说该效果；不修改物理键盘全局重复设置。新策略只能证明合成时序，RC003按键抖动和目标软件实际响应仍需真机。

当前纯策略与模拟检查98核心/99适配器、CLT构建和bundle检查通过。原生隔离预览完成折叠、条件控件、毫秒编辑与步进、逐键隔离和恢复默认检查。没有执行真实HID手势、系统输入或改动已安装应用；详情见[验证记录](../../../../docs/validation/2026-10-29-advanced-gestures.md)。
