# Agent Note: 源码 Formula 与应用生命周期分离

Status: proposed

## Problem

源码 Formula 仅安装 keg 内的 app，手工链接到应用程序后，Formula 卸载不能完整管理该入口。用户需要 Homebrew 从源码编译、实际安装到应用程序，并支持对应清理。

## Proposal

保留 `remote2prompt` Formula 在独立 CLT 和 Homebrew 沙箱中测试、编译、签名与验证；配套 `remote2prompt-app` Cask 依赖该 Formula，核对源码归档 SHA-256 后复制已编译的 app，由标准 `app` artifact 安装本体到 `/Applications` 并拥有其卸载。Cask 不下载预编译二进制。Formula 测试额外核验应用程序中的 app 与本次编译结果一致。

公开 tap 固定完整源码 commit 的 GitHub 归档 URL 与 SHA-256；每次发布更新 `VERSION`，不引用移动的 main。源码、根目录 `Formula/`/`Casks/` 和 CI 保留在同一个仓库，以显式仓库 URL 执行 tap。CI 检查：两种架构的 CLT 源码构建、安装、`brew test`、真实目录检查、卸载及 `--zap` 设置清理。生成的 tap、归档、app、日志与本机信息不提交到源码仓库。

普通 Cask 卸载移除 app，Formula 卸载移除构建文件和命令；`--zap` 仅清理本应用的偏好、缓存和恢复记录，不清理 TCC 或驱动。删除恢复记录前必须退出应用并确保无待恢复原生映射；未完成恢复时保留记录排查。

## Alternatives considered

**Formula 的 post_install 复制 app。** 没有成对的标准卸载回调，容易留下失去管理的副本。

**继续手工软链接。** 入口依赖 keg，用户不能从普通安装流程得到完整应用生命周期。

**Cask 下载发布二进制。** 安装管理直接，但不满足这次源码编译要求，也需要独立签名与公证工作。

## Acceptance criteria

实际远端 tap 的固定源码可下载并通过 SHA 校验，用 CLT 编译安装；应用程序路径为真实 app 而非软链接，`brew test` 验证两处代码一致。实际卸载清除本体及启动命令，`--zap` 清理设置；最后重新从远端源码安装并保留可用应用。公开前完成当前源码与全历史脱敏检查，云端 CI 结果独立记录。

## Risks

源码产物和安装本体占用两份空间，分两条卸载命令管理；升级时必须先升级 Formula 再升级 Cask。临时签名更新后可能需重新授权；系统隐私授权不能由 Homebrew 测试证明。项目尚未选择许可证；公开源码不等于授权再分发。真实遥控器、音频与系统输入切换不属于本次安装验证。
