---
name: git-branch-and-commit
scope: all repositories
version: 1.1.0
updated: 2026-11-10
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
