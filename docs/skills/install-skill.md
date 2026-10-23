# 技能注册 — install-skill

> **技能标识**: `install-skill`
> **使用场景**: 将 `.harness/skills/` 下的技能注册到当前 AI 工具

## 它做什么？

在目标项目根目录执行此命令，自动将 `.harness/skills/` 下的技能安装到当前 AI 工具可识别的技能目录，让 `/harnessing`、`/harness-me`、`/coding-skill` 等斜杠命令立即生效。

## 为什么需要这个命令？

`/apply-harness` 只负责把技能文件**复制**到 `.harness/skills/`，但各 AI 工具**不会自动扫描** `.harness/` 目录来注册斜杠命令。本命令把技能**注册**到工具真正扫描的技能目录。

## 支持的工具

| 工具 | 检测依据 | 安装目录 | 兼容性 |
|------|---------|---------|--------|
| **Reasonix** | `.reasonix/` 目录 | `.reasonix/skills/` | ✅ 原生 |
| **Claude Code** | `.claude/` 目录 | `.claude/skills/` | ✅ 原生 |
| **Cline / Roo Code** | `.cline/` 目录 | `.cline/skills/` | ✅ 兼容 |
| **Cursor** | `.cursor/` 目录 | `.cursor/skills/` | ✅ 原生 |
| **Codex (OpenAI)** | `.codex/` 目录 | `.codex/skills/` | ✅ 原生 |
| **Qoder** | `.qoder/` 目录 | `.qoder/skills/` | ✅ 原生 |
| **VS Code Agent Skills** | `.vscode/` 目录 | `.vscode/agent-skills/` | ✅ 原生 |
| **Windsurf** | `.windsurf/` 目录 | `.windsurf/workflows/` | ⚠️ 部分兼容 |
| **Continue.dev** | `.continue/` 目录 | `.continue/skills/` | ⚠️ 部分兼容 |
| **GitHub Copilot** | `.github/` 目录 | `.github/skills/` | ⚠️ 部分兼容 |
| **OpenCode** | `.opencode/` 目录 | `.opencode/commands/` | ⚠️ 有独立体系 |

## 工作流程

### Step 1: 检测当前 AI 工具

按优先级检测当前运行的 AI 工具，优先选择原生 SKILL.md 兼容的工具。

### Step 2: 定位技能来源

扫描 `.harness/skills/`，收集所有包含 `SKILL.md` 的技能目录。

### Step 3: 创建目标目录并安装技能

确保目标目录存在（`mkdir -p`），将每个技能完整复制到工具目录。

### Step 4: 输出安装摘要

显示已安装的技能列表和斜杠命令状态。

## 约束

- ❌ 不修改原始 `.harness/skills/` 内容
- ❌ 不把 `install-skill` 自身当作要安装的技能
- ✅ 若 `.harness/skills/` 不存在，提示先运行 `/apply-harness`

## 相关文档

- [应用 Harness 规范](apply-harness.md) — 先执行 `/apply-harness` 生成 `.harness/`