#!/usr/bin/env bash
# PreToolUse hook — 写文件前校验 change 状态机 + 配置区守卫
#
# 默认：仅注入提示（allow），不阻断——避免误伤 Hotfix / Spike / 纯文档裁剪场景。
# 严格模式：GATE_STRICT=1 时，无流程中 change 却写源码 → block 该工具调用。
# 配置区直改（.harness/{hooks,scripts,rules,gate-config.json}）：一律 block（所有宿主对齐）。
# 克隆区（.harness/clone/）为配置区只读快照，缺失时自动复制生成，不报错。
set -uo pipefail

INPUT="$(cat)"
GATE_STRICT="${GATE_STRICT:-0}"

# 提取本次写改的目标文件
FILE="$(printf '%s' "$INPUT" | node -e '
let s=""; process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  try {
    const j=JSON.parse(s);
    const ti=(j && j.tool_input)||{};
    let p=ti.file_path||ti.filePath||ti.path||"";
    if(!p && Array.isArray(ti.edits) && ti.edits[0]) p=ti.edits[0].path||"";
    process.stdout.write(p);
  } catch(e){ process.exit(0); }
});' 2>/dev/null)"

[ -z "$FILE" ] && exit 0

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # 项目根（本脚本位于 .harness/hooks/，上两级）
CLONE_DIR="$HARNESS_DIR/.harness/clone"

exit_json() {
  # Claude Code hooks JSON 回执（stdout 只输出 JSON）
  node -e 'const o=JSON.parse(process.argv[1]);process.stdout.write(JSON.stringify(o));' "$1" 2>/dev/null || true
}

# 克隆区维护：配置区只读快照，缺失时自动复制生成（不报错）
ensure_clone() {
  [ -d "$CLONE_DIR" ] && return 0
  mkdir -p "$CLONE_DIR"
  for d in hooks scripts rules; do
    [ -d "$HARNESS_DIR/.harness/$d" ] && cp -R "$HARNESS_DIR/.harness/$d" "$CLONE_DIR/$d" 2>/dev/null
  done
  [ -f "$HARNESS_DIR/.harness/gate-config.json" ] && cp "$HARNESS_DIR/.harness/gate-config.json" "$CLONE_DIR/gate-config.json" 2>/dev/null
  : > "$CLONE_DIR/.synced-at"
}

is_config_zone() {
  case "$FILE" in
    .harness/hooks/*|.harness/hooks|.harness/scripts/*|.harness/scripts|.harness/rules/*|.harness/rules|.harness/gate-config.json|.harness/动态事实来源.md) return 0 ;;
  esac
  return 1
}

# 守卫 1：配置区（对照克隆区快照；apply-harness 规范流程经 .harness/.applying 标记豁免）
if is_config_zone; then
  ensure_clone
  SNAP="$CLONE_DIR/${FILE#.harness/}"
  if [ -f "$HARNESS_DIR/.harness/.applying" ]; then
    # apply-harness 规范流程写入：放行 + 增量同步克隆区（保持基线=现网，防后续直改比对失准）
    mkdir -p "$(dirname "$SNAP")" 2>/dev/null
    [ -f "$HARNESS_DIR/$FILE" ] && cp "$HARNESS_DIR/$FILE" "$SNAP" 2>/dev/null
    exit_json '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"[门禁] 允许配置区写入（apply-harness 规范流程，克隆区基线已同步）"}}'
    exit 0
  fi
  MSG=""
  DECISION="block"
  if [ ! -f "$SNAP" ]; then
    MSG="[门禁] 目标 $FILE 属 Harness 配置区（新增文件）：配置变更请通过 harness-standard / apply-harness 走规范流程，不要直改模板"
  elif ! diff -q "$HARNESS_DIR/$FILE" "$SNAP" >/dev/null 2>&1; then
    MSG="[门禁] 目标 $FILE 与规范快照不一致（配置已被直改）：正在 block。配置变更请通过 harness-standard / apply-harness 走规范流程"
  else
    MSG="[门禁] 目标 $FILE 属配置区且与规范快照一致：如需变更请走规范流程"
    DECISION="allow"
  fi
  exit_json "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"decision\":\"$DECISION\",\"reason\":\"$MSG\",\"additionalContext\":\"$MSG\"}}"
  exit 0
fi

# 守卫 2：状态机（仅对非配置区源码生效；.harness 自身文档与产物目录不受状态机限制）
# 注: 守卫 2 不检查 .harness/.applying 标记——标记只豁免配置区写入（守卫 1），源码防呆提示照常。
case "$FILE" in
  .harness/*|vendor/*|node_modules/*|target/*|dist/*|build/*) exit 0 ;;
esac

CHANGES_DIR="$HARNESS_DIR/.harness/changes"

# 当前所有 change 的状态集合
STATES="$(grep -h -m1 -E '^status:' "$CHANGES_DIR"/*/change.md 2>/dev/null \
  | sed 's/^status:[[:space:]]*//' | tr -d '[:space:]' | sort -u | tr '\n' ' ')"

# 允许写源码的状态（coding 实现 / testing 测试完善 / reviewing 评审修复）
HAS_ACTIVE=0
for s in $STATES; do
  case "$s" in coding|testing|reviewing) HAS_ACTIVE=1 ;; esac
done

if [ "$HAS_ACTIVE" -eq 0 ]; then
  MSG="[门禁·状态机] 当前没有处于 coding/testing/reviewing 的 change，但你正在写源码文件 $FILE。请先 /harnessing 建卡并在 change.md 更新状态；若属 Hotfix/Spike/纯文档裁剪，请在 change.md 显式记录该直改。"
  if [ "$GATE_STRICT" = "1" ]; then
    node -e 'const o={hookSpecificOutput:{hookEventName:"PreToolUse",decision:"block",reason:process.argv[1],additionalContext:process.argv[1]}};process.stdout.write(JSON.stringify(o));' "$MSG" 2>/dev/null || true
  else
    node -e 'const o={hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:process.argv[1]}};process.stdout.write(JSON.stringify(o));' "$MSG" 2>/dev/null || true
  fi
fi
exit 0
