#!/usr/bin/env bash
# 门禁证据落盘 — report.sh <gate> [change-id] [备注...]
#
# 把门禁执行结果写入 .harness/changes/<id>/gate-<gate>.md（markdown），
# 供 harness-status / harness-quality / harness-retro 对账审计。
#
# change-id 缺省时自动选中状态机匹配的 change（status ∈ coding/testing/reviewing/ci/verifying）。
set -uo pipefail

GATE="${1:?用法: report.sh <gate> [change-id] [备注...]}"
CHANGE_ID="${2:-}"
NOTE="${3:-}"

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGES_DIR="$HARNESS_DIR/changes"

# 自动选择 change：优先 status 处于流程中（coding/testing/reviewing/ci）的
if [ -z "$CHANGE_ID" ]; then
  for f in "$CHANGES_DIR"/*/change.md; do
    [ -f "$f" ] || continue
    st="$(grep -m1 -E '^status:' "$f" | sed 's/^status:[[:space:]]*//' | tr -d '[:space:]')"
    case "$st" in
      coding|testing|reviewing|ci|verifying)
        CHANGE_ID="$(basename "$(dirname "$f")")"
        break
        ;;
    esac
  done
fi

if [ -z "$CHANGE_ID" ]; then
  echo "[report] 未找到流程中的 change，证据未落盘" >&2
  exit 0
fi

CHANGE_DIR="$CHANGES_DIR/$CHANGE_ID"
mkdir -p "$CHANGE_DIR"

# 汇总最近一次门禁 stdout/stderr（从调用方传入的 rc 及备注推断）
RC="${NOTE#rc=}"
[ "$RC" = "$NOTE" ] && RC="unknown"

OUT="$CHANGE_DIR/gate-$GATE.md"
{
  echo "# 门禁证据: $GATE"
  echo ""
  echo "- 变更: \`$CHANGE_ID\`"
  echo "- 时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- 结果: rc=$RC"
  if [ "$RC" = "2" ]; then
    echo "- 状态: **DEGRADED（工具未安装，降级人工核对）**"
  elif [ "$RC" = "1" ]; then
    echo "- 状态: **FAIL（红灯，禁止进入下一阶段）**"
  else
    echo "- 状态: PASS"
  fi
  [ -n "$NOTE" ] && echo "- 备注: $NOTE"
  echo ""
  echo "> 本文件由 \`.harness/scripts/report.sh\` 自动生成，供对账审计；人工复核结论请追加在下方。"
} > "$OUT"

echo "[report] 证据已落盘: $OUT"
exit 0
