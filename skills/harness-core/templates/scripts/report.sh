#!/usr/bin/env bash
# report.sh <gate> [change-id] [rc=N 备注...]
# 每类门禁只保留最新运行摘要；阶段结论由技能写入持久报告。
set -uo pipefail

GATE="${1:-}"
CHANGE_ID="${2:-}"
NOTE="${*:3}"
[[ "$GATE" =~ ^[a-z][a-z0-9-]*$ ]] || { echo '[report] 非法或缺失 gate' >&2; exit 3; }
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 3
CHANGES_DIR="$HARNESS_DIR/changes"

# 只在唯一候选时自动选择，避免将结果写进另一项需求。
if [ -z "$CHANGE_ID" ]; then
  candidates=()
  for f in "$CHANGES_DIR"/*/change.md "$CHANGES_DIR"/*/workspace-change.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$(dirname "$f")")" != _TEMPLATE ] || continue
    st="$(awk '/^---$/ { n++; next } n==1 && /^status:/ { sub(/^status:[[:space:]]*/, ""); sub(/[[:space:]]*#.*/, ""); print; exit }' "$f")"
    case "$st" in
      coding|testing|reviewing|ci|verifying|implementing|integrating)
        candidates+=("$(basename "$(dirname "$f")")") ;;
    esac
  done
  if [ "${#candidates[@]}" -eq 0 ]; then
    echo '[report] 未找到执行中的 change，未生成摘要' >&2
    exit 0
  fi
  [ "${#candidates[@]}" -eq 1 ] || { echo '[report] 多个活动 change，请显式传入 ID' >&2; exit 3; }
  CHANGE_ID="${candidates[0]}"
fi
[[ "$CHANGE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] && [ "$CHANGE_ID" != _TEMPLATE ] || { echo '[report] 非法 change ID' >&2; exit 3; }
if [ ! -f "$CHANGES_DIR/$CHANGE_ID/change.md" ] && [ ! -f "$CHANGES_DIR/$CHANGE_ID/workspace-change.md" ]; then
  echo "[report] 变更卡不存在: $CHANGE_ID" >&2
  exit 3
fi

RC=unknown
if [[ "$NOTE" =~ ^rc=(-?[0-9]+)($|[[:space:]]) ]]; then RC="${BASH_REMATCH[1]}"; fi
case "$RC" in
  0) RESULT=PASS ;;
  1) RESULT=FAIL ;;
  2) RESULT=DEGRADED ;;
  *) RESULT=ERROR ;;
esac

# 只添加本协议的忽略项，保留项目原有规则。
IGNORE="$CHANGES_DIR/.gitignore"
if ! grep -qxF '/.runtime/' "$IGNORE" 2>/dev/null; then
  printf '\n/.runtime/\n' >> "$IGNORE" || exit 1
fi
RUN_DIR="$CHANGES_DIR/.runtime/$CHANGE_ID"
mkdir -p "$RUN_DIR" || exit 1
OUT="$RUN_DIR/gate-$GATE.md"
TMP="$(mktemp "$RUN_DIR/.gate-$GATE.XXXXXX")" || exit 1
trap 'rm -f "$TMP"' EXIT
{
  printf '# 门禁运行摘要: %s\n\n' "$GATE"
  printf -- '- 变更: `%s`\n' "$CHANGE_ID"
  printf -- '- 时间: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf -- '- 结果: rc=%s\n- 状态: %s\n' "$RC" "$RESULT"
  [ -z "$NOTE" ] || printf -- '- 备注: %s\n' "$NOTE"
  printf '\n> 自动更新的本地摘要，不包含完整命令输出。阶段结束时将真实命令、版本、关键证据及人工确认写入需求报告；不要在本文件追加人工记录。\n'
} > "$TMP" || exit 1
mv "$TMP" "$OUT" || exit 1
printf '[report] 最新运行摘要: %s (%s)\n' "$OUT" "$RESULT"
