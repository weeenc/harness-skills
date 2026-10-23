#!/usr/bin/env bash
# Gemini CLI SessionEnd hook — 会话结束时的出口全量深度检测 + 证据落盘
#
# 协议（官方 geminicli.com/docs/hooks/）：
#   stdin : 单 JSON 对象；stdout: Golden Rule —— 只输出一个最终 JSON 对象
#   systemMessage 立即显示；hookSpecificOutput.additionalContext 注入下一轮上下文
#   退出码 0（出口只汇报不阻断；红灯靠 additionalContext 让模型看到后自行修复）
set -uo pipefail

INPUT="$(cat)"

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # 项目根（.harness/hooks/gemini/ 上三级）
GATE_DIR="$HARNESS_DIR/.harness/scripts"
if [ ! -f "$GATE_DIR/harness-gate.sh" ]; then
  echo '{}'
  exit 0
fi

# 检测流程中活动 change（有则把 change-id 传给门禁，证据落盘到对应目录）
ACTIVE_FILE="$(grep -l -E '^status:[[:space:]]*(coding|testing|reviewing|ci|verifying)' "$HARNESS_DIR"/.harness/changes/*/change.md 2>/dev/null | head -1)"
CHANGE_ID=""
[ -n "$ACTIVE_FILE" ] && CHANGE_ID="$(basename "$(dirname "$ACTIVE_FILE")")"

# 出口门禁：全量代码风格 + 静态分析 + 安全扫描（顺序执行，结果汇总）
R=""
for g in check-style static-analysis security-scan; do
  if [ -n "$CHANGE_ID" ]; then
    out="$(bash "$GATE_DIR/harness-gate.sh" "$g" all "$CHANGE_ID" 2>&1)"
  else
    out="$(bash "$GATE_DIR/harness-gate.sh" "$g" 2>&1)"
  fi
  rc=$?
  R="${R}== ${g} (rc=${rc}) ==${IFS}${out}${IFS}${IFS}"
done

printf '%s' "$R" | node -e '
let s=""; process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  const t=s.trim();
  const red=/\bFAIL\b/.test(t);
  const deg=/\bDEGRADED\b/.test(t);
  const head=red ? "【红灯】存在门禁违规，修复后再收尾"
    : (deg ? "【降级】部分门禁工具未安装，已显式降级需人工核对"
            : "【通过】出口全量门禁通过");
  process.stdout.write(JSON.stringify({
    systemMessage: "[门禁·出口] "+head,
    hookSpecificOutput: { additionalContext: "[门禁·出口]\n"+t }
  }, null, 0));
});' 2>/dev/null || echo '{}'
exit 0