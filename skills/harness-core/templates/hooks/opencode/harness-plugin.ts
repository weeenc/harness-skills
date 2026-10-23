/**
 * Harness 门禁插件（OpenCode）
 *
 * 依据官方文档: https://opencode.ai/docs/plugins/
 * 安装: 复制到项目 .opencode/plugins/harness-plugin.ts，启动时自动加载
 *
 * 能力边界：tool.execute.before 抛错可硬阻断违规写操作；after / session.idle
 * 阶段通过 client.app.log 记录门禁结果（OpenCode 插件暂无上下文注入通道，
 * 红灯阻断以 before 守卫为主，深度检测由 .harness/scripts/ 承担）。
 */
import { existsSync } from "node:fs"
import type { Plugin } from "@opencode-ai/plugin"

const WRITE_TOOLS = new Set(["write", "edit", "patch", "multiedit", "write_file", "edit_file"])

/** 禁止直改的 Harness 配置区 */
const CONFIG_PATHS = [
  ".harness/hooks", ".harness/scripts", ".harness/rules",
  ".harness/gate-config.json", ".harness/动态事实来源.md",
]

function argsPath(args: unknown): string | null {
  const a = args as Record<string, unknown> | null | undefined
  if (!a) return null
  for (const k of ["filePath", "file_path", "path"]) {
    const v = a[k]
    if (typeof v === "string" && v.length > 0) return v
  }
  return null
}

function isConfigPath(p: string): boolean {
  const s = p.replace(/^\.\//, "")
  return CONFIG_PATHS.some((c) => s === c || s.startsWith(c + "/"))
}

export const HarnessPlugin: Plugin = async ({ client, $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (!WRITE_TOOLS.has(input.tool)) return
      const p = argsPath(output.args)
      if (!p) return
      if (isConfigPath(p)) {
        // apply-harness 规范流程豁免：标记存在时放行（基线同步由 apply-harness 自身维护）
        if (existsSync(".harness/.applying")) return
        throw new Error(
          `[门禁] 禁止直接修改 Harness 配置区 ${p}——配置变更请通过 harness-standard / apply-harness 走规范流程`,
        )
      }
    },

    "tool.execute.after": async (input, output) => {
      if (!WRITE_TOOLS.has(input.tool)) return
      const p = argsPath(output.args)
      if (!p || isConfigPath(p)) return
      const r = await $`bash .harness/scripts/check-style.sh ${p}`.quiet().nothrow()
      await client.app.log({
        body: {
          service: "harness",
          level: r.exitCode === 0 ? "info" : "warn",
          message: `[门禁·增量] ${p} rc=${r.exitCode} ${r.stdout.trim().split("\n").filter(Boolean).pop() ?? ""}`,
        },
      })
    },

    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      // 出口全量检测（非阻断，记录供复盘；会话空闲 ≈ 一轮回复结束）
      const r = await $`bash .harness/scripts/harness-gate.sh check-style all`.quiet().nothrow()
      await client.app.log({
        body: {
          service: "harness",
          level: "info",
          message: `[门禁·出口] rc=${r.exitCode}\n${r.stdout.trim().slice(0, 2000)}`,
        },
      })
    },
  }
}