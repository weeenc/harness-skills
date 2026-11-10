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

`start` 只执行①需求分析，创建或更新协调层的 `workspace-change.md`、`report.md` 和子仓执行卡；完成后保持 `analyzing` / `harnessing`，报告标记“等待实施授权”，②~⑥保持未执行。此时不能修改业务代码、测试、可执行契约、mock、生成客户端或实施配置，也不能调度子仓编码。

只有用户明确确认对该变更开始实施，或实际执行 `run WS-001`，才允许进入②。确认需求事实、回答分析问题、没有未决问题或报告中列出的建议命令都不等于实施授权。授权来源、用户原话或命令及范围写入报告①，供后续推进和子仓执行核对。

`run` 从当前状态推进流水线；遇到未解决的需求审批、架构决策、生产发布等人工决策点会暂停。`resume` 用于已有实施授权范围内的决策完成或修复后继续，不能绕过首次实施授权。`status` 只查询，不触发实施。一次工作空间授权覆盖对应范围内的各仓库，不要求重复审批。
