# 0.2.12胶囊跟随源码发布与清洁安装

日期：2026-10-29。用户明确授权commit、脱敏、公开推送、同仓库tap、从远端源码清洁安装及清除现有设置。复用唯一public仓库`realDGD/Remote2Prompt`，不另建仓库、Formula或第二个Cask。

## 发布范围与边界

本版包含微信语音胶囊跟随：仅真实遥控器50–60秒倒计时查询位置，避开胶囊及上方文字，未知/歧义/消失时回退固定位置。窗口来源限本机实测微信输入法3.0.0；不读标题、文字、剪贴板或音频，不改变语音、按键与系统输入事务。实测、102项核心/108项适配器检查及隔离原生面板检查已在[功能记录](2026-10-29-wetype-capsule-follow.md)分开记录。

沿用[Agent Note](../../.agents/notes/implemented/feature/2026-10-29-follow-wetype-capsule.md)、SwiftPM与独立CLT、单源码Cask、默认临时签名和Applications唯一app本体。不创建证书、不安装音频驱动、不重置系统隐私授权。`.gitignore`已核实排除本地探测、构建、日志、配置导出及签名材料；公开边界检查覆盖当前源码与所有可达历史，凭据扫描另行执行。

## 发布与安装执行记录

功能以`50361db`、`81bea85`、`eb35ccc`三个阶段提交。版本源码commit为`18cb09b779bb01ca1218fc03f4ae215a9195a72c`，已推送main；从该commit的公开HTTPS归档下载并计算SHA-256为`ab8f3e300262c4761bf19dabb4b949b7e50f91551732c58f2f77cdfebe122f2f`，同仓库唯一Cask固定此来源。发布前公开边界全历史扫描、gitleaks全历史凭据扫描、actionlint与文档检查通过。

安装必须使用README的公开HTTPS tap与固定远端归档，不使用本地checkout或file URL。清理只针对本项目app、Homebrew条目及用户授权清除的设置；保留系统TCC、蓝牙配对和其他应用。实际CI、清洁安装及核验结果在执行后追加。

`brew test`仅支持Formula。本项目保持单Cask安装，记录该命令的真实结果，同时以安装期源码测试、CLT编译和`verify-homebrew-install.sh`完成适用的安装核验；不把命令不适用伪报为通过。

## 未覆盖项目

真实RC003持续至50秒时的微信叠加、跨屏/文字暂存切换、真实鼠标点透、全屏/Stage Manager及微信重启仍待端到端验收。CI、数字窗口实测、隔离面板和首次向导成功不能替代这些场景。
