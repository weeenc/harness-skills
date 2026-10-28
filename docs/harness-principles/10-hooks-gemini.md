# 宿主 hooks：Gemini CLI（10）

> 对应实现：`hooks/gemini/before-tool.sh` `hooks/gemini/after-tool.sh` `hooks/gemini/session-end.sh`
> + `hooks/gemini/settings.json.tpl`（渲染进 `.gemini/settings.json`，脚本经 `$GEMINI_PROJECT_DIR` 绝对路径引用）

## 一、hook 是如何触发的（协议差异是关键）

Gemini CLI hooks 的 stdout 遵循 **Golden Rule**：只输出**一个**最终 JSON 对象，任何多余文本
（echo 调试、进度输出）都会导致宿主解析失败。所以三个脚本的全部输出都先逮进变量，最后
一次性 `JSON.stringify` 单对象输出。stdin 为单 JSON（session_id/cwd/tool_name/tool_input…）。

```jsonc
// gemini/settings.json.tpl
{
  "hooks": {
    "BeforeTool": [ { "matcher": "write_file|replace|apply_patch|patch|edit", "hooks": [
      { "name": "harness-guard", "type": "command", "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/before-tool.sh", "timeout": 15000 } ] } ],
    "AfterTool":  [ { "matcher": "write_file|replace|apply_patch|patch|edit", "hooks": [
      { "name": "harness-incremental", "type": "command", "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/after-tool.sh",  "timeout": 60000 } ] } ],
    "SessionEnd": [ { "matcher": "", "hooks": [
      { "name": "harness-exit-gate", "type": "command", "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/session-end.sh", "timeout": 300000 } ] } ]
  }
}
```

| 事件 | matcher | 触发时刻 | 阻断能力 |
|---|---|---|---|
| BeforeTool | 写工具（write_file/replace/apply_patch/patch/edit…） | 工具执行前 | **`decision:"deny"` 可硬拦**；退出码 0=正常、2=System Block |
| AfterTool | 写工具 | 工具执行后 | 无（检测结果注入上下文） |
| SessionEnd | 全部（matcher 空） | 会话结束 | 无（出口汇报） |

## 二、before-tool.sh 如何检测、如何出结果

1. **解析**：stdin JSON 里取 `tool_name` 与 `tool_input.{file_path,filePath,path}`；非写工具名兜底放行。
2. **守卫 1｜配置区**（`.harness/{hooks,scripts,rules,gate-config.json,动态事实来源.md}`）——与
   Claude 版同逻辑同文案，差异在输出协议：
   - `.applying` 标记 → `{"decision":"allow","systemMessage":"…基线已同步"}`；
   - 快照无此文件（新增）→ `{"decision":"deny","reason":"…配置变更请通过 harness-standard / apply-harness 走规范流程…"}`；
   - 不一致 → `{"decision":"deny","reason":"…与规范快照不一致…"}`；
   - 一致 → `{"decision":"allow","systemMessage":"…属配置区且与本规范快照一致，如需变更请走规范流程"}`。
3. **守卫 2｜流程提示**：扫 `.harness/changes/*/change.md` 找进行中 change（状态集与 stop.sh 一致：
   coding/testing/reviewing/ci/verifying）——有 → `allow` + systemMessage 报出 change id；
   无 → `allow` + 「未检测到进行中 change——源码改动应先在 .harness/changes/<id>/ 建变更卡（/harnessing）」。
4. **结果不满足时**：`deny` → 宿主**中止工具调用**、reason 给模型看（配置区直改被硬拦）。

> `ensure_clone()` 与 Claude 版一致：`.harness/clone/` 缺失自动复制，绝不报错跳过——克隆区
> 是检测"配置被直改"的依据，自举后才有得比对。

## 三、after-tool.sh 如何检测、如何出结果

1. 解析写改文件路径（非写工具放行；文件不存在 → additionalContext 提示）。
2. 经总入口跑单文件增量：`bash .harness/hooks/…/harness-gate.sh check-style <file>`（`|| true` 防自身崩）。
3. 单 JSON 输出：

```jsonc
// 全绿
{ "systemMessage": "[门禁·增量] 本次写改文件已通过增量检测",
  "hookSpecificOutput": { "additionalContext": "[门禁·增量] <path>\n<检测输出>" } }
// 红灯（输出含 FAIL 或 DEGRADED）
{ "systemMessage": "[门禁·增量·红灯] 本次写改存在风格违规或降级，请修复后再继续", … }
```

**结果不满足时**：`systemMessage` 立即在终端显示、`additionalContext` 注入上下文，让模型看到
具体违规行自行修复；不阻断写操作（写后检测不回溯）。

## 四、session-end.sh 如何检测、如何出结果

1. 缺 `harness-gate.sh` → `{}` 放行（防未装完整时会话阻塞）。
2. 找活动 change（→ change-id 传给门禁落盘；无则跑无 id 版本，只报不落盘）。
3. 依次跑三个全量门禁并汇总（check-style / static-analysis / security-scan）。
4. 单 JSON 输出，`systemMessage` 按汇总内容分档：

```jsonc
// 含 FAIL      → "【红灯】存在门禁违规，修复后再收尾"
// 含 DEGRADED  → "【降级】部分门禁工具未安装，已显式降级需人工核对"
// 否则         → "【通过】出口全量门禁通过"
// 另注 additionalContext: "[门禁·出口]\n<三个 gate 完整输出>"
```

**结果不满足时**：红灯/降级直接打在 systemMessage 上（会话收尾时模型必然看见），
同时证据已落盘 `gate-*.md` 供审计；出口只汇报不阻断（`exit 0`）——Gemini 的硬拦只在 BeforeTool。
> 新版 report.sh 将 gate 摘要写在 changes/.runtime/<id>/，重复检查只更新固定文件。阶段结束将关键证据与人工确认写 report.md，不提交临时摘要；旧报告保留兼容。详见 [运行摘要协议](08-report.md)。
