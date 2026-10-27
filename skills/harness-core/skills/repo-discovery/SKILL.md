---
name: repo-discovery
description: 多仓库工作空间的仓库发现与能力匹配。扫描独立 Git 仓库，维护 .harness/repo-map.yaml，并把需求映射到需要修改的前端、后端或契约仓库。
---

# Repo Discovery — 多仓库发现与需求路由

当一个业务工作空间包含多个独立 Git 仓库时，先回答两个问题：需求涉及哪些仓库，每个仓库承担什么职责。这个技能只负责发现、匹配和登记，不直接修改业务代码。

## 适用场景

- 前端与后端是两个独立 Git 仓库；
- 一个需求可能同时改动多个服务或一个独立的 API 契约仓库；
- 当前目录本身没有 `.git`，但子目录存在多个 Git 仓库；
- 需要把 AI 的工作范围固定到具体仓库、模块和分支。

## 工作空间约定

从工作空间根目录执行时，维护 `.harness/repo-map.yaml`。工作空间根目录可以不是 Git 仓库，但为了让映射、跨仓变更卡和联合门禁可复现，推荐把它放进一个单独的 workspace/coordinator Git 仓库。工作空间模式只安装协调技能，不安装某一种语言的 Owner 和规则。

仓库内的 `.harness/` 仍是该仓库的规则、技能、变更和本地门禁的事实源；工作空间层只记录编排关系，不复制仓库内规则。

## `repo-map.yaml` 最小格式

```yaml
version: 1
workspace: process-platform
repos:
  - id: frontend
    path: ./process-platform-frontend
    role: frontend
    git_root: ./process-platform-frontend
    harness: .harness
    keywords: [页面, 前端, 交互, 路由]
    contracts:
      consumes: [backend-api]
    gates:
      command: bash .harness/scripts/harness-gate.sh all all
  - id: backend
    path: ./process-platform-backend
    role: backend
    git_root: ./process-platform-backend
    harness: .harness
    keywords: [接口, 服务, 数据库, 后端]
    contracts:
      publishes: [backend-api]
    gates:
      command: bash .harness/scripts/harness-gate.sh all all
contracts:
  - id: backend-api
    source: backend
    path: process-platform-backend/.harness/wiki/接口协议.md
    consumers: [frontend]
coordination:
  change_root: .harness/changes
  local_change_policy: linked
  integration_command: <真实的前后端联调命令>
```

`path`、`git_root`、`source` 和 `integration_command` 必须使用真实值；不能用示例值进入门禁。

## 执行步骤

### 1. 发现仓库

从当前目录向下扫描，识别：

- 当前目录是否是 Git 根；
- 一层或多层子目录中的 `.git`；
- 每个仓库的语言、框架、构建工具和已有 `.harness/`；
- 仓库是否存在未提交变更。

对每个仓库使用等价于以下命令的检查，并记录实际输出：

```bash
git -C <path> rev-parse --show-toplevel
git -C <path> status --short --branch
```

不要把工作空间根目录的 `git diff` 当成所有子仓库的 diff。

### 2. 建立或校验映射

- 没有 `.harness/repo-map.yaml`：根据扫描结果生成初稿，并标记需要人确认的职责、契约和联调命令；
- 已有映射：校验路径、Git 根、职责和 `.harness` 是否存在；
- 路径失效、职责冲突或同一关键词命中多个仓库时，停止自动路由，列出候选项；
- 根目录不是 Git 仓库时，明确声明“工作空间协调层未被版本控制”，并建议使用 coordinator 仓库。

### 3. 把需求映射到仓库

输出一张需求路由表：

| 仓库 | 角色 | 命中原因 | 预计模块 | 是否需要改动 |
|---|---|---|---|---|
| `frontend` | frontend | 需求包含页面交互 | `src/views/...` | 是 |
| `backend` | backend | 需求包含 REST 接口 | `module-*/...` | 是 |

匹配只提供建议。涉及公共 API、数据库、鉴权、发布拓扑或跨仓依赖时，必须把候选仓库全部列出并交给需求阶段确认。

### 4. 输出跨仓工作单

对涉及两个及以上仓库的需求，创建工作空间层变更卡（见 `workspace-change.md`），至少包含：

- workspace change ID；
- 仓库清单与各自 local change ID；
- API/事件/数据库契约的唯一来源；
- 依赖顺序与可并行范围；
- 每个仓库的分支、commit、PR 和门禁状态；
- 联合验证命令及回滚顺序。

## 完成标志

- `.harness/repo-map.yaml` 已生成或校验通过；
- 每个候选仓库都能解析 Git 根和本地 `.harness/`；
- 需求路由到明确的仓库与模块；
- 跨仓需求已创建工作空间变更卡，并关联各仓库的 local change。
