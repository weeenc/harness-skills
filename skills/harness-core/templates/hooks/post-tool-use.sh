#!/usr/bin/env bash
# PostToolUse hook — 每次 Write/Edit/MultiEdit 后对写改文件做增量深度检测
#
# 宿主引擎自动执行（.claude/settings.json 配置），stdin 接收 Claude Code hooks JSON。
# 检测脚本不可用时静默跳过（不阻断会话）；检测违规时把红灯注入 AI 上下文。
set -uo pipefail

INPUT="$(cat)"

# 从 tool_input 提取本次写改的文件路径（Write.file_path / Edit.path / MultiEdit.edits[].path）
FILES="$(printf '%s' "$INPUT" | node -e '
let s=""; process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  try {
    const j=JSON.parse(s);
    const ti=(j && j.tool_input)||{};
    const paths=new Set();
    const add=v=>{ if(typeof v==="string" && v.length>0 && !v.startsWith("[")) paths.add(v); };
    if(ti.file_path) add(ti.file_path);
    if(ti.filePath) add(ti.filePath);
    if(ti.path) add(ti.path);
    if(Array.isArray(ti.edits)) ti.edits.forEach(e=>{ if(e && e.path) add(e.path); });
    console.log([...paths].join("\n"));
  } catch(e){ process.exit(0); }
});' 2>/dev/null)"

[ -z "$FILES" ] && exit 0

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"    # 项目根（本脚本位于 .harness/hooks/，上两级）
SCRIPTS="$HARNESS_DIR/.harness/scripts"
[ -f "$SCRIPTS/check-style.sh" ] || exit 0

RESULTS=""
RC_ALL=0
while IFS= read -r f; do
  case "$f" in
    .harness/*|vendor/*|node_modules/*|target/*|dist/*|build/*|\.venv/*|venv/*) continue ;;
  esac
  [ -f "$f" ] || continue
  OUT="$(bash "$SCRIPTS/check-style.sh" "$f" 2>&1)"
  r=$?
  RESULTS="$RESULTS
$OUT"
  [ "$r" -ne 0 ] && RC_ALL=1
done <<< "$FILES"

if [ -n "$RESULTS" ]; then
  if [ "$RC_ALL" -eq 0 ]; then
    ADD="[门禁·增量] 本次写改文件已通过风格增量检测：${RESULTS}"
  else
    ADD="[门禁·增量·红灯] 本次写改文件存在风格违规，请修复后再继续：${RESULTS}"
  fi
  node -e 'const o={hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:process.argv[1]}};process.stdout.write(JSON.stringify(o));' "$ADD" 2>/dev/null || true
fi
exit 0
