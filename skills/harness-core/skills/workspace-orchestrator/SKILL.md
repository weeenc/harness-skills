---
name: workspace-orchestrator
description: 编排多个独立 Git 仓库的全栈变更。维护工作空间变更卡、仓库级 local change、契约版本、联合门禁和提交/PR 对账。
---

# Workspace Orchestrator — 跨仓全栈变更编排

这个技能用于“一个用户需求同时涉及前端和后端”的情况。默认采用 **single-pipeline 模式**：用户只启动一次工作空间级 6 阶段流水线；前后端仓库是每个阶段的执行单元，不再让用户分别启动两套 6 阶段流程。

仓库内原有 Harness 仍负责执行本仓库的构建、测试、静态分析和 hooks。它们产生执行证据，但阶段推进和对用户呈现的唯一状态由 workspace change 负责。

## Single-pipeline 模式

| 工作空间阶段 | 一次性动作 | 仓库执行单元 |
|---|---|---|
| ① harnessing | 分析完整需求、仓库范围、契约和 AC | 生成各仓库任务，不单独启动需求流程 |
| ② coding-skill | 按依赖顺序或并行实现 | 前端/后端各自编码并记录证据 |
| ③ unit-test-write | 汇总测试策略并补齐测试 | 各仓库运行本地测试和覆盖率 |
| ④ expert-reviewer | 对完整跨仓 diff 做一次聚合评审 | 分别读取各仓库 diff，输出一个 workspace review |
| ⑤ unit-test-ci | 执行一次联合质量门禁 | 逐仓 CI + 契约兼容性 + 联调/E2E |
| ⑥ deploy-verify | 执行一次联合发布验证 | 按发布顺序检查前后端健康和回滚 |

用户只需要关注 `WS-*` 的状态。`C-*` 可以作为仓库内执行记录，但不要求用户重复调用六个技能或重复审批。

## 用户执行命令

在 coordinator 工作空间中使用以下命令协议：

```text
/workspace-orchestrator start WS-001 <全栈需求>
/workspace-orchestrator run WS-001
/workspace-orchestrator status WS-001
/workspace-orchestrator resume WS-001
```

`start` 创建 workspace change 并执行 ①；`run` 从当前状态继续执行到下一个需要人工决策的阶段；`resume` 在人工批准或修复后继续；`status` 汇总所有仓库的阶段、commit、门禁和阻塞项。用户不需要手动分别调用前端和后端的 `coding-skill-*`、`unit-test-*` 或 `deploy-verify-*`。

如果宿主不支持带参数的斜杠命令，使用自然语言发送同样的意图，例如：“执行 workspace change WS-001，从当前阶段继续，按 single-pipeline 模式编排所有 required 仓库”。

## 两层状态

工作空间变更卡负责业务整体状态，仓库内可以使用已有 `change.md` 作为执行记录：

```text
workspace: draft → analyzing → implementing → integrating → verifying → done
local repo: draft → analyzing → coding → testing → reviewing → ci → verifying → done
```

在 single-pipeline 模式下，工作空间状态是唯一对外状态；仓库内状态由编排器同步或写入 `repo-execution.md`。只有所有 required 仓库、契约检查和联合验证均通过，workspace 才能进入 `done`。

## 工作空间变更卡

在 workspace `.harness/changes/<id>/workspace-change.md` 记录：

```yaml
id: WS-001
status: implementing
pipeline_mode: workspace_once
repos:
  - id: backend
    local_change: C-101
    branch: feat/ws-001-backend
    required: true
  - id: frontend
    local_change: C-102
    branch: feat/ws-001-frontend
    required: true
contracts:
  - id: backend-api
    source_repo: backend
    consumer_repos: [frontend]
    version: v1
integration:
  command: <真实的联调或 E2E 命令>
```

正文必须补充 REQ/AC、跨仓依赖、契约变更、联合验证、发布顺序和回滚顺序。

## 执行顺序

1. 调用 `repo-discovery`，确认仓库、模块和 Git 状态。
2. 在 workspace 变更卡中固定 API/事件/数据库契约的唯一来源。
3. 为每个需要改动的仓库登记 local change 或 `repo-execution.md`，并记录 `depends_on` 或 `relates_to`。
4. 先完成契约，再允许前后端并行编码；后端未就绪时，前端使用 `harness-api-mock`，mock 必须来自同一契约。
5. 在工作空间的 ②~③ 阶段批量调度各仓库执行编码和测试，不重新启动各自的需求分析流程。
6. 在 ④ 阶段聚合各仓库 diff，输出一份 workspace review。
7. 在 ⑤ 阶段按 `repo-map.yaml` 逐仓运行门禁，再运行契约兼容性和联合 E2E；命令必须使用 `git -C <repo>` 或进入对应仓库执行。
8. 在 ⑥ 阶段记录真实的 commit SHA、门禁报告和部署版本，按依赖顺序完成发布验证。
9. 只有所有 required 仓库都通过，才将 workspace 变更卡置为 `done`。

## 必须阻断的情况

- 需求命中多个仓库，但没有 workspace change；
- 前后端使用不同版本的接口契约；
- 某仓库有未登记的工作区改动；
- 只验证了一个仓库，却声称全栈需求已完成；
- workspace 根目录没有 Git 协调仓库，且需要提交映射、变更卡或联合门禁证据。

## 完成标志

- 每个 local change 都有明确仓库、分支、commit 和本地门禁证据；
- 契约检查通过，前端 mock/生成代码与契约版本一致；
- 联合验证通过并留存证据；
- workspace change 与各 local change 的状态、提交和 PR 可互相追溯。
