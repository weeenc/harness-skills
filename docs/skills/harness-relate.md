# 变更关系链管理 — harness-relate

> **技能标识**: `harness-relate`
> **使用场景**: "改这个 change 会影响哪些别的 change？"——动工前先看牵连
> **定位**: 只读查询不修改文件；写操作只改两个索引文件（`_relations.json` / `_graph.md`），不改任何 change.md 正文

## 它做什么？

管理 `.harness/changes/` 下各 change 之间的**六类关系**，维护反向索引 `_relations.json` 与可视化 `_graph.md`。**核心价值：改一个 change 之前，先知道它牵连哪些 change**（`impact`）。

## 六类关系

| 关系类型 | 含义 | 是否对称 |
|---------|------|---------|
| `extends` | B 扩展 A（A 是 B 的基础） | 否 |
| `depends_on` | B 依赖 A（A 必须先完成） | 否 |
| `supersedes` | B 取代 A（A 被 B 替代/废弃） | 否 |
| `resolves` | B 解决 A（A 是 B 解决的 issue/债） | 否 |
| `conflicts_with` | A 与 B 冲突（改动区域/契约重叠） | **是** |
| `relates_to` | A 与 B 相关联（弱关系） | **是** |

对称关系在写入时**镜像**到对方 change 的反向索引。

## 文件布局

```
.harness/changes/
├── <id>/change.md        # 每个 change 自带 relations 元数据（见模板）
├── _relations.json       # 关系反向索引（唯一事实源，机器读）
└── _graph.md             # 关系图（人读，由 _relations.json 生成，禁止手工编辑）
```

## 子命令

| 子命令 | 作用 |
|--------|------|
| `set <source> <type> <target> [reason]` | 添加关系（对称类型自动镜像），触发 `rebuild` 刷新索引与关系图 |
| `query <id>` | 显示全部关系：出边 + 入边 |
| `impact <id>` ⭐ | **杀手锏**：评估改动 `<id>` 会影响哪些 change，按严重度分级输出 |
| `orphans` | 列出无任何关系且未 done 的孤立 change（提示可能遗漏依赖标注） |
| `rebuild` | 扫描所有 change.md 的 relations 元数据，重建 `_relations.json` + `_graph.md` |
| `validate` | 校验元数据与索引一致性、target 存在性、自引用禁止 |

### impact 影响分级

1. 从 `_relations.json` 找所有**指向** `<id>` 的关系（入边）
2. 递归一层展开受影响 change
3. 按严重度排序输出：
   - 🔴 **阻断**：`depends_on <id>` 的 change（依赖它，先动会崩）
   - 🟡 **冲突**：`conflicts_with` 的 change（改动区域重叠）
   - 🟢 **关联**：`relates_to` / `extends` / `resolves` 的 change（弱影响）
4. 无关系 → 输出"无其他 change 受影响，可独立推进"
5. 提示：修改 `<id>` 前先处理所有 🔴 阻断项（或与人类确认顺序）

## 什么时候用？

- **动工前**：改 A 之前先 `impact <id>`，看它牵连哪些 change
- **评审时**：多个 change 并存，校验 `validate` 防止改 A 破坏 B
- **需求分析时**：`harnessing` 评估新需求触碰哪些存量 change

## 为什么需要它？

| 问题 | 解法 |
|------|------|
| 改 A 破坏了依赖它的 B，上线才炸 | impact 分级清单（🔴 阻断先行处理） |
| 多个 change 改动区域重叠互相踩 | `conflicts_with` 标注 + 评审重点核对 |
| 关系散落在各 change 里无法总览 | `_relations.json` 反向索引 + `_graph.md` 可视化 |
| 手工改过 change.md 导致索引不一致 | `validate` 检查 + `rebuild` 恢复 |

## 与流水线的联动

| 场景 | 动作 |
|------|------|
| `harnessing` 分析影响面 | 调用 `impact` 评估新需求触碰哪些存量 change |
| `coding-skill` 开工前 | 调用 `impact <id>` 检查被影响的 change 是否已 done |
| `expert-reviewer` 评审 | 校验 `validate`，防止改 A 破坏 B |
| 变更多个并存 | 用 `conflicts_with` 标注重叠区域，评审时重点核对 |

## 完成标志

- `set`/`rebuild` 后 `_relations.json` 与 `_graph.md` 已同步
- `impact` 已输出分级影响清单（🔴/🟡/🟢）
- `validate` 无一致性错误（或已提示 rebuild）