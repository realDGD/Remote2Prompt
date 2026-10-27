# Agent Notes

Note 保存长期有用的决策理由和放弃的方案，代码、测试及当前文档保存实际行为。规则裁剪自 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/README.md)。本项目使用 `.agents/`，不另建 `.agent/`。

## 路径与状态

路径为 `{lifecycle}/{class}/yyyy-mm-dd-topic.md`；日期是首次提出的日期，不是最后更新时间。类别限定为 `feature`、`bug-fix`、`simplification`、`architecture`、`process`、`testing`。

- `proposed/`：未来或部分实现的提案，包含问题、方案、备选、验收和风险。
- `implemented/`：已经接入的决策，用现在时描述实际行为，跟随当前文件路径、默认值和结构更新事实。
- `rejected/`：保留仍有价值的拒绝理由，状态行写明原因。
- `archived/`：仅在已实现决策不再指导当前工作时保存历史；归档内容冻结，不作为当前行为依据。尚无归档时不创建占位文件。

不要为每次修改写 Note。新的能力边界、设备接管语义、配置格式、清理规则、构建与分发取舍值得记录；机械改名和局部 UI 调整通常不需要。搜索已有 Note 并更新同一决策，避免重复索引和流水账。

## 文件格式

前三行固定为标题、空行和状态；正文首先是 `## Problem`。标题和状态标记使用英文，正文使用中文。

```markdown
# Agent Note: 标题

Status: proposed

## Problem

说明问题。

## Proposal

说明方案及当前实施范围。

## Alternatives considered

说明真实考虑过的替代方案及未选原因。

## Acceptance criteria

可观察、可验证的完成条件。

## Risks

风险和代价。
```

已实现 Note 用 `## Decision` 替代 `## Proposal`，用 `## Consequences` 替代验收与风险。拒绝的 Note 保留提案内容，状态行改为 `Status: rejected — 原因`。迁移状态时同一次修改移动文件、改状态、重写对应章节并修复相对链接。归档时增加 `Archived: YYYY-MM-DD`，不再更新内容。

纯策略代码及 UI 设置存在、系统适配器尚未接入的功能继续留在 proposed。`make docs-check` 检查路径、状态、必需章节及本地链接；它不能代替实际功能验收。
