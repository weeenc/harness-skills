# 独立 Git 仓库的全栈开发支持

参考 `process-platform` 的结构，前端和后端可以继续保持两个独立 Git 仓库，并分别拥有 `.harness/agents/owner.md`、规则、skills、changes、脚本和 hooks。当前缺少的是父级协调层，而不是把两个仓库强行改成 monorepo。

推荐采用三层结构，并在 workspace change 中设置 `pipeline_mode: workspace_once`：

```text
workspace coordinator（独立 Git 仓库）
├── .harness/repo-map.yaml
├── .harness/changes/WS-*/workspace-change.md
├── contracts/ 或契约仓库引用
└── scripts/workspace-gate.sh

process-platform-frontend（独立 Git 仓库）
└── .harness/changes/C-*/change.md

process-platform-backend（独立 Git 仓库）
└── .harness/changes/C-*/change.md
```

工作空间协调仓库可以通过 Git submodule 固定前后端 commit，也可以只维护 clone 路径和 commit 清单。前者复现性更强；后者适合现有目录已经是两个独立仓库的情况，但必须把 commit SHA 写进 workspace change。

## 与参考项目的对应关系

参考项目已经验证了“每仓库独立 Harness”的可行性：前端与后端各自生成 `.harness/`，各自运行本地 lint、测试、评审和 CI。这一层应保留。

需要补上的能力是：

- 工作空间仓库地图：明确 `frontend`、`backend`、契约和联调入口；
- workspace change：把一个需求关联到多个 local change；
- 契约单一来源：OpenAPI、事件 schema 或共享 DTO 必须有版本；
- 联合门禁：逐仓执行本地门禁，再执行 API 兼容性、联调和 E2E；
- 发布对账：记录每个仓库的 commit、构建产物、部署版本和回滚顺序。

## 只执行一次 6 阶段流水线

工作空间变更卡是唯一对外状态源。① 需求分析、④ 聚合评审、⑤ 联合 CI、⑥ 发布验证各执行一次；② 编码和③ 测试阶段由编排器把任务分发到前端和后端仓库，分别运行它们的真实构建和测试命令。仓库内的 `change.md` 保留本地 id/status、分工和提交关联，以 workspace_ref/report_ref 指向协调层需求与报告，不要求用户再次审批或手动推进一套完整状态机。

实际使用时，在 coordinator 工作空间执行：

```text
/workspace-orchestrator start WS-001 <全栈需求>
/workspace-orchestrator run WS-001
```

状态查询和中断后继续执行：

```text
/workspace-orchestrator status WS-001
/workspace-orchestrator resume WS-001
```

## 不建议的做法

- 只在前端仓库建 change，却把后端改动当作“顺手修改”；
- 从工作空间根目录执行一次 `git diff`，假设它能覆盖子仓库；
- 把接口约定只写在前端或后端代码注释里；
- 复制两套 `.harness/` 到父目录，造成规则与门禁漂移；
- 为了统一命令，把两个仓库改成 monorepo。

## 推荐落地顺序

1. 在当前父目录初始化 coordinator 仓库，或选择一个已有平台仓库承载 `.harness/`。
2. 执行 `repo-discovery`，生成并确认 `.harness/repo-map.yaml`。
3. 执行 `apply-harness` 时分别在前端和后端仓库生成本地 Harness。
4. 为工作空间增加 `workspace-change.md` 模板和联合门禁脚本。
5. 将 `harness-api-mock` 接入契约版本，前端 mock 与后端契约使用同一来源。
6. 在 CI 中按“契约检查 → 前端/后端本地门禁 → 联合 E2E → 发布对账”执行。

新需求默认 artifact_mode: compact：协调层只保留 workspace-change.md + 六阶段 report.md，子仓各一份执行卡；review-check 读取共享报告，不复制子仓 review.md。临时输出放 changes/.runtime/，不按每次运行保存两仓完整 diff。详见 [变更管理](../change-management.md)。
