# 0.2.2 单源码 Cask 验证

日期：2026-10-28。用户要求一个 Homebrew 安装项、CLT 源码构建、Applications 本体、成套卸载，减少重复 app；安装测试必须像新用户一样使用远端仓库。

## 固定来源

- 源码：`ee59f4e23a08af1513949c6cde3061ef8ec1868d`，版本 0.2.2。
- 实际 GitHub 归档 SHA-256：`009ee5e1c14678b7db377f2cb6ce1eed86a4f8c5186be2796ad008a4f9602404`。
- 单 Cask：`realdgd/remote2prompt/remote2prompt`，不依赖 Formula，不引用移动的 main，不下载预编译 app。

## 安装前检查

独立 CLT `make check` 通过，核心 69/69、适配器 59/59、Release bundle/签名、文档与脱敏通过。生成器只做静态归档与 Ruby 语法检查，没有安装本地 tap。两个构建/验收脚本的参数检查及 Bash 语法检查通过。

## 远端验收

- [x] 移除旧双项，untap 后以公开 HTTPS URL 重新 tap；只从远端固定归档安装。
- [x] 实际 Cask sandbox 编译、签名内来源和安装自检通过。
- [x] 仅一个 Cask；无 Formula、旧 Cask、第二份 app 或构建缓存；CLI 指向 Applications 本体。
- [x] 实际卸载与 zap 清理 app、CLI、设置和 Caskroom，再从远端重新安装。
- [x] 两种架构 CI 已配置并触发远端安装和卸载验收；最终文档 HEAD 的结果由交付时核对 [Actions](https://github.com/realDGD/Remote2Prompt/actions/workflows/ci.yml)，不为补填结果循环提交。

## 本机实际过程

1. 正常卸载旧 Cask `remote2prompt-app` 与 Formula `remote2prompt`，原生恢复记录为空；删除核对身份且未运行的开发 app。
2. `brew untap realdgd/remote2prompt` 删除旧 checkout，再执行 `brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git`。实际克隆到配方提交 `f1b2ff2b52cc344983944ab3cd486faedab20fa8`，Homebrew 报告只有一个 Cask。安装元数据的 URL 和 SHA 与上面的固定来源一致，依赖只有 macOS 14，不含 Formula。
3. 执行 `brew install --cask realdgd/remote2prompt/remote2prompt`，Cask sandbox 内运行核心 69/69、适配器 59/59、CLT Release 构建和 bundle 检查。编译阶段约 30 秒，不包含前面的检查时间；没有传入本地源码目录或 file URL。
4. `scripts/verify-homebrew-install.sh` 对照远端 Cask 元数据验证签名内来源、自检、版本、签名、CLI、唯一 app 和构建缓存清理，全部通过。`/Applications/Remote2Prompt.app` 是本体；Caskroom 内只找到一个同名链接、零个真实 app 目录，没有 `.build`，Cellar 中无 `remote2prompt`，旧 Caskroom 也不存在。
5. 写入本应用专用的合成偏好标记，再执行一条 `brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt`。核对 app、CLI、Caskroom、偏好文件都不存在，标记也不能再由 defaults 读到；没有悬空链接。
6. 再次执行同一远端 Cask 安装命令并重新编译，最终验收再次通过，留下唯一 `remote2prompt 0.2.2` Cask。生产偏好、ByHost、缓存、保存状态和 Application Support 仍为空，开发 app 不存在。

另用自动清理的隔离路径样例验证启动器的相对/绝对链接链与带空格 appdir，正确定位实际目标；该检查不调用 Homebrew，也不安装或启动真实 app。原始安装输出留在被忽略的本机目录。

## 边界

brew test 只支持 Formula，不用它冒充 Cask 安装验收。原生菜单、真实遥控器、语音输入法和最低 macOS 14 不由打包检查证明。本轮不创建证书、不重置 TCC、不安装驱动、不重建自动任务。
