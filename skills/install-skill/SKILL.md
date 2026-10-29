---
name: install-skill
description: 将 .harness/skills/ 下的技能注册到当前 AI 工具（reasonix / claude-code / cline / cursor / codex / qoder / trae / codebuddy / lingma / windsurf / copilot 等 19+ 工具）可识别的技能目录，使 /harnessing、/harness-me 等斜杠命令立即可用
---

# Install Skill — 一键注册技能到当前工具

> 在**目标项目根目录**执行此命令，自动将 `.harness/skills/` 下的技能安装到当前 AI 工具可识别的技能目录，让 `/harnessing`、`/harness-me`、`/coding-skill` 等斜杠命令立即生效。

---

## 为什么需要这个命令？

各 AI 工具不会自动把 `.harness/` 当成技能注册目录。本技能是统一注册入口：`apply-harness` 初始化时自动执行本流程；已有项目拉取后或注册失败时，也可以单独调用，不需要重新生成 Harness。

**常见问题**：许多项目从未生成过 AI 工具的技能目录。例如，即使项目使用 Reasonix，`.reasonix/skills/` 目录可能不存在或为空——这导致 `/harnessing`、`/coding-skill` 等斜杠命令无法被识别。本命令不仅检测 AI 工具，还会**自动创建缺失的目录**并安装技能。

## 工作流程

### Step 1: 检测当前 AI 工具

优先采用当前会话明确的宿主或用户指定的工具，其次才使用环境和目录线索。确定目标工具后，按以下目录注册；目录缺失不代表工具不可用：

| 工具 | 检测依据 | 技能安装目录 | 兼容性说明 |
|------|---------|-------------|-----------|
| **Reasonix** | 存在 `.reasonix/` 目录 或 `REASONIX` 环境变量 | `.reasonix/skills/` | ✅ 原生 SKILL.md |
| **Claude Code** | 存在 `.claude/` 目录 或 `CLAUDE_CODE` 环境变量 | `.claude/skills/` | ✅ 原生 SKILL.md |
| **Cline / Roo Code** | 存在 `.cline/` 或 `.clinerules/` 目录 | `.cline/skills/` 或 `.claude/skills/` | ✅ 兼容 `.claude/skills/` |
| **Cursor** | 存在 `.cursor/` 目录 | `.cursor/skills/` | ✅ 原生 SKILL.md |
| **Codex (OpenAI)** | 当前会话为 Codex；`.codex/` 仅作辅助线索 | `.agents/skills/` | ✅ 原生 SKILL.md；按下文检查跨范围冲突 |
| **Qoder** | 存在 `.qoder/` 目录 | `.qoder/skills/` | ✅ 完全兼容 SKILL.md |
| **VS Code Agent Skills** | 存在 `.vscode/` 目录（VS Code 1.98+） | `.vscode/agent-skills/` | ✅ 通过 VS Code Agent Skills 标准 |
| **Amazon Q Developer** | 存在 `.qdeveloper/` 或通过 VS Code 代理 | `.github/copilot-instructions.md` 或 `.vscode/agent-skills/` | ⚠️ 通过 VS Code Agent Skills 间接兼容 |
| **Windsurf** | 存在 `.windsurf/` 目录 | `.windsurf/workflows/`（需手动映射命令） | ⚠️ 非 SKILL.md 原生 |
| **Continue.dev** | 存在 `.continue/` 目录 | `.continue/skills/`（通过 config.yaml 注册） | ⚠️ 部分兼容 SKILL.md |
| **GitHub Copilot** | 存在 `.github/` 目录 | `.github/skills/` | ⚠️ 部分兼容（Cloud Agent） |
| **OpenCode** | 存在 `.opencode/` 目录 | `.opencode/commands/`（每命令一个 .md 文件） | ⚠️ 有独立命令体系 |
| **Trae** | 存在 `.trae/` 目录 | `.trae/rules/`（非 SKILL.md 原生） | ⚠️ 有独立规则体系 |
| **CodeBuddy** | 存在 `.codebuddy/` 目录 | `.codebuddy/`（路径待确认） | ⚠️ 兼容性未确认 |
| **通义灵码 (Tongyi Lingma)** | 存在 `.lingma/` 目录 | `.lingma/`（路径待确认） | ⚠️ 兼容性未确认 |
| **CodeGeeX** | 存在 `.codegeex/` 目录 | `.codegeex/`（路径待确认） | ⚠️ 兼容性未确认 |
| **Tabnine** | 存在 `.tabnine/` 目录 | `.tabnine/guidelines/` | ⚠️ 使用 guidelines.md 替代 SKILL.md |
| **Sourcegraph Cody** | 存在 `.cody/` 目录 | `.cody/`（路径待确认） | ⚠️ 兼容性未确认 |
| **MarsCode** | 存在 `.mars/` 目录 | `.mars/`（已合并到 Trae） | ⚠️ 兼容性未确认 |

> **检测逻辑**：明确的宿主身份优先于表格顺序。无宿主信息时才按线索选择原生兼容工具；多个候选无法区分时询问工具名称。`OPENAI_API_KEY` 不能单独证明正在使用 Codex，`.agents/skills/` 也可能被其他工具使用。
>
> **目录准备**：需要新增入口时用 `mkdir -p <目标目录>` 创建缺失目录；已有可复用入口时无需另建目录。

### Step 2: 定位技能来源

扫描项目根目录下的 `.harness/skills/`，收集所有包含 `SKILL.md` 的技能目录：

```
.harness/skills/
├── {lang}/          # 语言特有技能（harnessing、harness-me、coding-skill...）
└── common/          # 跨语言通用技能（domain-modeling、research、resolving-merge-conflicts）
```

工作空间调用时，协调层和每个子仓分别以自己的根为输入，不递归收集兄弟仓库的技能。读取渲染后的 frontmatter `name`，以它作为注册名和目标目录名；例如两个都叫 `coding-skill/` 的源目录分别注册为 `coding-skill-java/` 与 `coding-skill-front/`。含未替换占位符、无合法名称或同名不同内容的来源先报告，不安装未渲染模板。

只注册这里的运行技能。不要再次复制原始 `harness-core`、语言包或初始化器；安装原始包与注册渲染后的技能是两个步骤，不能互相代替。

### Step 3: 创建目标目录并安装技能

**Codex 先读取 [作用域检查与去重规则](references/codex-registration.md)，完成检查后再决定哪些入口需要创建。** 其他工具也先检查源和目标差异；只在确有新入口时创建目标目录：

```bash
mkdir -p <目标目录>
```
例如：`mkdir -p .reasonix/skills/`、`mkdir -p .claude/skills/`、`mkdir -p .cursor/skills/`。

> 不要假设目标目录已经存在。很多项目从未生成过 AI 工具的技能目录，`mkdir -p` 是安全的。

然后，对每个含 `SKILL.md` 的技能目录 `<skill-name>`，按工具兼容性采取不同方式：

**✅ 原生 SKILL.md 工具**（Reasonix、Claude Code、Cline、Cursor、Codex、Qoder、VS Code Agent Skills）
1. 目标不存在且没有可复用入口时，完整复制到 `<工具目录>/<frontmatter-name>/`，保留支持文件与相对引用。
2. 保持 frontmatter `name` 不变；不得靠更改目录名来掩盖同名冲突。
3. 同内容已存在时复用；同名不同内容时保留现有内容，列出差异及范围，按已有更新授权处理，否则待确认。不得通过复制到另一条扫描路径制造第二个入口。
4. 安装前识别符号链接：不通过项目链接覆写个人或外部技能目录。安装后重扫当前作用域，验证名称、路径和支持文件均可解析。

**⚠️ 非原生工具**（Windsurf、OpenCode、Trae、CodeBuddy、通义灵码、CodeGeeX、Tabnine、Cody、MarsCode 等）
- 优先尝试将技能复制到对应目录（如 `.trae/rules/`、`.opencode/commands/`）
- 若工具不支持 SKILL.md 格式，将技能内容转换为该工具支持的格式（如 Tabnine 的 `guidelines.md` 或 OpenCode 的独立命令 .md 文件）
- 若无法自动转换，**提示用户手动配置**并给出配置指引

### Step 4: 输出安装摘要

摘要区分新增、复用、冲突、失败，列出入口来源及实际可调用名；全部源技能都有可用且不冲突的入口才称注册完成。已有项目/个人双重安装要单独报告，不把“本次没有新建重复项”写成“历史重复已修复”。

```
╔══════════════════════════════════════════╗
║   ✅ 技能已安装到 <工具名>               ║
╠══════════════════════════════════════════╣
║  目标目录: .reasonix/skills/             ║
║  已安装:   N 个技能                       ║
║  /harnessing        ✅ 可调用             ║
║  /harness-me        ✅ 可调用             ║
║  /coding-skill      ✅ 可调用             ║
║  ...                                    ║
╚══════════════════════════════════════════╝
```

> 提示：若工具未即时刷新，重启会话或重新加载即可看到新斜杠命令。
> **Claude Code 用户注意**：若 `.claude/skills/` 未自动将技能暴露为斜杠命令，请在 `.claude-plugin/plugin.json` 的 `skills` 数组中添加对应路径，或通过 `.claude/commands/` 目录注册。
> **Cline 用户注意**：Cline 兼容 `.claude/skills/` 目录，技能安装到 `.claude/skills/` 即可被 Cline 识别。
> **通用回退**：无法确认宿主时请用户指定工具或目录，不自动重新运行整包安装器；缺少技能包与已有包尚未注册应分别处理。

---

## 约束

- ❌ 不修改原始 `.harness/skills/` 内容（只复制，不移动）
- ❌ 不把 `install-skill` 自身当作要安装的技能
- ✅ 只安装到检测到的工具目录，不跨工具安装
- ✅ 若 `.harness/skills/` 不存在，提示先运行 `/apply-harness`
- ✅ 同内容复用，不同内容保留并报告；不盲目覆盖已有入口。
- ❌ 不为项目初始化写入、删除或禁用个人范围技能；历史重复安装单独处理。
---


