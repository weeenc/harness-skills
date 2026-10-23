# 门禁体系原理总览（00）

> 本目录逐文件拆解 `.harness/` 门禁层：**每个脚本一篇原理文档**，讲清楚——
> 用途 / 运行原理 / 如何被调用（含 hook 触发链）/ 如何检测与出结果 / 结果不满足时如何报错。
> 入口：`docs/harness-usage.md`（怎么用）；本目录（为什么这样，逐行对得上实现）。

## 一、分层模型：三层，一层只管一件事

```
┌─ 宿主层（触发配置）─────────────────────────────────────────────┐
│ .claude/settings.json   .gemini/settings.json   .codex/hooks.json │
│ .cline/plugins/harness-plugin.ts  .opencode/plugins/harness.ts      │
│ 职责：把宿主工具事件（write/stop/会话结束…）映射到 hooks 命令       │
├─ hooks 层（触发器 + 守卫）────────────────────────────────────────┤
│ .harness/hooks/pre-tool-use.sh   post-tool-use.sh   stop.sh         │
│ .harness/hooks/gemini/{before,after,session-end}-tool.sh           │
│ 职责：解析宿主事件 JSON → 决定「放行/阻断/提示」→ 调 scripts 检测   │
├─ scripts 层（确定性检测，唯一的事实来源）────────────────────────┤
│ .harness/scripts/harness-gate.sh（总入口，参数转发）                │
│ check-style / static-analysis / coverage / arch-check /             │
│ security-scan / bootstrap-tools / report                            │
│ 职责：跑真实检测命令 → 归一退出码 → 证据落盘，与宿主无关            │
└───────────────────────────────────────────────────────────────────┘
```

关键原则：**检测逻辑全部收敛在 scripts 层（一处实现），hooks 只是触发器**。
宿主差异（事件名、JSON 字段、回执协议）只体现在 hooks 层与宿主配置，scripts 层不认识任何宿主。

## 二、调用链：一次写文件，从事件到证据的全过程

以 Claude Code 写 `src/App.java` 为例（其余宿主事件名见各宿主文档）：

```
1. 生成期    apply-harness 把 settings.json.tpl 渲染为 .claude/settings.json
             (matcher "Write|Edit|MultiEdit" → PreToolUse/PostToolUse 命令)

2. 宿主事件  AI 调用 Write 工具 → Claude Code 命中 matcher → 以 stdin 注入
             hooks JSON（tool_name / tool_input / hook_event_name…）执行命令

3. PreToolUse → .harness/hooks/pre-tool-use.sh
             ├─ 守卫1 配置区（.harness/{hooks,scripts,rules,gate-config.json}）：
             │      克隆区比对 → allow/block（直改一律 block，.applying 豁免）
             ├─ 守卫2 状态机：无 coding/testing/reviewing 的 change 写源码
             │      → 注入提示（GATE_STRICT=1 时 block）
             └─ stdout 只输出 hooks JSON 回执（decision/reason/additionalContext）

4. 工具执行   Write 落盘 src/App.java

5. PostToolUse → .harness/hooks/post-tool-use.sh
             ├─ 提取写改文件路径列表
             └─ bash .harness/scripts/check-style.sh <file>（单文件增量）
                 → 违规时 additionalContext 注红灯，不阻断

6. 回复结束   Stop → .harness/hooks/stop.sh
             ├─ 检测「有流程中 change 且本轮有源码变更」才执行
             ├─ 依次 bash .harness/scripts/harness-gate.sh
             │      check-style|static-analysis|security-scan all <change-id>
             └─ 汇总 rc 注入下一轮上下文

7. 证据落盘   每个 gate 脚本末尾（有 change-id 时）调用 report.sh
             → .harness/changes/<id>/gate-<gate>.md（PASS/FAIL/DEGRADED + rc + 时间）

8. 对账审计   harness-status / harness-quality / harness-retro 读这些 gate-*.md
```

## 三、退出码约定（scripts 层全家族统一，hooks 据此判红灯）

| rc | 含义 | 对宿主呈现 | 能否进入下一阶段 |
|---|---|---|---|
| 0 | 通过 | PASS / allow / 「已通过增量检测」 | ✅ |
| 1 | 违规（有真实失败/红灯） | FAIL / block / deny / throw / 「红灯」 | ❌ 必须修复 |
| 2 | 工具未安装 / 无法测量 → **显式降级** | DEGRADED /「需人工核对」 | ⚠️ 人工核对后放行（绝不静默跳过） |
| 3 | 用法错误（参数不对） | stderr 提示用法 | — |

> **rc=2 是最重要的约定**：工具没装不是违规，但绝不能假装通过——宁可降级人工核对，
> 也不静默跳过。所有 gate 脚本在 `{{XXX_CMD}}` 未配置/命令不可用/底层依赖未就绪时都走这一步。

## 四、结果如何「出结果」：三类出口

1. **stdout 文本**（脚本给调用方看）：统一标记 `[OK]` / `[PASS]` / `[FAIL]` / `[DEGRADED]` / `[WARN]` / `[MISS]` / `[GUIDE]`，hooks 层用 `\b(FAIL|DEGRADED)\b` 正则识别红灯。
2. **退出码**（机器可判）：见上表，`harness-gate.sh <gate>` 退出码即 gate 脚本退出码。
3. **证据文件**（对账审计）：`report.sh` 落盘 `gate-<gate>.md`，含 rc / 状态 / 时间 / 变更 id。

## 五、结果不满足时如何报错：分宿主机制

| 宿主 | 写前（守卫） | 写后（增量） | 回复结束（出口） |
|---|---|---|---|
| Claude Code | `decision:"block"` + reason（stdout JSON） | additionalContext 注红灯（不阻断） | additionalContext 注入汇总（不阻断） |
| Codex CLI | 同 Claude（block） | 同 Claude | 同 Claude |
| Gemini CLI | `decision:"deny"` + reason（Golden Rule 单 JSON） | `hookSpecificOutput.additionalContext` 注入 | 同上（含【红灯】/【降级】/【通过】头部） |
| Cline | `throw new Error(...)`（工具调用记为失败） | `console.log` 会话日志（审计用） | 无出口挂点（before/after 只守卫写） |
| OpenCode | `throw new Error(...)`（before 阶段阻断） | `client.app.log`（level: warn） | `session.idle` 时出口全量检测记日志 |

## 六、触发频率与检测深度（分层检测策略）

| 时机 | 触发点 | 检测 | 不合格后果 |
|---|---|---|---|
| 每次写文件后 | PostToolUse / AfterTool | 单文件增量快检（行数/尾随空白/TODO/硬编码凭据 + lint 全量只提示） | 红灯注入上下文，AI 必须看到 |
| 每轮回复结束 | Stop / session.idle | 全量 check-style + static-analysis + security-scan | 汇总 rc 注入下一轮，AI 无法装作没看见 |
| 会话结束 | SessionEnd | 同上 + 证据落盘 | systemMessage 明示【红灯/降级/通过】 |
| CI / 技能出口 | unit-test-ci-<lang> 技能 | 全部 gate 含 coverage / arch-check（最全） | rc≠0 即失败，阻断合并 |

## 七、守卫的两种硬阻断与一个豁免

- **硬阻断**：直改 Harness 配置区（`.harness/{hooks,scripts,rules,gate-config.json}`）——五宿主全部硬拦截（block / deny / throw），提示走 `harness-standard` / `apply-harness` 规范流程。
- **软提示**：无进行中 change 却写源码（Claude/Codex 默认注入提示；Gemini 提示建卡；GATE_STRICT=1 / TS 插件放开后变硬拦截）。
- **豁免标记** `.harness/.applying`：apply-harness 规范重生成流程 start 时 `touch`、end 时 `rm -f`；存在期间配置区写入放行并同步克隆区基线。标记只应存在于 apply-harness 执行期间。

## 八、目录对应（本文档 → 实现文件）

| 文档 | 对应实现 |
|---|---|
| [01-bootstrap-tools.md](01-bootstrap-tools.md) | `scripts/bootstrap-tools.sh` |
| [02-check-style.md](02-check-style.md) | `scripts/check-style.sh` |
| [03-static-analysis.md](03-static-analysis.md) | `scripts/static-analysis.sh` |
| [04-coverage.md](04-coverage.md) | `scripts/coverage.sh` |
| [05-arch-check.md](05-arch-check.md) | `scripts/arch-check.sh` |
| [06-security-scan.md](06-security-scan.md) | `scripts/security-scan.sh` |
| [07-harness-gate.md](07-harness-gate.md) | `scripts/harness-gate.sh`（总入口） |
| [08-report.md](08-report.md) | `scripts/report.sh`（证据落盘） |
| [09-hooks-claude-codex.md](09-hooks-claude-codex.md) | `hooks/{pre,post}-tool-use.sh` `stop.sh` + `settings.json.tpl` `codex/hooks.json.tpl` |
| [10-hooks-gemini.md](10-hooks-gemini.md) | `hooks/gemini/*.sh` + `gemini/settings.json.tpl` |
| [11-hooks-cline.md](11-hooks-cline.md) | `hooks/cline/harness-plugin.ts` |
| [12-hooks-opencode.md](12-hooks-opencode.md) | `hooks/opencode/harness-plugin.ts` |