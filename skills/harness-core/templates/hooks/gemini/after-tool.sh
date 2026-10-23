#!/usr/bin/env bash
# Gemini CLI AfterTool hook — 写文件后的单文件增量深度检测
#
# 协议（官方 geminicli.com/docs/hooks/）：
#   stdin : 单 JSON 对象；stdout: Golden Rule —— 只输出一个最终 JSON 对象
#   systemMessage 立即显示；hookSpecificOutput.additionalContext 注入上下文（红灯让模型看到）
#   退出码 0（不阻断写操作；阻断走 before-tool.sh 的 decision:"deny"）
set -uo pipefail

INPUT="$(cat)"

# 提取 tool_name 与写改文件路径
PAIR="$(printf '%s' "$INPUT" | node -e '
let s=""; process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  try {
    const j=JSON.parse(s);
    const ti=(j&&j.tool_input)||{};
    let p="";
    for (const k of ["file_path","filePath","path"]) { if (typeof ti[k]==="string") { p=ti[k]; break; } }
    console.log((j.tool_name||"")+"\n"+p);
  } catch { console.log("\n"); }
});' 2>/dev/null)"
TOOL_NAME="${PAIR%%$'\n'*}"
FILE_PATH="${PAIR#*$'\n'}"

case "$TOOL_NAME" in
  write_file|replace|apply_patch|patch|edit|write|edit_file) ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0
if [ ! -f "$FILE_PATH" ]; then
  printf '%s' '{"hookSpecificOutput":{"additionalContext":"[门禁·增量] 未找到文件: '"$FILE_PATH"'"}}'
  exit 0
fi

# 增量检测（失败/红灯不阻断，结果注入上下文）
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # 项目根（.harness/hooks/gemini/ 上三级）
OUT="$(bash "$HARNESS_DIR/.harness/scripts/harness-gate.sh" check-style "$FILE_PATH" 2>&1 || true)"

printf '%s' "$OUT" | node -e '
let s=""; process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  const t=s.trim();
  const red=/\b(FAIL|DEGRADED)\b/.test(t);
  process.stdout.write(JSON.stringify({
    systemMessage: red ? "[门禁·增量·红灯] 本次写改存在风格违规或降级，请修复后再继续" : "[门禁·增量] 本次写改文件已通过增量检测",
    hookSpecificOutput: { additionalContext: "[门禁·增量] "+process.argv[1]+"\n"+t }
  }, null, 0));
});' "$FILE_PATH" 2>/dev/null || echo '{"systemMessage":"[门禁·增量] 检测完成（结果注入失败）"}'
exit 0