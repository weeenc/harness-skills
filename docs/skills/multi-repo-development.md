# 独立 Git 仓库的全栈开发支持

前端和后端保持两个独立 Git 仓库，各自拥有 `.harness/agents/owner.md`、规则、skills、changes、脚本和 hooks。协调层负责仓库映射、跨仓需求和联合验证，可以是前后端的共同父目录，也可以是与前后端同级的独立 coordinator 仓库。

推荐采用三层结构，并在 workspace change 中设置 `pipeline_mode: workspace_once`：

```text
workspace coordinator（建议独立 Git 仓库，也可先用普通文件夹）
├── .harness/repo-map.yaml
├── .harness/skills/common/（协调技能）
├── .harness/changes/（模板；有需求后创建 WS-*）
├── contracts/ 或契约仓库引用
├── scripts/workspace-gate.sh（真实联调命令确定后生成）
├── web-console/（独立 Git 仓库，示例名称）
│   └── .harness/
└── order-service/（独立 Git 仓库，示例名称）
    └── .harness/
```

如果协调层仓库需要与前后端包保持同级，可以使用以下布局：

```text
workspace/
├── coordinator/（独立协调仓库）
│   └── .harness/repo-map.yaml
├── web-console/（独立 Git 仓库，示例名称）
│   └── .harness/
└── order-service/（独立 Git 仓库，示例名称）
    └── .harness/
```

从 `coordinator/` 执行 `/apply-harness` 时，发现流程会检查共同父目录下的直接兄弟仓库，并在 `coordinator/.harness/repo-map.yaml` 中写入以协调层为基准的相对路径。`web-console`、`order-service` 只是示例名称；实际仓库目录名可以完全不同。其他兄弟项目不会因为处于同一父目录而自动加入；如果候选过多或职责无法判断，会先询问用户确认。

对应的最小映射如下：

```yaml
version: 1
workspace: demo
repos:
  - id: frontend
    path: ../web-console
    git_root: ../web-console
    role: frontend
    harness: .harness
  - id: backend
    path: ../order-service
    git_root: ../order-service
    role: backend
    harness: .harness
coordination:
  change_root: .harness/changes
  local_change_policy: linked
```

工作空间协调仓库可以通过 Git submodule 固定前后端 commit，也可以只维护 clone 路径和 commit 清单。前者复现性更强；后者适合现有目录已经是两个独立仓库的情况，但必须把 commit SHA 写进 workspace change。

## 一次初始化三个层级

在协调层打开 AI 对话，执行一次：

```text
/apply-harness
```

工具会发现前后端 Git 根、分别检测技术栈、检查已有 Harness，生成协调层资产，再逐仓初始化和注册，最后给出一张汇总表。前端、后端和协调层不需要分别调用三次。只有职责或技术栈无法确定时才需要补充信息。

已有项目重复执行时，相同内容跳过、缺失项补齐、本地定制保留，需要替换的文件列出差异。某仓失败后修正原因，再在协调层执行同一命令即可继续；已成功的兄弟仓库不会重建。

协调层暂时没有 Git 也可完成初始化；需要提交协调资产前再建立版本控制。接口契约或联调命令尚不明确时保留待配置项，不能用示例命令宣称联合验证通过。

Codex 的注册按实际可见范围去重：同内容的个人技能可复用，语言技能使用 `*-front`、`*-java` 等渲染名称；协调层按路径调度子仓技能。直接打开子仓也要检查入口可用，不能依赖跨 Git 根继承。原始包同时装在项目和个人范围造成的历史重复会单独报告，不自动删除。

## 与参考项目的对应关系

参考项目已经验证了“每仓库独立 Harness”的可行性：前端与后端各自生成 `.harness/`，各自运行本地 lint、测试、评审和 CI。这一层应保留。

需要补上的能力是：

- 工作空间仓库地图：明确各业务仓库的路径、职责、契约和联调入口；
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

1. 安装一次技能包，选择个人或项目范围，避免同一套包在两个范围重复安装。
2. 在协调层目录执行一次 `apply-harness`。协调层是共同父目录时扫描子目录；协调层与前后端同级时扫描共同父目录下的直接兄弟仓库，查看协调层与各子仓的初始化、注册和门禁状态。
3. 补齐汇总中未确定的契约来源和联调入口；需要提交协调资产时建立 coordinator Git 仓库。
4. 用 `workspace-orchestrator start` 发起全栈需求，前端 mock 与后端契约引用同一版本。
5. 在 CI 中按“契约检查 → 前端/后端本地门禁 → 联合 E2E → 发布对账”执行。

新需求默认 artifact_mode: compact：协调层只保留 workspace-change.md + 六阶段 report.md，子仓各一份执行卡；review-check 读取共享报告，不复制子仓 review.md。临时输出放 changes/.runtime/，不按每次运行保存两仓完整 diff。详见 [变更管理](../change-management.md)。
