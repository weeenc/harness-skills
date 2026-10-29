# 技能注册 — install-skill

> **技能标识**: `install-skill`
> **使用场景**: 将 `.harness/skills/` 下的技能注册到当前 AI 工具

## 它做什么？

在目标项目根目录执行此命令，自动将 `.harness/skills/` 下的技能安装到当前 AI 工具可识别的技能目录，让 `/harnessing`、`/harness-me`、`/coding-skill` 等斜杠命令立即生效。

## 为什么需要这个命令？

各 AI 工具不会自动扫描 `.harness/` 来注册命令。`apply-harness` 已自动调用本注册流程；单独执行 `install-skill` 用于拉取已有项目后的本机注册，或重试未完成项，不重新生成 Harness 规则与历史。

## 支持的工具

| 工具 | 检测依据 | 安装目录 | 兼容性 |
|------|---------|---------|--------|
| **Reasonix** | `.reasonix/` 目录 | `.reasonix/skills/` | ✅ 原生 |
| **Claude Code** | `.claude/` 目录 | `.claude/skills/` | ✅ 原生 |
| **Cline / Roo Code** | `.cline/` 目录 | `.cline/skills/` | ✅ 兼容 |
| **Cursor** | `.cursor/` 目录 | `.cursor/skills/` | ✅ 原生 |
| **Codex (OpenAI)** | 当前 Codex 会话优先 | `.agents/skills/` | ✅ 原生；检查项目/个人同名入口 |
| **Qoder** | `.qoder/` 目录 | `.qoder/skills/` | ✅ 原生 |
| **VS Code Agent Skills** | `.vscode/` 目录 | `.vscode/agent-skills/` | ✅ 原生 |
| **Windsurf** | `.windsurf/` 目录 | `.windsurf/workflows/` | ⚠️ 部分兼容 |
| **Continue.dev** | `.continue/` 目录 | `.continue/skills/` | ⚠️ 部分兼容 |
| **GitHub Copilot** | `.github/` 目录 | `.github/skills/` | ⚠️ 部分兼容 |
| **OpenCode** | `.opencode/` 目录 | `.opencode/commands/` | ⚠️ 有独立体系 |

## 工作流程

### Step 1: 检测当前 AI 工具

当前会话的宿主或用户指定的工具优先，目录仅作辅助线索；不能仅凭 `OPENAI_API_KEY` 判断为 Codex。

### Step 2: 定位技能来源

扫描当前根自己的 `.harness/skills/`，使用渲染后的 frontmatter `name`，不递归收集子仓或重新安装整个原始包。

### Step 3: 创建目标目录并安装技能

先检查当前作用域已有入口。同名、同内容且引用有效时复用；没有入口时创建目录并完整复制；同名不同内容或已有多个入口时报告冲突，不再制造副本。完整协议见 [Codex 注册规则](../../skills/install-skill/references/codex-registration.md)。

前后端是独立 Git 仓库时分别检查可见性，不假设子仓继承协调层。同一语言的两个仓库各注册自己的技能是正常的；协调层按仓库路径调用，不集中复制子仓命令。

### Step 4: 输出安装摘要

显示新增、复用、冲突、失败及来源路径。无冲突且所有入口可用才算注册完成；菜单未实时刷新时需重新加载确认。

## 约束

- ❌ 不修改原始 `.harness/skills/` 内容
- ❌ 不把 `install-skill` 自身当作要安装的技能
- ❌ 不自动删除、覆盖或禁用个人技能，不通过改目录名隐藏同名冲突
- ✅ 若 `.harness/skills/` 不存在，提示先运行 `/apply-harness`

## 为什么会同时显示“项目名”和“个人”？

通常是同一个技能包同时安装在项目 `.agents/skills/` 与个人 `~/.agents/skills/`。Codex 的同名入口不会自动合并；这与前后端是否独立 Git 仓库是两回事。首次安装原始包时选择一个范围，已有个人安装时不要再向项目复制整包。

新注册规则会避免继续新增冲突入口，但不会擅自清理历史安装。已重复的两套内容可能版本不同，需要比较后再决定保留范围。

## 相关文档

- [应用 Harness 规范](apply-harness.md) — 先执行 `/apply-harness` 生成 `.harness/`
