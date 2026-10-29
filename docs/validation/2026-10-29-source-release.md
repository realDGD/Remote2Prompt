# 0.2.8至0.2.10源码发布、首次向导及清洁安装

日期：2026-10-29。用户明确授权提交、公开推送、同仓库tap、清洁源码安装及清除现有设置。本轮复用现有唯一public仓库 `realDGD/Remote2Prompt`，不新建第二个仓库、Formula或伴随Cask。

## 发布范围

0.2.8包含原创简约RC003应用图标、指定的菜单栏SF符号、默认关闭的临近语音时限浮条、设置窗口创建前建立运行时订阅，以及schema5高级普通手势配置。普通手势与提醒的策略、原生预览和未覆盖范围分别见[手势记录](2026-10-29-advanced-gestures.md)、[提醒记录](2026-10-29-voice-limit-indicator.md)。提议中的纯麦克风模式等候选不在本次发布内。

本次发布保持SwiftPM与独立Command Line Tools、默认临时签名、单源码Cask和Applications唯一app本体。不创建证书、安装音频驱动、重置TCC或更改其他应用。`.gitignore`已覆盖构建、原始日志、录音、签名材料与配置导出；复核后沿用该边界。

## 发布前检查

现有仓库可见性为PUBLIC，默认分支main；本轮15个功能、修复与检查提交的作者均为已核对的GitHub noreply邮箱。全历史公开边界扫描通过；官方Gitleaks8.30.1临时工具经官方摘要校验后扫描87个可达提交，未发现凭据。工具与原始结果留在被忽略目录。忽略规则对生产配置导出、环境、签名材料、本地检查点及两种开发app路径均已实际核对。

固定来源、旧版本退出恢复、实际HTTPS清洁安装和安装后检查的已执行结果记录如下。`brew test`是Formula命令；本轮记录实际返回，并以安装期核心/适配器检查与 `verify-homebrew-install.sh` 验证单Cask，不能伪报该命令成功。

## 固定源码

源码 `0e8477931bfe86c1d89ebdf343967a62d4f751e4` 已推送main。生成器实际下载该提交的GitHub HTTPS源码归档，SHA-256为 `0678327e6c71c0524fac50875979bf598f43b38e1ec88dd1b30810e4eb8a8639`，根目录唯一Cask固定0.2.8及该完整来源。Cask语法验证通过。

本机发布版本CLT Release构建、bundle最低macOS14/实际SDK27元数据、0.2.8版本和配置自检通过。此前相同功能源码的98核心/99适配器检查已通过；安装过程从远端归档再次运行检查，没有把本地构建用于安装。

## 0.2.8实际安装与发现

旧版本经原生退出，HID恢复记录的originals为空后执行 `brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt`。实际移除应用、CLI、Caskroom、偏好和Application Support；安装前另行确认生产偏好域不存在。两份本地开发app移到可恢复废纸篓，未清空废纸篓或改动系统隐私记录。

untap后执行README中的HTTPS tap及单Cask安装命令。新克隆tap HEAD为 `85abf5730d2fd8923df3771e6d427810878730d1`，origin为唯一公开仓库；Cask固定上一节源码。下载归档内98/98核心、99/99适配器检查与独立CLT编译通过，唯一app本体移入 `/Applications/Remote2Prompt.app`。

安装后来源/版本/摘要标记、严格签名、自检、CLI、无旧包、无第二份Caskroom app及构建缓存清理均通过。`brew test realdgd/remote2prompt/remote2prompt`实际退出1，提示没有该Formula；不是Cask测试成功，也不是源码编译失败。安装期检查与 `verify-homebrew-install.sh` 才是本次Cask验收。

原生安装版确认0.2.8、三项能力关闭、映射全空和高级配置收起。但首次仅显示按键设置，缺少自动向导。用户指出后，核对出根因为只有手动入口；因此追加0.2.9修复，不把0.2.8首次体验判为通过。

## 0.2.9首次向导修复

无本地配置与展示标记时，设置层级就绪后自动显示准备页。展示即写本机标记，跳过后不反复弹出，手动入口保留；已有配置、已导入或读取失败不弹。标记不进入配置导出，不代表硬件通过，不自动申请权限。

实际ConfigurationStore的首次、跳过、重建、手动重跑、升级、损坏保护和先导入等7项断言已纳入应用CLI自检，独立CLT构建、bundle和自检通过。独立硬件关闭预览实际自动出现向导，跳过后回到默认关闭设置；手动重跑、跳过检查、明确标记未检查及保存回设置通过。安装版首次体验结果见下节。

0.2.9源码 `d2432dbcaf0e2902f04200fe74bea489cb255a33` 已推送main；临时HTTPS传输错误后，通过本机已有且严格核验host key的SSH连接完成推送，未改origin、系统代理或TLS校验。安装来源仍为公开HTTPS归档。该归档实际下载计算SHA-256为 `ea55739c96111a8e18bfd146a7023333ba1072a4d6c110e6486598d115aac9c0`，唯一Cask固定该来源，语法检查通过。

## 0.2.9最终安装与首次体验

正常退出0.2.8后再次单Cask卸载zap，确认生产偏好域不存在。重新untap并从README的公开HTTPS地址克隆，tap HEAD为 `da561425c9ca2a716f78e7bdf266e811dc07cc62`，远端地址和Cask版本/固定来源/摘要均符合上节。安装下载远端归档并在Homebrew目录中用独立CLT运行98/98核心、99/99适配器检查及Release编译，包含新的首次启动CLI自检；没有使用本地checkout、file URL或开发app。

`verify-homebrew-install.sh`、安装版 `verify-app.sh`、版本及CLI自检通过：0.2.9、完整来源标记、严格签名、最低macOS14/实际SDK27、单一Cask、Applications唯一真实app、Caskroom受管理链接、无旧Formula/Cask及构建缓存。开发app和独立预览再次移到可恢复废纸篓；工作区内不保留app副本。实际 `brew test` 再次退出1，原因仍是没有该Formula，未伪报成功。

首次打开前，生产偏好域仍不存在。原生Computer Use打开 `/Applications/Remote2Prompt.app` 后，未点击任何向导入口即自动显示“准备遥控器”，包括跳过配置与继续配置。随后只读确认 `initialSetup.presented.v1` 为真且 `configuration.v1` 尚不存在：展示标记和配置分离，旧设置没有恢复。应用留在准备页供用户继续，未跳过安装版向导、请求权限或保存草稿。当前权限显示未允许，不把界面验收说成真实遥控器可用。

## CI与验证边界

现有main工作流继续检查Linux公开边界、全历史凭据和工作流语法，以及macOS15 arm64/Intel独立CLT、远端同仓库Cask安装、安装后核验和实际卸载zap。实际结果见本轮最终main提交对应的[Actions](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml)，旧版或已取消的run不作为最终版本通过证据。

本轮不请求用户辅助按键，不自动恢复旧能力或修改TCC。RC003新手势、50/55秒提醒、目标输入法焦点/鼠标实际穿透、全屏/多屏及最低macOS14真实UI仍保持单列的未验收边界；CI和首次向导成功不能代替这些项目。

## 授权退出重开追查与0.2.10修复

用户在首次向导中授予输入监控、点击系统退出重开后报告未重开。取证时仍是首次启动的旧PID，主循环及权限轮询仍运行，不能归因于3.5秒退出恢复超时。隔离硬件预览复现向导打开时Command-Q无效，跳过后才正常退出；与[Apple关于模态窗口阻止终止且不咨询代理的说明](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal)吻合。

只对向导sheet设置 `preventsApplicationTerminationWhenModal=false`，使退出请求进入现有有界清理；拆除时恢复原值。原生预览验证修复后向导未关闭时Command-Q正常结束进程，没有强杀。未添加守护或自动重启进程，也未请求或重置任何权限。

同时替换0.2.9展示即完成的状态：进行中的本机向导保留pending，只有保存或明确跳过才finished。普通退出和授权重启后回准备页，旧配置的手动向导也可恢复；草稿不持久化。真实ConfigurationStore自检新增中断恢复、手动恢复、旧展示标记及损坏数据边界，CLT构建、bundle、自检与原生退出回归通过。真实TCC系统按钮需要用户后续再次操作核对，不用Command-Q结果伪报该按钮已通过。

0.2.10固定源码为 `df2ca6b7115d19a7b794f40a1df8b001ebed65d8`，公开归档实际下载SHA-256为 `12fd7fa7edca307100c1692fafc53c07bd7d70fabc7d897b222e79a2b69bbda0`；同仓库Cask提交 `923fe607ab6658ad64696bd83135c50dc59fa431`。旧版正常退出且HID恢复记录为空后卸载zap，新克隆HTTPS tap的origin、HEAD、Cask版本和来源均已核对；没有保留开发app或旧设置。

0.2.10远端源码安装实际通过98/98核心、99/99适配器、首次启动CLI自检及独立CLT Release；安装后单Cask来源/版本/摘要、严格签名、Applications唯一真实app、CLI、构建缓存清理和bundle检查通过。`brew test`实际仍退出1并提示无Formula，未伪报为Cask测试成功。

安装版首次打开自动进入准备页。保持向导未关闭执行Command-Q，随后只读检查真实进程已结束、pending仍为真、finished尚未写入；再打开同一Applications app，原生向导重新出现。没有跳过配置、保存草稿、请求权限或写系统输入。应用保留准备页，已请用户另行复测真实TCC系统按钮；截至本次记录该按钮尚无新版人工反馈，不能据普通退出与重开结果判为系统按钮通过。

随后用户在0.2.10安装版真实输入监控授权中再次点击系统“退出并重新打开”，明确反馈“自动重开，并继续显示向导”。该项按用户实测记为通过，与此前普通Command-Q回归分开；未由代理操作隐私设置，也未重置TCC或再更换构建。此通过只覆盖本机这次系统授权重开与向导恢复，不扩展为全部权限/系统版本或真实语音验收。
