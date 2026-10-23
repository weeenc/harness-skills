# 宿主 hooks：Claude Code / Codex CLI（09）

> 对应实现：`hooks/pre-tool-use.sh` `hooks/post-tool-use.sh` `hooks/stop.sh`
> + `hooks/settings.json.tpl`（Claude） `hooks/codex/hooks.json.tpl`（Codex）
>
> 两宿主共享同一套 shell hooks（Codex 官方兼容 Claude Code hooks 格式），差别只在配置文件
> 与放行路径：Claude → `.claude/settings.json`；Codex → `.codex/hooks.json`。

## 一、hook 是如何触发的

```jsonc
// settings.json.tpl（渲染进 .claude/settings.json；Codex 同名结构进 .codex/hooks.json）
{
  "hooks": [
    { "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "PreToolUse",  "command": "bash .harness/hooks/pre-tool-use.sh",  "timeout": 15 },
        { "type": "PostToolUse", "command": "bash .harness/hooks/post-tool-use.sh", "timeout": 60 }
      ] },
    { "matcher": "Stop",
      "hooks": [ { "type": "Stop", "command": "bash .harness/hooks/stop.sh", "timeout": 300, "async": false } ] }
  ]
}
```

| 事件 | matcher | 触发时刻 | stdin 内容（宿主注入） |
|---|---|---|---|
| PreToolUse | Write/Edit/MultiEdit | 工具执行**前** | hooks JSON：`hook_event_name`、`tool_name`、`tool_input`（含 `file_path`/`path`/`edits[].path`）… |
| PostToolUse | Write/Edit/MultiEdit | 工具执行**后** | 同上 |
| Stop | Stop | 每轮回复**结束** | hooks JSON（`hook_event_name:"Stop"`） |

宿主引擎命中 matcher 后：以 stdin 注入 JSON → 阻塞执行 command → 读取 **stdout 上的 hooks 回执 JSON**。

## 二、pre-tool-use.sh 如何检测、如何出结果

stdout 只输出回执 JSON（`exit_json` 保证单 JSON），默认退出码 0（**意图性阻断用 JSON decision 表达**，
不用退出码）。

**守卫 1｜配置区直改**（目标文件命中 `.harness/{hooks,scripts,rules,gate-config.json,动态事实来源.md}`）：

1. `ensure_clone()`：`.harness/clone/`（配置区只读快照）缺失时自动 `cp -R` 自举，**缺失不报错**。
2. `.harness/.applying` 标记存在（apply-harness 规范流程中）→ `allow` + 增量同步基线快照。
3. 快照无此文件（**新增配置**）→ `decision:"block"` + 「配置变更请通过 harness-standard / apply-harness」。
4. `diff` 不一致（**配置被直改过**）→ `decision:"block"` + 「正在 block」。
5. 与快照一致（重复写相同内容）→ `decision:"allow"` + 「如需变更请走规范流程」。

**守卫 2｜状态机提示**（非配置区源码；`.harness/*` 与 vendor/node_modules/target 等自动放行）：
扫描 `.harness/changes/*/change.md` 的 `status:` 集合——

- 无 `coding/testing/reviewing` 中的 change 却在写源码：
  - `GATE_STRICT=1` → `decision:"block"`（硬拦）；
  - 默认 → 仅 `additionalContext` 注入提示（「请先 /harnessing 建卡…Hotfix/Spike 请在 change.md 显式记录」）。

**结果不满足时的呈现**：`block` 时宿主中止该次工具调用；`allow+提示` 时模型下一轮看到
`additionalContext` 红字提示，但写操作放行（故意宽松，防误伤 Hotfix/Spike/纯文档）。

## 三、post-tool-use.sh 如何检测、如何出结果

1. 从 stdin JSON 提取本次写改**所有**文件路径（Write.file_path / Edit.path / MultiEdit.edits[].path，去重）。
2. 按守卫白名单过滤（`.harness/*`、产物目录跳过），逐个 `bash check-style.sh <file>` 增量快检。
3. stdout 只输出一个回执 JSON：全绿 → `additionalContext:"[门禁·增量] 本次写改文件已通过风格增量检测: …"`；
   任一违规 → `additionalContext:"[门禁·增量·红灯] …存在风格违规，请修复后再继续: …"`（含文件名与命中行）。

**结果不满足时**：不阻断写操作（写后检测本来就无法回滚），把红灯**注入 AI 下一轮上下文**——
让模型看到具体违规位置并自行修复；深度清零由出口全量兜底。检测脚本缺失 → 静默跳过（`exit 0`）。

## 四、stop.sh 如何检测、如何出结果

两个前置条件**同时满足**才执行（避免每轮回复空转）：
1. 存在流程中 change（`status ∈ coding/testing/reviewing/ci/verifying`）；
2. 本轮有源码变更（`git diff --quiet HEAD` 非空，或有未提交的非 `.harness` 文件）。

然后依次经总入口跑三个全量门禁并逐条汇总 rc：

```bash
bash .harness/scripts/harness-gate.sh check-style      all <change-id>
bash .harness/scripts/harness-gate.sh static-analysis  all <change-id>
bash .harness/scripts/harness-gate.sh security-scan    all <change-id>
```

输出单个回执 JSON，`additionalContext` 头部明示：`[门禁·出口] 本轮全量深度检测（change: xxx）—— rc=0 通过 / rc=1 红灯需修复 / rc=2 工具未安装已显式降级需人工核对`+ 每个 gate 的首 40 行输出。

**结果不满足时**：不阻断本轮（异步注入下一轮），但 **rc≠0 的证据文件已落盘**（各 gate 末尾 report.sh），
`harness-status` 对账时该 change 停在当前阶段，AI 在下一轮回复里**被迫**看到红灯并修复。

## 五、关键差异与坑

| 项 | Claude | Codex |
|---|---|---|
| 配置文件 | `.claude/settings.json`（追加 hooks 数组，保留原配置） | `.codex/hooks.json`（合并/经用户确认） |
| 命令相对路径 | hook 命令相对项目根执行 | **版本不同 cwd 行为不同**——模板注释已提醒：若命令不生效，改为绝对路径 |
| async | Stop 可 `"async": false` | 同 |

> 命令相对路径经 `HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"` 锚定项目根再取
> 脚本，**与 cwd 无关**，从任何目录触发都同一基准（这是 scripts 层"不依赖 cwd"原则在 hooks 层的延续）。