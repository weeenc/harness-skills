---
id: WS-NNN
status: analyzing
pipeline_mode: workspace_once
created: <date>
repos:
  - id: <repo-id>
    local_change: <C-NNN>
    required: true
contracts:
  - id: <contract-id>
    source_repo: <repo-id>
    consumer_repos: []
integration:
  command: <真实命令>
---

# WS-NNN <跨仓变更标题>

## 用户故事
作为 <角色>，我想要 <功能>，以便 <价值>。

## 验收标准
- AC-1: …
- AC-2: …
- AC-3: …

## 仓库分工
| 仓库 | local change | 模块 | 依赖 | 分支/commit/PR |
|---|---|---|---|---|
| `<repo-id>` | `<C-NNN>` | … | … | … |

## 契约与版本
- 唯一来源：…
- 契约版本：…
- 兼容窗口：…
- mock/生成客户端同步方式：…

## 联合验证与发布
- 本地联调命令：…
- E2E 命令：…
- 发布顺序：…
- 回滚顺序：…
