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
| ④ expert-reviewer | 对完整跨仓 diff 做一次聚合评审 | 分别读取各仓库 diff，汇总到 workspace report.md 的④章节 |
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

| 命令 | 执行边界 |
|---|---|
| `start` | 创建 workspace change、共享报告及各仓库执行卡，只执行 ① 需求分析；完成后停下，等待实施授权。 |
| `run` | 用户对指定 workspace change 发出的实施授权；从当前状态推进到下一个需要人工决策的阶段。 |
| `resume` | 在已有实施授权的范围内，于人工批准或修复后继续；没有实施授权时仍停留在 ①。 |
| `status` | 只汇总所有仓库的阶段、commit、门禁和阻塞项，不触发实施。 |

用户不需要手动分别调用前端和后端的 `coding-skill-*`、`unit-test-*` 或 `deploy-verify-*`。

如果宿主不支持带参数的斜杠命令，使用自然语言发送同样的意图，例如：“执行 workspace change WS-001，从当前阶段继续，按 single-pipeline 模式编排所有 required 仓库”。

### ① → ② 的实施授权边界

- `start` 只授权准备工作：读取仓库与 Git 状态、分析需求和契约、记录 REQ/AC 与分工、创建或更新变更卡和报告。不能修改业务代码、测试、可执行契约、mock、生成客户端或实施所需配置，也不能调用编码技能或把编码任务委派给子代理。
- 完成 ① 后，workspace 保持 `status: analyzing`、`stage: harnessing`，新建 local change 保持 `analyzing`；报告①记录“等待实施授权”，②~⑥保持未执行。向用户给出卡片/报告位置、分析结论、未决问题和下一步 `run` 命令，然后结束本次 `start`。
- 只有用户明确确认对该变更开始实施（如“确认 WS-001 方案，开始编码”），或用户实际发出 `run WS-001`（含明确等价的自然语言请求），才允许进入②。仅确认需求事实、回答分析问题、分析已完成、没有未决问题、用户沉默或报告里建议的 `run` 命令，都不构成实施授权；编排器不能自行调用 `run`。
- 进入②前，在报告①的审批/关键决策中记录授权来源、用户原话或命令、授权范围；再将 workspace 更新为 `implementing` / `coding-skill` 并同步 local change。`run` 不代替尚未解决的需求、架构或发布决策。
- `resume` 和子仓技能都必须读取该变更的授权记录；缺失时不能从准备产物或状态值推断已获授权。已记录的授权在其范围内继续有效，不要求各仓重复审批；单独执行 `start` 仍只做准备工作，不自动恢复实施。

## 两层状态

工作空间变更卡负责业务整体状态，仓库内可以使用已有 `change.md` 作为执行记录：

```text
workspace: draft → analyzing → implementing → integrating → verifying → done
local repo: draft → analyzing → coding → testing → reviewing → ci → verifying → done
```

在 single-pipeline 模式下，工作空间状态是唯一对外状态；仓库内状态由编排器同步到各自 `change.md`。只有所有 required 仓库、契约检查和联合验证均通过，workspace 才能进入 `done`。

## 工作空间变更卡

在 workspace `.harness/changes/<id>/workspace-change.md` 记录：

```yaml
id: WS-001
status: analyzing
pipeline_mode: workspace_once
artifact_mode: compact
stage: harnessing
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

## 变更文档与运行数据

遵循 `.harness/changes/README.md`。新全栈需求只在协调仓保留 `workspace-change.md` 与 `report.md`；六阶段各更新已有报告章节，只有协调者写入共享报告。旧卡没有 compact 标记时兼容原报告，不自动迁移。

子仓只保留 `change.md`：`id`、`status`、`artifact_mode: compact`、`workspace_change`、`workspace_ref`、`report_ref`、分工和 commit/PR。两个引用均相对本地卡片目录计算；先确认目标 workspace-change 的 ID。协调者同步本地状态，子仓技能返回执行结果，由协调者按仓库汇总；不重复需求审批，不生成第二套阶段报告。子仓 `review-check` 直接通过 report_ref 检查共享报告，不复制本地 review.md。

初始化协调层时也复制 changes/README.md、changes/.gitignore、卡片/报告模板与无语言参数的 scripts/report.sh、scripts/review-check.sh。若生成联合门禁包装器，采用以下产物边界：

- 每个门禁原始输出与最新结果写 `changes/.runtime/<WS-ID>/<repo>/<gate>/` 的固定文件；单仓脚本的摘要留在其本地 `.runtime/<C-ID>/`。不在持久需求目录创建 evidence/run-*。
- 每次检查不复制两仓完整 diff；需要保留未提交状态时，每份不同代码状态仅存一份快照，各检查引用它。原始输出、快照都由 `changes/.gitignore` 的 `/.runtime/` 忽略；不能把其他目录的 local 配置当缓存。
- 阶段结束只将仓库、命令、版本/dirty 范围、时间、rc、关键断言与限制写入共享 report.md。重要历史原始证据需要稳定制品地址；不能仅链接本机日志。
- 真正的验证代码仍在项目测试目录；wiki/tech/rules/契约等沿用原维护方式。运行区不能替代共享知识或唯一源码备份，也不自动清理。

## 执行顺序

1. 调用 `repo-discovery`，确认仓库、模块和 Git 状态。
2. 在 workspace 变更卡中固定 API/事件/数据库契约的唯一来源。
3. 为每个需要改动的仓库从 local-change.md 模板创建 change.md 执行卡，标记 artifact_mode: compact，填写 workspace_ref / report_ref，并记录关系；不复制整个模板目录。
4. 完成①并更新共享报告；`start` 在此停止。只有满足上述实施授权边界后，才继续以下步骤。
5. 先实现契约，再允许前后端并行编码；后端未就绪时，前端使用 `harness-api-mock`，mock 必须来自同一契约。
6. 在工作空间的 ②~③ 阶段批量调度各仓库执行编码和测试，不重新启动各自的需求分析流程。
7. 在 ④ 阶段聚合各仓库 diff，更新 workspace report.md 的④章节。
8. 在 ⑤ 阶段按 `repo-map.yaml` 逐仓运行门禁，再运行契约兼容性和联合 E2E；命令必须使用 `git -C <repo>` 或进入对应仓库执行。
9. 在 ⑥ 阶段的共享报告记录真实的 commit SHA、具名门禁结论和部署版本，按依赖顺序完成发布验证。
10. 只有所有 required 仓库都通过，才将 workspace 变更卡置为 `done`。

## 必须阻断的情况

- 没有用户明确实施确认或用户发出的 `run`，却试图从①进入②、修改实现文件或调度子仓编码；
- 需求命中多个仓库，但没有 workspace change；
- 前后端使用不同版本的接口契约；
- 某仓库有未登记的工作区改动；
- 只验证了一个仓库，却声称全栈需求已完成；
- workspace 根目录没有 Git 协调仓库，且需要提交映射、变更卡或联合门禁证据。

## 完成标志

- 每个 local change 都有明确仓库、分支、commit、共享报告引用和本地门禁摘要；
- 契约检查通过，前端 mock/生成代码与契约版本一致；
- 联合验证通过并留存证据；
- workspace change 与各 local change 的状态、提交和 PR 可互相追溯。
