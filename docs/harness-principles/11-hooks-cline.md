# 宿主 hooks：Cline（11）

> 对应实现：`hooks/cline/harness-plugin.ts`（渲染为 `.cline/plugins/harness-plugin.ts`，
> 需在 Cline 内 `plugin install` / 或按官方 SDK 加载）
>
> Cline 是 **TS 插件体系而非 shell hooks**：没有 stdin JSON、没有 hooks JSON 回执协议。
> 插件以 `AgentPlugin` 导出，宿主按生命周期回调。检测逻辑仍全在 `.harness/scripts/`，
> 插件只是**触发器 + 守卫**。

## 一、hook 是如何触发的

```ts
const plugin: AgentPlugin = {
  name: "harness-gates",
  manifest: { capabilities: ["hooks"] },
  hooks: {
    beforeTool(context) { … },   // 每次工具调用【前】
    afterTool(context)  { … },   // 每次工具调用【后】
  },
}
export default plugin
```

| 回调 | 触发时刻 | context 里取什么 |
|---|---|---|
| `beforeTool` | 工具执行前 | `context.toolCall.name`（工具名）、`context.input`（参数对象） |
| `afterTool` | 工具执行后 | 同上 |

写工具白名单 `WRITE_TOOLS`：`Write / Edit / MultiEdit / WriteFile / EditFile /
insert_content / replace_in_file`（兼容 Claude 系与 Cline 自身写工具命名）。

## 二、如何检测、如何出结果

**beforeTool（守卫，硬拦截）**：

1. 非写工具 → 放行。
2. 取目标路径（`input.{file_path,filePath,path}`，逐键取首个非空）。
3. 命中配置区（`.harness/{hooks,scripts,rules,gate-config.json,动态事实来源.md}`）：
   - `.harness/.applying` 标记存在（apply-harness 规范流程中）→ 放行（基线同步由 apply-harness 自身维护）；
   - 否则 **`throw new Error("[门禁] 禁止直接修改 Harness 配置区 …——配置变更请通过 harness-standard / apply-harness 走规范流程")`**。
4. 源码文件（非配置区）→ 放行（Cline 无 GATE_STRICT 开关位，状态机提示由技能模板承担）。

> 依据官方设计指南：beforeTool 抛错会**计为该次工具调用失败**——这正是硬拦截语义。

**afterTool（增量检测，观察性）**：

1. 非写工具/配置区 → 跳过。
2. `spawnSync("bash", [".harness/scripts/check-style.sh", p], { timeout: 60000 })` 单文件增量快检。
3. 只 `console.log` 会话日志：`[harness·增量] <path> ⇒ rc=<N> <最后一行结论>` —— 供审计/后续修复，
   **不注入上下文**（Cline hooks 的能力边界：以观察/审计为主）。

## 三、结果不满足时如何报错

| 情形 | 表现 | 语义 |
|---|---|---|
| 直改配置区 | `throw` → 工具调用记为**失败**，错误消息显示给模型 | 硬拦截 ✅ |
| 增量检测红灯 | 仅日志记录（level 无关，console） | 软提示——深度清零靠 CI/技能出口门禁（`unit-test-ci`）兜底 |

**能力边界（官方文档查证）**：Cline hooks 无「注入模型上下文」通道，所以：
写前硬拦（throw）是主防线；写后红灯靠日志 + 出口全量门禁补。文档（hooks/README.md）已注明
此边界，避免误以为 Cline 侧能做到 Claude 的 additionalContext 注入。

## 四、与其他文件的关系

- 调用的脚本：`scripts/check-style.sh`（增量）；CI 出口全量由 `unit-test-ci-<lang>` 技能承担
- 守卫配置区白名单：与 Claude/Gemini 版同一份路径集合
- 规范流程豁免：`.harness/.applying` 标记（与其余宿主语义一致）