# 0.2.2 单源码 Cask 验证

日期：2026-10-28。用户要求一个 Homebrew 安装项、CLT 源码构建、Applications 本体、成套卸载，减少重复 app；安装测试必须像新用户一样使用远端仓库。

## 固定来源

- 源码：`ee59f4e23a08af1513949c6cde3061ef8ec1868d`，版本 0.2.2。
- 实际 GitHub 归档 SHA-256：`009ee5e1c14678b7db377f2cb6ce1eed86a4f8c5186be2796ad008a4f9602404`。
- 单 Cask：`realdgd/remote2prompt/remote2prompt`，不依赖 Formula，不引用移动的 main，不下载预编译 app。

## 安装前检查

独立 CLT `make check` 通过，核心 69/69、适配器 59/59、Release bundle/签名、文档与脱敏通过。生成器只做静态归档与 Ruby 语法检查，没有安装本地 tap。两个构建/验收脚本的参数检查及 Bash 语法检查通过。

## 远端验收

- [ ] 移除旧双项，untap 后以公开 HTTPS URL 重新 tap；只从远端固定归档安装。
- [ ] 实际 Cask sandbox 编译、签名内来源和安装自检通过。
- [ ] 仅一个 Cask；无 Formula、旧 Cask、第二份 app 或构建缓存；CLI 指向 Applications 本体。
- [ ] 实际卸载与 zap 清理 app、CLI、设置和 Caskroom，再从远端重新安装。
- [ ] 两种架构的最终 HEAD CI 通过；界面与硬件边界单独记录。

## 边界

brew test 只支持 Formula，不用它冒充 Cask 安装验收。原生菜单、真实遥控器、语音输入法和最低 macOS 14 不由打包检查证明。本轮不创建证书、不重置 TCC、不安装驱动、不重建自动任务。
