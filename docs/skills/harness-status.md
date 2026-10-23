# 变更状态总览 — harness-status

> **技能标识**: `harness-status`
> **使用场景**: "现在做到哪了？还有哪些变更卡着？"——看一眼全项目进度
> **定位**: 只读聚合总览，不修改任何 change 状态

## 它做什么？

扫描 `.harness/changes/` 下所有变更卡，输出项目当前的开发进度总览：哪些 change 在进行中、哪些已完成、哪些异常、下一步该做什么。

```
.harness/changes/*/change.md
    ↓ 逐个解析 frontmatter 的 status 字段
按状态分组（进行中 / 草稿 / 已完成 / 异常）
    ↓
输出：总览表 + 阶段分布条形图 + 待办建议
```

## 核心机制

### 状态分组

| 分组 | status 值 |
|------|----------|
| 🚧 进行中 | `analyzing` / `coding` / `testing` / `reviewing` / `ci` / `verifying` |
| ⏸ 草稿 | `draft` |
| ✅ 已完成 | `done` |
| ❌ 异常 | 无法解析 frontmatter，或 status 值未知 |

### 输出三块内容

1. **总览表**：`📊 变更总览：N 个（进行中 X · 草稿 Y · 已完成 Z · 异常 W）`，按 id 升序列出每个 change
2. **阶段分布**：条形图直观展示各阶段数量（条形长度 ∝ 数量）
3. **待办建议**（每条一行，机器可读）：按当前阶段给出下一步命令

```
<id> → <下一步建议命令>  (<标题>)
```

| 当前 status | 下一步 | 建议命令 |
|-------------|--------|---------|
| `draft` | 需求未启动 | `/harnessing` 细化或删除 |
| `analyzing` | 需求卡待审批 | 提示人类审批后置为 `coding` |
| `coding` | 编码实现 | `/coding-skill <id>` |
| `testing` | 单测编写 | `/unit-test-write <id>` |
| `reviewing` | 专家评审 | `/expert-reviewer <id>` |
| `ci` | CI 门禁 | `/unit-test-ci <id>` |
| `verifying` | 部署验证 | `/deploy-verify <id>` |

## 什么时候用？

- 想知道"现在做到哪了"、分派下一步工作
- 多个 change 并存，需要看整体进度和卡点
- 无进行中 change 且已有 done change 时，提示可启动新需求或 `/harness-retro` 复盘

## 为什么需要它？

| 问题 | 解法 |
|------|------|
| 变更一多，不知道整体进度 | 一页总览所有 change 状态 |
| 不知道下一步该干什么 | 按状态给出机器可读的待办建议 |
| 有 change 卡在某个阶段 | 阶段分布条形图直接暴露瓶颈 |
| 有损坏/异常的状态数据 | ❌ 异常分组显式列出，不静默跳过 |

## 核心纪律

- **只读**：状态迁移由流水线技能（coding-skill / unit-test-write / expert-reviewer / unit-test-ci / deploy-verify）负责
- **异常不静默**：解析失败的 change.md 列入 ❌ 异常并输出文件路径与错误

## 输出

一页进度总览：总览表 + 阶段分布条形图 + 待办建议（无进行中变更时附复盘提示）。

## 完成标志

- 已输出总览表 + 阶段分布 + 待办建议
- 异常 change 已显式列出（若有）
- 未修改任何 change 文件