---
name: git-branch-and-commit
scope: all repositories
version: 1.2.0
updated: 2026-11-12
status: active
---

# Git 分支与提交规范

> **作用域**: 所有使用 Harness 的代码仓库。
> **状态**: 强制。分支创建和 commit message 必须符合本规范。

## 1. 分支命名

工作分支统一使用以下前缀，并按 `<prefix>/<short-description>` 命名：

| 前缀 | 用途 |
|---|---|
| `feature/*` | 新功能开发 |
| `bugfix/*` | 普通 Bug 修复 |
| `hotfix/*` | 生产环境紧急修复 |
| `release/*` | 版本发布准备 |
| `refactor/*` | 代码重构 |
| `docs/*` | 文档修改 |
| `test/*` | 测试相关修改 |
| `chore/*` | 工程配置、依赖和其他维护 |

分支名中的描述部分一般使用小写字母、数字和短横线，保持简短并能说明目的；`release/*` 可使用带点号的 SemVer 版本号。例如：

```text
feature/user-login
bugfix/order-timeout
hotfix/payment-callback
release/v1.4.0
refactor/auth-module
docs/git-conventions
test/order-service
chore/upgrade-dependencies
```

只允许使用上表中的前缀。禁止创建以 `codex/`、`claude/`、`cursor/`、`copilot/`、`gemini/`、`ai/` 等 AI 工具、代理或执行环境名称开头的分支；任何未列入上表的前缀都视为不合规。`main`、`master`、`develop` 等受保护分支不作为日常开发分支创建。

## 2. Commit message

Commit message 的首行必须符合以下格式：

```text
<type>(<scope>): <subject>
```

- `type` 必须从下表选择。
- `scope` 使用受影响的模块、领域或组件名称，保持简短；没有合理 scope 时使用仓库约定的统一 scope。
- `subject` 必须使用简洁、明确的中文描述，以动词说明变更，不以句号结尾；允许保留 API、类名、版本号等技术标识，禁止纯英文描述。`type` 保留英文标准值，`scope` 可以使用模块英文名。
- 一个 commit 只表达一个逻辑变更，避免把功能、重构和格式调整混在一起。

| Type | 含义 | 使用场景 |
|---|---|---|
| `feat` | 新功能 | 新增业务功能 |
| `fix` | Bug 修复 | 修复程序缺陷 |
| `docs` | 文档 | 修改 README、接口或其他文档 |
| `style` | 代码格式 | 格式调整，不影响逻辑 |
| `refactor` | 重构 | 优化代码结构，不改变功能 |
| `perf` | 性能优化 | 提升系统运行性能 |
| `test` | 测试 | 新增或修改测试代码 |
| `build` | 构建 | 修改构建配置或构建脚本 |
| `ci` | 持续集成 | 修改 CI/CD 配置 |
| `chore` | 其他维护 | 依赖升级、工具配置等维护工作 |
| `revert` | 回滚 | 撤销之前的提交 |

示例：

```text
feat(route): C-012 新增预算告警阈值
fix(order): C-012 修复重复回调处理
docs(api): C-012 更新认证接口示例
style(web): C-012 格式化请求组件
refactor(auth): C-012 提取令牌校验服务
perf(query): C-012 优化订单查询索引
test(budget): C-012 补充离线估算降级测试
build(deps): C-012 升级框架版本
ci(checks): C-012 增加合并请求静态检查
chore(tooling): C-012 更新开发脚本
revert(api): C-012 回滚不兼容的响应变更
```

如果仓库使用 `.harness/changes/`，commit message 必须包含对应的变更 ID（如 `C-012`）；推荐将它放在 subject 中，也可以放在 commit body 或 footer。这样既保持 `<type>(<scope>): <subject>` 格式，又能与变更卡追踪。

## 变更编号与卡片关联

- `C-*` 是仓库级变更 ID，`WS-*` 是协调仓工作空间变更 ID；两者独立分配，不要求数字相同。同一需求的实现、测试、修复、合并提交复用原卡 ID；无关需求必须新建卡片，不能按提交次数递增或复用他人的编号。
- 新建前先搜索已有卡片和需求，确认是否属于已有变更。新需求统一执行 `python3 .harness/scripts/new-change.py --prefix C --title "需求标题"`；协调仓跨仓需求使用 `--prefix WS`。子仓可加 `--workspace-card <协调仓卡片路径>` 自动写入关联，再由协调仓登记 `repos[].local_change`。
- 分配器取本仓已有卡片、分支卡片、所有本地可见 refs 的提交信息和本机已预留序号的最大值加一；至少三位补零。使用 Git 公共目录锁防止同机 worktree 并发撞号；失败可留空号，禁止回收。远端或不同克隆之间不共享锁，协作前须同步 refs，合并时复核同 ID 是否对应同一需求，必要时重编号并同步引用。
- 使用变更卡管理时，提交信息中第一个 `C-*` 或 `WS-*` 是本次主变更 ID，必须对应本仓 `.harness/changes/<ID>/change.md`（C）或 `workspace-change.md`（WS），目录名与 frontmatter 的唯一 `id` 必须完全一致。正文之后的其他编号仅作为历史关联，例如回滚目标；不会代替主卡。子仓以本地 C 卡为主 ID，跨仓 WS 关系写入卡片。
- 填好卡片后先 `git add`。提交前校验与 commit-msg 读取暂存区；CI 读取每条提交自身的树。仅存在于工作目录、提交后补建、目录和 ID 不一致的卡片不能通过。存在性校验不判断需求语义，评审仍须核对改动是否属于主卡，不能拿任意现有卡凑数。
- `.harness/change-card-policy-base` 是首次启用卡片检查时固定的历史兼容基点；它的祖先提交只运行原格式检查，其余提交必须有卡。原 `.harness/commit-policy-base` 保持不变；禁止移动任一基点绕过检查。空仓使用 `ROOT`，从首条提交校验。不为历史无卡编号补造需求，不改写历史提交。

旧项目的带后缀卡片目录（例如 `C-001-example`）不会自动迁移。新卡统一使用纯编号目录；继续修改旧需求前，先按授权范围对齐其目录、frontmatter ID 和引用，再提交。编号分配时仍预留这些旧目录的数字。未采用 `.harness/changes/` 的项目可省略编号；已采用的项目不能通过删除卡片目录让当前提交免检。

## 3. 执行与校验

- 每次提交前读取本规范；入口见仓库根目录 `AGENTS.md`。
- 新克隆执行 `python3 .harness/scripts/install-commit-policy.py`，启用 `commit-msg`。
- 提交前执行 `python3 .harness/scripts/check-commit-message.py --message-file <文件>`；提交后及 CI 执行 `sh .harness/scripts/ci-commit-check.sh`。
- 机器检查格式、subject 包含中文、不以句号结尾、使用 `.harness/changes/` 时的变更 ID；描述的中文语义与准确性仍由评审确认。
- merge、revert、squash 等提交同样适用，必须改写默认英文标题，不允许绕过校验。
- 范围检查从 `.harness/commit-policy-base` 之后生效，不追溯修改历史提交；基线不得为规避违规而移动。CI 接入说明见 `../scripts/commit-policy.md`。

## 修订记录

| 日期 | 变更摘要 | 审批人 |
|---|---|---|
| 2026-11-05 | 新增 Git 分支命名和 commit message 规范，禁止 AI 工具前缀分支 | 需求提出者（用户） |
| 2026-11-10 | 统一中文示例、提交入口及本地/CI 校验，版本升级为 1.1.0 | 用户明确要求修正三个方面 |

| 2026-11-12 | 同步变更编号分配、主卡校验与历史兼容基点 | 用户要求同步优化 harness-skills |
