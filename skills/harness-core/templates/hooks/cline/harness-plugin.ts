/**
 * Harness 门禁插件（Cline / ClineCore SDK hooks）
 *
 * 依据官方文档: https://docs.cline.bot/sdk/guides/writing-plugins
 *             https://docs.cline.bot/sdk/events
 * 安装: 复制到项目 .cline/plugins/harness-plugin.ts（或 cline plugin install 本文件）
 *
 * 能力边界（官方设计指南）：Cline hooks 以观察/审计为主——beforeTool 抛出错误会
 * 计为工具失败（可硬拦截违规写操作），afterTool 用于记录检测结果。
 * 深度检测仍由 .harness/scripts/ 承担；本插件只是触发器 + 守卫。
 */
import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import type { AgentPlugin } from "@cline/sdk"

const WRITE_TOOLS = new Set([
  "Write", "Edit", "MultiEdit",
  "WriteFile", "EditFile",
  "insert_content", "replace_in_file",
])

/** 禁止直改的 Harness 配置区（须走 harness-standard / apply-harness 规范流程） */
const CONFIG_PATHS = [
  ".harness/hooks", ".harness/scripts", ".harness/rules",
  ".harness/gate-config.json", ".harness/动态事实来源.md",
]

function toolName(context: unknown): string {
  const t = (context as { toolCall?: { name?: unknown } }).toolCall
  return typeof t?.name === "string" ? t.name : ""
}

function targetPath(context: unknown): string | null {
  const input = (context as { input?: unknown }).input as Record<string, unknown> | null | undefined
  if (!input) return null
  for (const k of ["file_path", "filePath", "path"]) {
    const v = input[k]
    if (typeof v === "string" && v.length > 0) return v
  }
  return null
}

function isConfigPath(p: string): boolean {
  const s = p.replace(/^\.\//, "")
  return CONFIG_PATHS.some((c) => s === c || s.startsWith(c + "/"))
}

const plugin: AgentPlugin = {
  name: "harness-gates",
  manifest: { capabilities: ["hooks"] },
  hooks: {
    beforeTool(context) {
      if (!WRITE_TOOLS.has(toolName(context))) return
      const p = targetPath(context)
      if (!p) return
      if (isConfigPath(p)) {
        // apply-harness 规范流程豁免：标记存在时放行（基线同步由 apply-harness 自身维护）
        if (existsSync(".harness/.applying")) return
        // 硬拦截：直改门禁配置区 = 工具失败
        throw new Error(
          `[门禁] 禁止直接修改 Harness 配置区 ${p}——配置变更请通过 harness-standard / apply-harness 走规范流程`,
        )
      }
    },

    afterTool(context) {
      if (!WRITE_TOOLS.has(toolName(context))) return
      const p = targetPath(context)
      if (!p) return
      if (!p.includes(".harness/")) {
        // 单文件增量深度检测（红灯不阻断，记录到会话日志供审计/后续修复）
        const r = spawnSync("bash", [".harness/scripts/check-style.sh", p], {
          encoding: "utf8", timeout: 60000,
        })
        const last = (r.stdout || r.stderr || "").trim().split("\n").filter(Boolean).pop() || ""
        console.log(`[harness·增量] ${p} ⇒ rc=${r.status ?? -1} ${last}`)
      }
    },
  },
}

export default plugin