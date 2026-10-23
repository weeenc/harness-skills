# 宿主工具 hooks — `.harness/hooks/`

> 本目录是「门禁层」的**触发器**：把 `.harness/scripts/` 的确定性检测脚本挂到宿主 AI 工具的
> 工具调用事件上，由宿主引擎强制执行——**不依赖模型自觉**。
>
> 支持 5 个宿主的 hooks（2026-10 官方文档查证）：**Claude Code**、**Gemini CLI**、
> **Codex CLI (OpenAI)**、**Cline**、**OpenCode**。其余工具（Cursor/Windsurf/Copilot/
> Continue/Roo Code 等）无动作级 hooks → 降级为技能文本强制调用脚本（见技能兜底）。

## 各宿主支持一览（官方文档来源）

| 宿主 | 机制 | 事件 | 配置生成于 | 本目录对应 |
|---|---|---|---|---|
| Claude Code | shell command hooks | PreToolUse / PostToolUse / Stop | `.claude/settings.json`（合并 hooks 数组） | `pre-tool-use.sh` `post-tool-use.sh` `stop.sh` + `settings.json.tpl` |
| Gemini CLI | shell command hooks | BeforeTool / AfterTool / SessionEnd | `.gemini/settings.json`（合并 hooks 字段） | `gemini/before-tool.sh` `gemini/after-tool.sh` `gemini/session-end.sh` + `gemini/settings.json.tpl` |
| Codex CLI (OpenAI) | shell command hooks（兼容 Claude Code 格式） | PreToolUse / PostToolUse / Stop | `.codex/hooks.json` | `codex/hooks.json.tpl`（复用左侧三个脚本） |
| Cline | SDK TS 插件 | beforeTool / afterTool / 等（观察性 + throw 阻断） | `.cline/plugins/harness-plugin.ts` | `cline/harness-plugin.ts` |
| OpenCode | TS 插件 | tool.execute.before / after / session.idle | `.opencode/plugins/harness-plugin.ts` | `opencode/harness-plugin.ts` |

> 协议差异要点：Claude Code / Codex 的 stdin 为 JSON、stdout 回执 JSON、退出码 0/2 语义一致，
> 故 Codex 直接复用 Claude 协议脚本；Gemini CLI 的 stdout 遵循 **Golden Rule**（只输出一个最终
> JSON 对象，多余文本导致解析失败），故其脚本独立实现（输出全走捕获变量 + 单次 JSON echo）；
> Cline / OpenCode 是 TypeScript 插件（非 shell），守卫靠 throw、记录靠日志/审计，无上下文注入通道。

## 机制

| hook / 触发器 | 触发点 | 干什么 |
|------|--------|--------|
| `pre-tool-use.sh` (Claude/Codex) | 每次 `Write/Edit/MultiEdit` 前 | 配置区守卫（克隆区比对：与快照一致 `allow`、新增/不一致 `block`；`.harness/.applying` 存在时放行并增量同步基线）+ 状态机提示；`GATE_STRICT=1` 时无 change 写源码也 `block` |
| `post-tool-use.sh` (Claude/Codex) | 每次 `Write/Edit/MultiEdit` 后 | 对写改文件跑增量深度检测（`check-style.sh <file>`），红灯注入 |
| `stop.sh` (Claude/Codex) | 每个回复结束时 | 全量深度检测（check-style / static-analysis / security-scan）+ 证据落盘，结果注入下一轮 |
| `gemini/before-tool.sh` | Gemini 写工具前 | 配置区守卫（克隆区比对：一致 `allow`、新增/不一致 `deny`；`.applying` 豁免同上）+ 流程提示（进行中 change） |
| `gemini/after-tool.sh` | Gemini 写工具后 | 单文件增量检测 → `additionalContext` 注入（红灯让模型看到） |
| `gemini/session-end.sh` | Gemini 会话结束 | 出口全量检测 + 证据落盘 → `additionalContext` 注入 |
| `cline/harness-plugin.ts` | Cline 写工具前/后 | beforeTool 守卫（throw 阻断配置区直改）；afterTool 增量检测日志 |
| `opencode/harness-plugin.ts` | OpenCode 写工具前/后/会话空闲 | before 守卫（throw 阻断）；after 增量检测日志；session.idle 出口全量日志 |

## 克隆区 `.harness/clone/`

配置区（`.harness/{hooks,scripts,rules,gate-config.json}`）的**只读快照**，由 hook 脚本在首次运行时
**自动复制生成**（缺失不报错，直接自举），用于识别配置被直接篡改：

- 写工具目标是配置区文件时，脚本先 `ensure_clone()`（缺失→自动 `cp -R` 自举），再与快照 `diff`：
  - 快照不存在该文件（新增）→ 视为直改：Claude/Codex `block`、Gemini `decision:"deny"`、Cline/OpenCode `throw`；
  - 内容与快照不一致（已被动过）→ 同上硬拦截，并提示走规范流程；
  - 与快照一致（重复写相同内容）→ 放行并提示「如需变更请走规范流程」。
- 快照目录本身（`.harness/clone/`）不在守卫白名单内，允许 hook 自举写入。
- **规范流程豁免标记 `.harness/.applying`**：apply-harness 重新生成时在流程开始 `touch`（Step 7.3 第 0 步）、结束 `rm -f`。标记存在期间，四个宿主对配置区写入一律放行并**增量同步克隆区基线**（保持基线=现网，防后续直改比对失准）。标记只应存在于 apply-harness 执行期间；异常出现时删掉即恢复守卫（hook 不自动清理）。
- harness-standard（改门禁/规则）**不建标记**：先走其评审流程，完成后重同步基线（删 `.harness/clone/` 触发下次 hook 自举复制即可）。

## 安装（apply-harness Step 7.3 按检测到的宿主自动完成）

1. 本目录脚本复制到 `.harness/hooks/`（含 `gemini/` 子目录）；
2. 按 Step 5.5 检测到的宿主生成对应配置：
   - **Claude Code**（`.claude/` 存在）：`settings.json.tpl` → `.claude/settings.json`，已存在则仅追加 hooks 数组（保留原配置）；
   - **Gemini CLI**（`.gemini/` 存在或 `GEMINI_CLI` 环境变量）：`gemini/settings.json.tpl` 的 hooks 字段 → `.gemini/settings.json`，已存在则合并 hooks 键（保留原配置）；脚本经 `$GEMINI_PROJECT_DIR` 绝对路径引用；
   - **Codex (OpenAI)**（`.codex/` 存在）：`codex/hooks.json.tpl` → `.codex/hooks.json`（若已存在，合并/经用户确认）；
   - **Cline**（`.cline/` 存在）：`cline/harness-plugin.ts` → `.cline/plugins/harness-plugin.ts`；
   - **OpenCode**（`.opencode/` 存在）：`opencode/harness-plugin.ts` → `.opencode/plugins/harness-plugin.ts`；
3. 前提：环境有 `bash`（Windows 用 Git Bash）；Claude/Codex/Gemini 的 shell hook 另需 `node`
   （Claude Code 自带 node；Gemini/Codex 若缺 node，脚本内已回退粗解析，或跳过 hooks 并在卡片注明）；
   TS 插件在宿主体内编译运行，无需本地 node 工具链。
4. **卸载**：删除对应配置文件中本模板添加的条目/文件即可。

## 严格模式

默认 before/PreToolUse 只**注入提示不拦截**（避免误伤 Hotfix / Spike / 纯文档裁剪场景）。
守卫例外：**直改 Harness 配置区**（`.harness/hooks|scripts|rules|gate-config.json`）在
Claude/Gemini/Codex/Cline/OpenCode 全部硬阻断（`block` / `decision:"deny"` / `throw`）。
如需整体硬拦截：在 shell hooks 的 command 前加 `GATE_STRICT=1`（或设环境变量）；TS 插件在源内放开。

## 分层检测策略（与 scripts/README.md 一致）

- 增量单文件（每次写后）→ 快检，代码风格红线即时暴露
- 出口全量（每轮回复/会话结束）→ 复核全部变更，deep check + 证据落盘
- ⑤ `unit-test-ci` 门禁 → 全部 gate 全量（含 coverage / arch-check，最全）

> hooks 只是触发器；**检测深度由 `.harness/scripts/` 承载**——想检测多深就堆多深。