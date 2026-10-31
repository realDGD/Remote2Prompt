# Agent Note: VoiRemote 名称、登录启动与 Dock 生命周期

Status: implemented

## Problem

用户要求完整更名，包含应用、源码、仓库和目录；登录静默运行，设置打开时显示Dock，关闭时默认隐藏，也可选择常驻。

## Decision

应用、模块、命令和配方使用VoiRemote / voiremote，应用标识固定为`dev.voiremote.app`。`LegacyIdentity`仅为兼容旧数据保留旧标识；历史验证中的实际签名身份和Git历史不重写，不能把旧身份的授权验收算作新身份通过。

首次启动只读复制旧域中的原始配置和向导标记，不覆盖新配置、不删旧数据；损坏配置保留错误提示。导出使用新格式，导入兼容旧格式。系统授权不迁移，新标识需首次重新授权。

登录项使用`SMAppService.mainApp`，默认不注册，由用户在“通用”页设置，显示真实状态及错误。登录Apple Event或`--background`走静默路径，不创建设置窗口或向导；用户打开设置后才继续向导。

SwiftUI仅创建菜单栏场景。AppKit按需创建设置窗口，内部保留原生NavigationSplitView；打开切regular，关闭指定窗口后按Dock偏好切accessory。提醒和权限帮助窗口不驱动该状态。Dock常驻默认关闭，本机偏好不进入便携导出。退出沿用已有资源清理，卸载命令提供本应用登录项注销。

## Alternatives considered

- 只改显示名保留旧标识：能保留权限，但不满足完整更名的选择。
- SwiftUI Settings场景启动后隐藏：本机检查发现后台启动仍会创建可见窗口，故改为按需窗口，避免先显示再隐藏。
- LaunchAgent、helper或第三方包：macOS14+可直接使用系统主应用登录项API，无需额外组件。

## Consequences

必要的CLT Release、bundle及配置自检通过；聚焦检查覆盖旧配置保留、不覆盖新配置、损坏配置及旧格式导入。原生隔离检查通过静默零窗口、设置打开/关闭/重开与Dock常驻切换；Computer Use确认“通用”页默认值。隔离检查没有访问设备。远端安装后实际注册/注销系统登录项成功并恢复关闭；没有执行真实登出/登录。

仓库、目录与公开Cask的交付结果另记，源码实现不等于部署已完成。新标识授权需用户首次操作；GitHub更名会改变新下载归档的根目录和摘要，历史摘要仅保留原记录含义。
