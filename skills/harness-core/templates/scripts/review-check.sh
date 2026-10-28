#!/usr/bin/env bash
# review-check.sh <change-id>
# compact: report.md 的④章节（全栈通过 report_ref）；legacy: review.md。
# 只验证记录结构，不代替独立评审、0严重问题判断和阶段推进。
set -uo pipefail
CHANGE_ID="${1:-}"
[[ "$CHANGE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo '用法: review-check.sh <change-id>' >&2; exit 3; }
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 3
CHANGE_DIR="$HARNESS_DIR/changes/$CHANGE_ID"
CARD="$CHANGE_DIR/change.md"
[ -f "$CARD" ] || CARD="$CHANGE_DIR/workspace-change.md"
[ -f "$CARD" ] || { echo '[FAIL] 变更卡不存在'; exit 1; }

# 本协议字段使用单行 YAML scalar，可用引号包裹；不执行字段内容。
field() {
  awk -v key="$1" '
    /^---$/ { n++; next }
    n==1 && index($0, key ":")==1 {
      sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]+#.*/, ""); sub(/[[:space:]]+$/, "")
      gsub(/^"|"$/, ""); gsub(/^\047|\047$/, ""); print; exit
    }' "$2"
}
MODE="$(field artifact_mode "$CARD")"
REF="$(field report_ref "$CARD")"
WS_ID="$(field workspace_change "$CARD")"
if [ "$MODE" = compact ]; then
  REVIEW_FILE="$CHANGE_DIR/report.md"
  if [ -n "$WS_ID" ]; then
    [[ "$WS_ID" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo '[FAIL] 非法 workspace_change'; exit 1; }
    [ -n "$REF" ] || { echo '[FAIL] 全栈执行卡缺少 report_ref'; exit 1; }
  fi
  if [ -n "$REF" ]; then
    case "$REF" in /*|*://*) echo '[FAIL] report_ref 必须是相对文件路径'; exit 1 ;; esac
    [ -n "$WS_ID" ] || { echo '[FAIL] report_ref 缺少 workspace_change'; exit 1; }
    [ "$(basename "$REF")" = report.md ] || { echo '[FAIL] report_ref 必须指向 report.md'; exit 1; }
    SHARED_DIR="$(cd "$CHANGE_DIR/$(dirname "$REF")" 2>/dev/null && pwd)" || { echo '[FAIL] report_ref 目录不存在'; exit 1; }
    WS_CARD="$SHARED_DIR/workspace-change.md"
    if [ ! -f "$WS_CARD" ] || [ "$(field id "$WS_CARD")" != "$WS_ID" ] || [ "$(field artifact_mode "$WS_CARD")" != compact ]; then
      echo '[FAIL] report_ref 的工作空间卡 ID 或产物模式不匹配'; exit 1
    fi
    REVIEW_FILE="$SHARED_DIR/report.md"
  fi
  [ -f "$REVIEW_FILE" ] || { echo '[FAIL] 六阶段报告不存在'; exit 1; }
  # 限定在④章节，避免其他阶段出现相同文字导致误判。
  REVIEW="$(awk '/^## ④ 专家评审[[:space:]]*$/ { active=1; next } active && /^## / { exit } active { print }' "$REVIEW_FILE")"
  printf '%s\n' "$REVIEW" | grep -qx 'review_status: complete' || { echo '[FAIL] ④评审未完成（review_status 不是 complete）'; exit 1; }
  # 统一为 legacy 的标题深度，以下校验共用。
  REVIEW="$(printf '%s\n' "$REVIEW" | sed 's/^###/##/')"
elif [ -z "$MODE" ] || [ "$MODE" = legacy ]; then
  REVIEW_FILE="$CHANGE_DIR/review.md"
  [ -f "$REVIEW_FILE" ] || { echo '[FAIL] legacy review.md 不存在'; exit 1; }
  REVIEW="$(cat "$REVIEW_FILE")"
else
  echo "[FAIL] 不支持的 artifact_mode: $MODE"; exit 1
fi
printf '== 评审结构检查: %s ==\n' "$REVIEW_FILE"
failed=0
printf '%s\n' "$REVIEW" | grep -q '审查范围' || { echo '[FAIL] 缺少审查范围'; failed=1; }
for AXIS in 'Spec 轴报告' 'Standards 轴报告'; do
  if ! printf '%s\n' "$REVIEW" | grep -qE "^## ${AXIS}([[:space:]（(]|$)"; then
    echo "[FAIL] 缺少 $AXIS"; failed=1; continue
  fi
  AXIS_TEXT="$(printf '%s\n' "$REVIEW" | awk -v axis="$AXIS" '
    index($0, "## " axis)==1 { active=1; next }
    active && /^## / { exit }
    active { print }
  ')"
  if ! printf '%s\n' "$AXIS_TEXT" | grep -q '^### 🔴 严重问题'; then
    echo "[FAIL] $AXIS 缺少严重问题节"; failed=1; continue
  fi
  RED="$(printf '%s\n' "$AXIS_TEXT" | awk '
    /^### 🔴 严重问题/ { active=1; next }
    active && /^### / { exit }
    active && /^[-*] / { print }
  ')"
  # “无”可以不带引用；真实发现必须带代码/规范行号、hunk 或 AC 引用。
  BAD="$(printf '%s\n' "$RED" | grep -vE '^$|^[-*] (无[。.]?|无严重问题[。.]?)$|\.md[:： ]|[Ll][0-9]+|hunk[:：]|AC-[0-9]+' || true)"
  if [ -n "$BAD" ]; then echo "[FAIL] $AXIS 的严重问题缺少引用: $BAD"; failed=1; fi
done
[ "$failed" -eq 0 ] || exit 1
echo '[PASS] review-check 结构通过；评审结论与状态推进另行判断'
