# `workspace-orchestrator`：跨仓全栈变更编排

该技能在仓库级 Harness 之上增加一层工作空间状态机。推荐使用 `pipeline_mode: workspace_once`：用户只启动一次 6 阶段流水线，workspace change 记录整体验收标准、仓库分工、local change ID、契约版本、分支/commit/PR、联合门禁和发布回滚顺序；前后端仓库只执行对应阶段的构建、测试和门禁动作。

它解决两个常见误判：前端完成不等于全栈完成，单仓库 CI 通过不等于跨仓链路可用。只有所有 required 仓库的执行记录、契约检查和联合 E2E 都通过，workspace change 才能完成。用户无需重复启动前端和后端各自的 6 阶段流程。

执行命令：

```text
/workspace-orchestrator start WS-001 <全栈需求>
/workspace-orchestrator run WS-001
/workspace-orchestrator status WS-001
/workspace-orchestrator resume WS-001
```

`run` 是一次编排入口，会按当前状态推进 ①~⑥；遇到需求审批、架构决策、生产发布等人工决策点会暂停。`resume` 用于决策完成或修复后继续。
