# Harness 实际项目落地使用手册（操作清单）

> 适用对象：要在**真实项目**里把 Harness 规范体系跑起来的使用者。
> 本文提供可执行、可核对的完整清单，包含 hooks 门禁实操与故障排查。
> 每个条目都有「命令 + 预期输出 + 判定标准」；做不到预期就停下来查 5（故障排查）。

---

## 0. 前置条件核对表

| # | 条件 | 检查命令（Windows 用 Git Bash） | 通过标准 |
|---|---|---|---|
| 0.1 | bash（Windows 用 Git Bash） | `bash --version` | 有版本号输出 |
| 0.2 | node（Claude/Codex/Gemini shell hooks 需要） | `node --version` | `v18+`；TS 插件宿主（Cline/OpenCode）不需要 |
| 0.3 | 宿主 AI 工具已装 | `claude --version` / `gemini --version` / `codex --version`（按你用的） | 有版本号 |
| 0.4 | 目标项目是 git 仓库 | `git -C <项目根> status` | 输出正常（hooks 的状态机/凭据扫描依赖 git） |
| 0.5 | skill 包可用 | 你的 AI 工具能列出这个包里的斜杠命令（见 1.1） | `/apply-harness` 能弹出 |

> 检查发现工具缺失的：node 缺失 → hooks 会走脚本内粗解析回退（功能降级，见 5.3）；系统级工具只补装，**不要**让 AI 去改构建配置代偿。

---

## 1. 一次性接入（首次落地，做一次即可）

### 1.1 安装 skill 包

把 `harness-skills` 装进你的 AI 工具（两种方式任选）：

- **Reasonix**：对话里运行 `/install-capability`，指向本仓库（或将其 skills 目录加入 skill 根）。
- **Claude Code / Cursor / Windsurf / Copilot 等**：
  ```bash
  # 在任意项目根目录执行（对应文章的 npx 方式）
  npx skills@latest add git@github.com:weeenc/harness-skills.git
  ```

判定：你的 AI 工具现在能列出 `apply-harness`、`harnessing`、`coding-skill-*` 等命令——**先注册，再开工**，顺序反了后面的流水线全是摆设。

原始技能包选择个人或项目一个安装范围即可。Codex 已有个人安装时不要再向项目复制整包，否则菜单可能同时出现“项目名”和“个人”的同名项。

### 1.2 起手 apply-harness（生成规范骨架）

在**目标项目根目录**的 AI 对话里执行；前后端是独立 Git 仓库时，在协调层执行一次。协调层可以是两者的共同父目录，也可以是与前后端同级的独立 coordinator 仓库：

```
/apply-harness
```

它会检测语言/框架、生成 Owner 与规则、渲染技能、自动注册、初始化变更追踪/知识库/门禁层并输出摘要。全栈模式先生成协调资产，再分别在前后端执行本地初始化，最后统一汇总，无需三次调用。重复执行只补缺，已有定制保留；失败修复后仍从协调层执行同一命令续跑。

> 宿主检测：Claude Code / Gemini CLI / Codex CLI / Cline / OpenCode 五宿主。检测到哪个生成哪个配置（`.claude/settings.json` / `.gemini/settings.json` / `.codex/hooks.json` / `.cline/plugins/` / `.opencode/plugin/`）；未检测到的宿主按技能文本兜底（卡片会注明）。

### 1.3 落地确认清单（3 项，一项都别省）

```bash
# ① 看目录是否落地
ls .harness/
# 预期：agents/ rules/ skills/ changes/ wiki/ CONTEXT.md scripts/ hooks/ gate-config.json 都在
```

上面是单仓检查清单；全栈模式在各子仓分别检查。协调层只检查 repo-map、协调技能、changes 模板及共享报告脚本，不要求语言 Owner、语言规则或业务 hooks。

```bash
# ② 确认摘要中列出的实际技能入口可用
# 全栈使用 workspace-orchestrator；单仓使用 harnessing-java / harnessing-front 等
# 仅注册未完成或拉取已有项目后需要注册时，才执行：
/install-skill
```

```bash
# ③ 确认 hooks 已生效（见 1.5 的连通性自测）
```

### 1.4 门禁依赖体检（install 后必做一次）

```bash
bash .harness/scripts/bootstrap-tools.sh check all
```

预期输出三类结果与退出码：

| 输出 | 退出码 | 含义 | 下一步 |
|---|---|---|---|
| 全 `[OK]` | 0 | 依赖就绪，门禁可真实执行 | 直接进 1.5 |
| `[MISS]` | 1 | 可自动安装的独立工具缺失 | `bash .harness/scripts/bootstrap-tools.sh install all` 自动装，再 check |
| `[GUIDE]` | 2 | **项目内组件未声明**（如 Maven 缺 PMD 插件/p3c-pmd 规则或 jacoco 插件、缺 assertj/actuator 依赖） | 按输出指引**人工合入** `pom.xml` / `build.gradle` / `package.json`（门禁脚本绝不自动改写构建配置——那是规范流程范畴） |

> 举例：Java + Maven 项目，pom.xml 没配 PMD 插件或 p3c-pmd 规则 → `[GUIDE] …未在 pom.xml 中声明→ 请人工合入`，此时 `check-style` 门禁会输出 `[DEGRADED]` 并以退出码 2 显式降级，**不会**把 `mvn pmd:check` 的 BUILD FAILURE 误判成风格违规。

### 1.5 hooks 连通性自测（30 秒，做一次知道门禁是真拦还是摆设）

```bash
# ① 造一个进行中的变更卡（须含 status: coding，否则 hooks 判定为「无活动 change」，Stop 全量不会跑）
CH=$(date +%s); mkdir -p ".harness/changes/demo-$CH"; printf 'id: demo-%s\nstatus: coding\n' "$CH" > ".harness/changes/demo-$CH/change.md"
# 或直接用 /harnessing 建卡

# ② 改一个源码文件，回复 AI，看它的输出里是否出现 [门禁·增量] / [门禁·出口] 字样
```

```bash
# ③ 直接验证配置区守卫（不看 AI，手动跑 hook）：
printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":".harness/scripts/check-style.sh"}}' | bash .harness/hooks/pre-tool-use.sh
# 预期（首次）：生成 .harness/clone/ 快照 + decision:"allow"（与快照一致）

# ④ 篡改后应该被拦：
echo 'echo hacked' >> .harness/scripts/check-style.sh
printf '{"tool_name":"Write","tool_input":{"file_path":".harness/scripts/check-style.sh"}}' | bash .harness/hooks/pre-tool-use.sh
# 预期：decision:"block"（Claude/Codex）/ "deny"（Gemini）
# ⑤ 篡改的文件恢复原样（git checkout 或 git restore）
```

判定：③④符合预期 → hooks 生效；④ 没拦 → 查 5.1（hook 配置没加载）。

---

## 2. 日常开发（每个需求走一遍）

### 2.1 起手：一句话需求建卡

```
/harnessing  <需求一句话>
```

生成 `.harness/changes/<id>/`（change.md 规格卡），状态进入 `draft → analyzing`。需求卡审批通过后进入 `coding`。

### 2.2 六阶段推进（状态机 `draft→analyzing→coding→testing→reviewing→ci→verifying→done`）

| 阶段 | 技能 | 出口门禁（Gate） | 不通过怎么办 |
|---|---|---|---|
| ① 规格构建 | `harnessing` | 需求卡 + 验收标准确认 | Owner Agent 提示"请审批"，不擅自进 coding |
| ② 编码实现 | `coding-skill-<lang>` | 失败测试先存在并转绿、构建/lint 通过 + 符合编码规范 | 退回修复或请示人类 |
| ③ 测试完善 | `unit-test-write-<lang>` | 核心逻辑覆盖率 ≥80%，覆盖 AC 与边界 | 补测试 |
| ④ 专家评审 | `expert-reviewer-<lang>` | Spec 需求匹配 + Standards 规范合规，0 个严重问题才放行 | 按评审意见修复 |
| ⑤ CI 门禁 | `unit-test-ci-<lang>` | 静态分析 + 架构约束 + 全量测试 全绿 | 修复直至全绿 |
| ⑥ 部署验证 | `deploy-verify-<lang>` | 部署后冒烟 + 健康检查 + 关键链路验证 | 回滚或修复重发 |

> 门禁原则：任一 Gate 不通过 → 退回修复或请示人类，**禁止进入下一阶段**。
> 状态推进责任：`coding→testing`、`testing→reviewing`、`reviewing→ci` 由 Owner Agent 在对应产物完成时推进；**需求审批（analyzing→coding）和重大取舍必须请示人类**（见 `开发流程规范.md` §4）。

### 2.3 hooks 在过程中自动做什么（你不用敲，但要能读懂它们的信号）

| 挂点 | 宿主触发点 | 自动动作 | AI 输出里的记号 |
|---|---|---|---|
| PreToolUse（写文件前） | Claude/Codex/Gemini/Cline/OpenCode | 配置区守卫（直改 block/deny/throw）+ 状态机防呆提示 | `[门禁] 目标 …属配置区…` / `[门禁·状态机]` |
| PostToolUse（写文件后） | Claude/Codex/Gemini/Cline(afterRun) | **单文件增量深度检测**（本次写改文件 lint/风格） | `[门禁·增量]` / `[门禁·增量·红灯]` |
| Stop（每个回复结束） | Claude/Codex | **出口全量深度检测**（有活动 change 且本轮有源码变更时）+ 证据落盘 | `[门禁·出口]` 汇总（rc=0 通过 / 1 红灯 / 2 降级） |
| SessionEnd（会话结束） | Gemini / OpenCode(session.idle) | 同上出口全量 + 证据落盘 | `[门禁·出口]` |

信号语义：**红灯（rc=1）必须修复后再继续**；**降级（rc=2）= 工具没装齐，先人工核对再继续**，都不是可以无视的噪音。

### 2.4 门禁证据去哪看

新需求使用 compact 两文件协议（[变更管理](change-management.md)）；wiki、tech、rules 等维持原逻辑。机器摘要在运行区，人工确认写持久报告，不能仅引用本地日志。

```bash
cat .harness/changes/<id>/report.md   # 六阶段结论；全栈读 report_ref 指向的报告
/harness-status               # 当前所有变更进度与待办聚合
cat .harness/changes/.runtime/<id>/gate-coverage.md   # 最新本地摘要（含 rc 与时间）
```

### 2.5 严格模式（可选，建议 CI/核心仓开启）

在宿主环境变量设 `GATE_STRICT=1`：无流程中 change 却写源码 → PreToolUse 直接 `block`（默认只提示不阻断）。开启后，`/harnessing` 建卡不再是可选动作。

---

## 3. 发布与收口

### 3.1 出口门禁

1. 阶段 ⑤ `unit-test-ci-<lang>` 全绿（静态分析 + 架构约束 + 全量测试）；
2. Stop/SessionEnd 出口全量 `[门禁·出口]` 无红灯、无降级；
3. `reviewing → ci → verifying → done` 推进完成。

### 3.2 证据留档（收口后一次性）

| 动作 | 命令 | 产出 |
|---|---|---|
| 迭代复盘 | `/harness-retro` | 历史留档 + 趋势报告 |
| 变更日志 | `/harness-changelog` | 带 change ID 的可追溯条目 |
| 发布 | `/harness-ship` | 版本 / tag / CI-CD（不可逆操作留人） |

### 3.3 提交 git（哪些要进版本库）

```bash
git add --ignore-missing \
  .harness/agents/ .harness/rules/ .harness/skills/ .harness/wiki/ .harness/CONTEXT.md \
  .harness/changes/ .harness/scripts/ .harness/hooks/ .harness/gate-config.json \
  .claude .gemini .codex .cline .opencode
# .harness/clone/ 是运行时快照（自动自举补给），建议加入 .gitignore 而不是提交：
echo '.harness/clone/' >> .gitignore
```

> 说明：`.harness/clone/` 由 hook 首次运行自动复制生成，提交会与现网配置漂移；changes 下的卡片与六阶段 report.md 建议提交，`.runtime/` 由 changes/.gitignore 忽略；原始输出不逐次进入 Git，阶段报告保留关键证据，历史 legacy 报告不自动删除。宿主配置（`.claude/settings.json` 等）是团队共享的门禁挂点，建议提交。

---

## 4. 配置 / 规则变更（别直改，走正道）

配置区 = `.harness/{hooks,scripts,rules}` + `.harness/gate-config.json` + `.harness/动态事实来源.md`。
**任何宿主都会拦截直改**（PreToolUse block / Gemini deny / Cline·OpenCode throw），这是设计，不是 bug。

| 变更类型 | 正道 | 说明 |
|---|---|---|
| 改门禁/规则内容 | `/harness-standard` | 规范库管理流程（新增/修订/归档，重大约束留人审批），不建 `.applying` 标记 |
| 重新生成整套规范 | `/apply-harness` | 流程开始自动挂 `.harness/.applying` 豁免标记 → 配置区写入放行并**增量同步克隆区基线** → 流程结束删除标记 |
| 基线被旧快照卡住 | `rm -rf .harness/clone/` | 下次对配置区的写入会触发 hook 自举复制，重建基线 |

> `.applying` 标记只应存在于 apply-harness 执行期间；**异常出现（非规范流程）时手动删掉即恢复守卫**（hook 不自动清理）。

---

## 5. 故障排查速查表

| 症状 | 可能原因 | 排查/修复 |
|---|---|---|
| 5.1 改动源码，AI 输出里从没有 `[门禁·增量]` | hook 没加载：`settings.json` 合并失败 / 路径错 | ① 看 `.claude/settings.json` 是否含本模板的 matcher 条目；② 从 `.harness/hooks/pre-tool-use.sh` 手动跑（见 1.5③）验证脚本本身 OK；③ 检查配置文件位置（`.claude/settings.json` 或 `~/.codex/hooks.json` 按宿主） |
| 5.2 配置区写入提示"与规范快照一致"但你没改过 | 无关紧要——重复写相同内容被放行+提示 | 无需处理 |
| 5.3 node 缺失，hooks 无输出 | 脚本内 node 解析失败静默回退 | 手动跑一遍 1.5③看输出；或 `bash .harness/hooks/post-tool-use.sh` 等回路看是否落到回退分支；补装 node 最稳 |
| 5.4 `.harness/.applying` 残留 | apply-harness 中断未清理 | `rm -f .harness/.applying`，恢复守卫 |
| 5.5 合法流程被误拦"与快照不一致" | 配置先被手改过，克隆区快照是旧的 | 确认你的改动确实走规范流程后，`rm -rf .harness/clone/`（下次写配置区时自举重建快照） |
| 5.6 GATE_STRICT 开启后写源码被 block 且提示建卡 | 没有活动 change | 按提示 `/harnessing` 建卡；Hotfix/Spike/纯文档裁剪在 change.md 显式记录该直改 |
| 5.7 Windows 下 hook 命令找不到 | Git Bash 未在 PATH | 用 Git Bash 启动宿主工具；hooks 脚本由 bash 调用不需要 chmod +x |

---

## 6. 卸载（完整移除）

```bash
# ① 删宿主触发配置（按检测到的宿主）
rm -f .claude/settings.json .gemini/settings.json .codex/hooks.json   # 只删本模板追加的条目也行
rm -rf .cline/plugins/harness-plugin.ts .opencode/plugin/harness.ts
# ② 删 .harness 骨架与运行时
rm -rf .harness/
# ③ 技能包从 AI 工具移除（install-capability 的反向操作 / npx skills remove）
```

---

## 7. 命令速查总表

| 目的 | 命令 |
|---|---|
| 安装包 | `npx skills@latest add git@github.com:weeenc/harness-skills.git`（或 `/install-capability`） |
| 生成规范 | `/apply-harness` |
| 建需求卡 | `/harnessing <需求>` |
| 依赖体检 | `bash .harness/scripts/bootstrap-tools.sh check all` |
| 自动装工具 | `bash .harness/scripts/bootstrap-tools.sh install all` |
| 手动跑任一门禁 | `bash .harness/scripts/harness-gate.sh <gate> [file\|all] [change-id]`（gate: check-style/static-analysis/coverage/arch-check/security-scan） |
| 进度总览 | `/harness-status` |
| 改动配置/规则 | `/harness-standard` |
| 证据落盘位置 | `.harness/changes/.runtime/<id>/gate-*.md`（最新摘要）；持久结论在 report.md |
| hooks 自测 | 见 1.5 ③④ |

## 8. 相关文档

- **原理文档（每个脚本一篇）**：[docs/harness-principles/00-overview.md](harness-principles/00-overview.md)
  —— 门禁如何触发/检测/出结果/报错，逐脚本拆解，与实现逐行可对账。
- **本文档（怎么用）** 与 **原理文档（为什么这样）** 配套阅读：遇到"为什么这个 hook 会 block
  / rc=2 是什么 / 配置区为什么不能直改"类问题，先查原理文档对应章节。
