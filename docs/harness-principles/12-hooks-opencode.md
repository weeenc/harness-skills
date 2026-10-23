# 宿主 hooks：OpenCode（12）

> 对应实现：`hooks/opencode/harness-plugin.ts`（渲染为 `.opencode/plugins/harness-plugin.ts`，
> OpenCode 启动时自动加载）
>
> OpenCode 也是 **TS 插件体系**：`Plugin` 函数返回事件处理器映射，宿主按阶段回调。
> 比 Cline 多一个 `session.idle` 出口挂点（可做每轮回复结束的全量检测）。

## 一、hook 是如何触发的

```ts
export const HarnessPlugin: Plugin = async ({ client, $ }) => {
  return {
    "tool.execute.before": async (input, output) => { … },   // 工具执行【前】
    "tool.execute.after":  async (input, output) => { … },   // 工具执行【后】
    event: async ({ event }) => { … },                        // 会话事件（含 session.idle）
  }
}
```

| 挂点 | 触发时刻 | 取什么 |
|---|---|---|
| `tool.execute.before` | 工具执行前 | `input.tool`（工具名）、`output.args`（参数对象） |
| `tool.execute.after` | 工具执行后 | 同上 |
| `event` | 会话事件流 | `event.type === "session.idle"`（≈ 一轮回复结束） |

写工具白名单 `WRITE_TOOLS`：`write / edit / patch / multiedit / write_file / edit_file`
（OpenCode 原生小写命名）。

## 二、如何检测、如何出结果

**tool.execute.before（守卫，硬拦截）**：

1. 非写工具 → 放行。
2. 取目标路径（`args.{filePath,file_path,path}`）。
3. 命中配置区 → `.harness/.applying` 存在放行；否则 **`throw new Error("[门禁] 禁止直接修改 Harness 配置区 …")`**
   —— before 阶段抛错可**硬阻断**违规写操作（依据官方文档能力边界）。
4. 源码文件放行。

**tool.execute.after（增量检测，日志记录）**：

```ts
const r = await $`bash .harness/scripts/check-style.sh ${p}`.quiet().nothrow()
await client.app.log({ body: {
  service: "harness",
  level: r.exitCode === 0 ? "info" : "warn",
  message: `[门禁·增量] ${p} rc=${r.exitCode} ${r.stdout…}` } })
```

配置区文件跳过（避免与 before 守卫双重报告）。红灯 → `level: "warn"` 记入 IDE 日志面板。

**event → session.idle（出口全量检测）**：

```ts
const r = await $`bash .harness/scripts/harness-gate.sh check-style all`.quiet().nothrow()
await client.app.log({ body: { service: "harness", level: "info",
  message: `[门禁·出口] rc=${r.exitCode}\n${r.stdout…(前 2000 字符)}` } })
```

会话空闲 ≈ 一轮回复结束：全量风格检测记日志（截断到 2000 字符防刷屏）。

## 三、结果不满足时如何报错

| 情形 | 表现 | 语义 |
|---|---|---|
| 直改配置区 | `throw` → 写操作被**硬阻断** | 硬拦截 ✅ |
| 增量红灯 / 出口 rc≠0 | `client.app.log`（level: warn / info，含 rc 与结论） | 软提示——**OpenCode 插件暂无上下文注入通道**，红灯阻断以 before 守卫为主，深度检测由脚本层与 CI 技能兜底 |

**能力边界（与 Cline 同族差异）**：OpenCode 有 `client.app.log` 可以优雅记日志（Cline 只能
console.log），且多一个 `session.idle` 出口挂点能做全量复核；两者都没有「注入模型上下文」通道，
所以写前 throw 守卫是 OpenCode 侧的主防线，其余交给 `unit-test-ci`/`deploy-verify` 技能出口门禁。

## 四、与其他文件的关系

- 调用的脚本：`scripts/check-style.sh`（增量）、`scripts/harness-gate.sh check-style all`（出口）
- 守卫配置区白名单：与其余宿主同一份路径集合
- 规范流程豁免：`.harness/.applying` 标记
- 与 Cline 版的关系：同设计模式、不同宿主事件名与日志通道（对照 [11-hooks-cline.md](11-hooks-cline.md)）