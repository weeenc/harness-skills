#!/usr/bin/env bash
# Stop hook — 每个回复结束时做全量深度检测 + 证据落盘
#
# 只在「存在流程中 change 且本轮有源码变更」时执行，避免空转拖慢会话。
# 结果经 additionalContext 注入下一轮，AI 无法装作没看见。
set -uo pipefail

INPUT="$(cat)"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"    # 项目根（本脚本位于 .harness/hooks/，上两级）
SCRIPTS="$HARNESS_DIR/.harness/scripts"

# 1) 是否存在流程中 change（coding/testing/reviewing/ci/verifying）
ACTIVE_FILE="$(grep -l -E '^status:[[:space:]]*(coding|testing|reviewing|ci|verifying)' "$HARNESS_DIR"/.harness/changes/*/change.md 2>/dev/null | head -1)"
[ -z "$ACTIVE_FILE" ] && exit 0
CHANGE_ID="$(basename "$(dirname "$ACTIVE_FILE")")"

# 2) 本轮是否有源码变更（git diff 非空 或 存在未提交的非 .harness 文件）
if git diff --quiet HEAD 2>/dev/null; then
  if [ -z "$(git status --porcelain 2>/dev/null | grep -vE '^\?\? \.harness/|^.. \.harness/' | head -1)" ]; then
    exit 0
  fi
fi

[ -f "$SCRIPTS/harness-gate.sh" ] || exit 0

SUMMARY=""
run_gate() {
  local name="$1" out rc
  out="$(bash "$SCRIPTS/harness-gate.sh" "$name" all "$CHANGE_ID" 2>&1)"
  rc=$?
  SUMMARY="$SUMMARY
[$name] rc=$rc
$(printf '%s' "$out" | head -40)"
}

run_gate check-style
run_gate static-analysis
run_gate security-scan

if [ -n "$SUMMARY" ]; then
  HEADER="[门禁·出口] 本轮全量深度检测（change: $CHANGE_ID）—— rc=0 通过 / rc=1 红灯需修复 / rc=2 工具未安装已显式降级需人工核对："
  node -e 'const o={hookSpecificOutput:{hookEventName:"Stop",additionalContext:process.argv[1]+"\n"+process.argv[2]}};process.stdout.write(JSON.stringify(o));' "$HEADER" "$SUMMARY" 2>/dev/null || true
fi
exit 0
