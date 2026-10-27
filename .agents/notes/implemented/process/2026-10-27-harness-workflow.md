# Agent Note: 采用精简的 Harness 仓库工作方式

Status: implemented

## Problem

空仓库需要为持续的 Agent 开发保留需求、决策和验证依据，但完整复制大型 Harness 的规则会让本地 Swift 项目的维护成本高于收益。

## Decision

根 `AGENTS.md` 作为渐进阅读入口，`CLAUDE.md` 软链接到它。当前产品和架构写在 `docs/`，持久理由按生命周期与类别写在 `.agents/notes/`，任务清单写在 `.agents/plans/`。Note 沿用 Harness 的标题、状态、问题、替代方案和状态迁移规则。

两个仓库技能分别覆盖 Note 维护和相关检查，不自动引入额外技能链。`make docs-check` 验证 Note 格式、相对链接和基础文件卫生。中文为主要维护语言，不建立双语对应文件或集中 Note 索引。

## Alternatives considered

**完整复制 Harness 的 AGENTS 和技能。** 其 Cordis、TypeScript、持久会话协议和发布检查不属于本产品，会引入无效约束和过多依赖。

**只有 README 和 TODO。** 启动成本更低，但设备接管、按键释放和 CLT 分发等决策理由容易在会话之间丢失。

## Consequences

后续 Agent 能从当前代码与决策分开判断真实进度。只为长期理由写 Note，小改动保持轻量；检查器只能验证文档结构，不能证明架构合理或真实功能可用。Superpowers 的使用范围继续遵守用户的全局约定。
