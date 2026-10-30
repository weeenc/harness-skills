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

从工作空间协调层执行时，维护 `.harness/repo-map.yaml`。协调层可以是前后端仓库的共同父目录，也可以是与前后端仓库同级的独立 `coordinator/` 仓库。后者使用协调层目录作为映射根，仓库路径以 `../<repo-dir>` 这类相对路径登记，目录名不承担前端或后端职责。协调层可以没有 Git；为了让映射、跨仓变更卡和联合门禁可复现，仍推荐把它放进单独的 workspace/coordinator Git 仓库。工作空间模式只安装协调技能，不安装某一种语言的 Owner 和规则。

仓库内的 `.harness/` 仍是该仓库的规则、技能、变更和本地门禁的事实源；工作空间层只记录编排关系，不复制仓库内规则。

由 `apply-harness` 初始化调用时，只执行下文 1~2 的发现与登记，返回仓库表供同一次调用继续逐仓初始化；不要求用户再次执行技能，也不执行 3~4 的需求路由和建卡。新仓库尚无 `.harness/` 记为待初始化，不作为发现失败；初始化模式的完成标志是路径与 Git 根已核验、映射已登记，业务契约与联调命令可暂列待配置。

## `repo-map.yaml` 最小格式

```yaml
version: 1
workspace: demo
repos:
  - id: web
    path: ./web-console
    role: frontend
    git_root: ./web-console
    harness: .harness
    keywords: [页面, 前端, 交互, 路由]
    contracts:
      consumes: [service-api]
    gates:
      command: bash .harness/scripts/harness-gate.sh all all
  - id: service
    path: ./order-service
    role: backend
    git_root: ./order-service
    harness: .harness
    keywords: [接口, 服务, 数据库, 后端]
    contracts:
      publishes: [service-api]
    gates:
      command: bash .harness/scripts/harness-gate.sh all all
contracts:
  - id: service-api
    source: service
    path: order-service/.harness/wiki/接口协议.md
    consumers: [web]
coordination:
  change_root: .harness/changes
  local_change_policy: linked
  integration_command: <真实的前后端联调命令>
```

`path`、`git_root`、`source` 和 `integration_command` 必须使用真实值；不能用示例值进入门禁。

## 执行步骤

### 1. 发现仓库

从当前目录扫描，识别：

- 当前目录是否是 Git 根；
- 当前目录一层或必要的业务子目录中的 `.git` 目录或文件（支持 worktree/submodule）；
- 如果当前目录被识别为独立协调层（已有 `.harness/repo-map.yaml`、用户明确说明这是 coordinator，或当前目录缺少业务语言入口且共同父目录下存在可识别的独立业务 Git 仓库），再检查其共同父目录下的**直接兄弟目录**。兄弟仓库只按明确映射、用户指定或项目技术特征纳入；目录名不用于推断职责。不向父目录的上级递归，不遍历符号链接；
- 跳过依赖、构建产物和技能缓存；发现独立仓库后不继续把它的普通子目录算作另一个仓库；
- 每个仓库的语言、框架、构建工具和已有 `.harness/`；
- 仓库是否存在未提交变更。

对每个仓库使用等价于以下命令的检查，并记录实际输出。对于同级布局，`<path>` 使用相对协调层的真实仓库目录，例如 `../<repo-dir-a>` 或 `../<repo-dir-b>`：

```bash
git -C <path> rev-parse --show-toplevel
git -C <path> status --short --branch
```

不要把工作空间根目录的 `git diff` 当成所有子仓库的 diff。

### 2. 建立或校验映射

- 没有 `.harness/repo-map.yaml`：根据扫描结果生成初稿，并标记需要人确认的职责、契约和联调命令；同级布局的仓库路径必须以协调层为基准写入，例如 `../<ui-repo-dir>`、`../<service-repo-dir>`；
- 已有映射：校验路径、Git 根、职责和 `.harness` 是否存在；
- 更新时保留既有仓库 id、契约、门禁及自定义字段，只合并已核实的新信息；
- 路径失效、职责冲突或同一关键词命中多个仓库时，停止自动路由，列出候选项；
- 如果无法唯一确定前端仓库、后端仓库或契约仓库，或者同级候选过多，必须先向用户列出候选绝对路径并询问职责/纳入范围，不根据目录名猜测，也不把所有兄弟仓库全部加入；
- 根目录不是 Git 仓库时，明确声明“工作空间协调层未被版本控制”，并建议使用 coordinator 仓库。

### 3. 把需求映射到仓库

输出一张需求路由表：

| 仓库 | 角色 | 命中原因 | 预计模块 | 是否需要改动 |
|---|---|---|---|---|
| `web` | frontend | 需求包含页面交互 | `src/views/...` | 是 |
| `service` | backend | 需求包含 REST 接口 | `module-*/...` | 是 |

匹配只提供建议。涉及公共 API、数据库、鉴权、发布拓扑或跨仓依赖时，必须把候选仓库全部列出并交给需求阶段确认。

### 4. 输出跨仓工作单

对涉及两个及以上仓库的需求，仅实例化工作空间层变更卡（artifact_mode: compact，见 `workspace-change.md`），阶段结论汇总到同目录 report.md；子仓执行卡以 report_ref 关联，不复制另一套阶段文档。卡片至少包含：

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
