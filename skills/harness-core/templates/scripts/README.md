# 确定性门禁层 — `.harness/scripts/`

> 本目录是 `rules/开发流程规范.md §1.1` 三层结构中「门禁」层的**实现物**：
> 确定性执行脚本（工作区校验 / 深度检测 / 证据落盘 / 发布门禁）。
>
> 门禁原则：**能机器验证的绝不靠自觉；工具未安装的显式降级，绝不静默跳过。**

---

## 调用方式

- **总入口**：`.harness/scripts/harness-gate.sh <gate> [file|all] [change-id]`
  - `gate`：`check-style` | `static-analysis` | `coverage` | `arch-check` | `security-scan`
  - `[file|all]`：单文件增量检测 或 全量深度检测（缺省 `all`）
  - `[change-id]`：证据落盘目标（缺省自动选中状态机匹配的 change）
- **证据落盘**：`.harness/scripts/report.sh <gate> [change-id]`
- **宿主 hooks 触发器**：`.harness/hooks/`（Claude Code 等宿主工具自动调用本层脚本，见 hooks/README.md）

## 退出码约定（hooks 与技能都依赖）

| 退出码 | 含义 | hooks / 技能处理 |
|--------|------|------------------|
| `0` | 通过 | 注入绿色摘要 |
| `1` | 检测到违规（红灯） | 注入红灯摘要，AI 必须修复后才能继续 |
| `2` | 工具未安装 | **显式降级「人工核对」**，落痕，不阻断（可被审计） |
| `3` | 用法错误 | 报错并提示正确用法 |

## 降级纪律（解决"工具没装门禁就消失"的问题）

任何检测命令在环境中不可用时，脚本必须：

1. 输出 `[DEGRADED] <gate> 工具未安装（<tool>），该门禁降级人工核对（依据：<规则文件>）`；
2. 以退出码 `2` 返回（不算红灯，也不算通过——是"显式降级"）；
3. 把降级事实写入 `.harness/changes/<id>/gate-<gate>.md`，供 `harness-status` / `harness-retro` 审计。

> 严禁：命令找不到时 `|| true` 静默吞掉、假装通过。

## 依赖就绪 — `bootstrap-tools.sh [check|install] [gate]`

门禁命令（如 `mvn checkstyle:check`）能执行的前提是**底层依赖就绪**。注意边界——**脚本不安装 Maven/Gradle 插件，也不改写任何构建配置**，只做三件事：

| 类别 | 是什么 | 脚本行为 |
|------|--------|----------|
| `runners` | 构建/运行器（`mvn`/`./gradlew`/`npm`/`go`/`python`/`pip`/`cargo`/`composer`） | 检测可用性；缺失给手动安装指引（不动系统工具链） |
| `tools` | 可自动安装的独立工具（`npm install -D` / `pip install` / `go install` / `rustup component add` 类） | `check` 检出缺失；`install` 模式自动执行安装命令 |
| `project` | 项目内【声明】组件（Maven/Gradle 插件 checkstyle/jacoco/pmd/spotbugs、库 assertj/actuator、package.json devDependencies） | 只探测构建文件里的声明 + 输出合入指引；**绝不自动改写 pom.xml / build.gradle / package.json** |

- 用法：`bash .harness/scripts/bootstrap-tools.sh check all`（体检）→ 有 `[MISS]` 跑 `install all`（自动装 tools 类）→ 有 `[GUIDE]` 按指引**人工合入项目构建配置**（属于 `harness-standard` 规范流程范畴）后重检。
- `gate` 参数（`all|lint|vet|cov|arch|sec`）按门禁过滤依赖，各 gate 脚本启动时自动预检：底层依赖未就绪 → 输出 `[DEGRADED]` + 指引并退出码 `2`，**绝不把「缺插件/缺库」误判成「违规」**（例如 pom 未配 checkstyle 插件时 `mvn checkstyle:check` 会 BUILD FAILURE，那是配置缺失，不是风格违规）。
- 退出码：`0`=就绪，`1`=有缺失（可自动/手动安装修复），`2`=有待人工合入的项目组件（该 gate 无法真实执行，应显式降级）；缺失与待合入**并存**时返回 `1`（缺失更紧急，先装工具再合配置）。

## 分层检测策略（hooks 与技能共用）

| 触发点 | 检测 | 深度 | 速度 |
|--------|------|------|------|
| PostToolUse（每次写文件后） | `check-style.sh <file>` 增量单文件 | 快速内置检查（行数/尾随空白/TODO/凭据） | 快（<2s） |
| Stop / 技能出口 | `harness-gate.sh check-style all` + `static-analysis` + `security-scan` | 全量深度（`{{LINT_CMD}}`/`{{VET_CMD}}`） | 中 |
| ⑤ `unit-test-ci` 门禁 | 全部 gate 全量 | 最全（含 `coverage` / `arch-check`） | 慢（阶段出口跑） |
