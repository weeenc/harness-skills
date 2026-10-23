#!/usr/bin/env bash
# Gemini CLI BeforeTool hook — 写文件前的门禁守卫
#
# 协议（官方 geminicli.com/docs/hooks/）：
#   stdin : 单 JSON（session_id/transcript_path/cwd/hook_event_name/timestamp + tool_name/tool_input）
#   stdout: Golden Rule —— 只输出一个最终 JSON 对象（decision: allow|deny, reason, systemMessage）
#   退出码: 0=正常（意图性阻断用 JSON decision 表达）；2=System Block（stderr 为理由）
set -uo pipefail

INPUT="$(cat)"

# 解析 tool_name 与待写文件路径（tool_input 内 file_path/filePath/path）
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

# matcher 已按写工具过滤；脚本内再兜底（不处理非写工具）
case "$TOOL_NAME" in
  write_file|replace|apply_patch|patch|edit|write|edit_file) ;;
  *) exit 0 ;;
esac

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # 项目根（本脚本位于 .harness/hooks/gemini/，上三级）
CLONE_DIR="$HARNESS_DIR/.harness/clone"

# 克隆区维护：.harness/{hooks,scripts,rules,gate-config.json} 的只读快照。
# 缺失时自动复制生成（绝不报错跳过）——克隆区用于检测配置区被 AI 直改。
ensure_clone() {
  [ -d "$CLONE_DIR" ] && return 0
  mkdir -p "$CLONE_DIR"
  for d in hooks scripts rules; do
    [ -d "$HARNESS_DIR/.harness/$d" ] && cp -R "$HARNESS_DIR/.harness/$d" "$CLONE_DIR/$d"
  done
  [ -f "$HARNESS_DIR/.harness/gate-config.json" ] && cp "$HARNESS_DIR/.harness/gate-config.json" "$CLONE_DIR/gate-config.json"
  : > "$CLONE_DIR/.synced-at"
}

CONFIG_ZONE() {
  case "$FILE_PATH" in
    .harness/hooks/*|.harness/hooks|.harness/scripts/*|.harness/scripts|.harness/rules/*|.harness/rules|.harness/gate-config.json|.harness/动态事实来源.md) return 0 ;;
  esac
  return 1
}

# 守卫 1：配置区（对照克隆区快照；apply-harness 规范流程经 .harness/.applying 标记豁免）
if CONFIG_ZONE; then
  ensure_clone
  SNAP="$CLONE_DIR/${FILE_PATH#.harness/}"
  if [ -f "$HARNESS_DIR/.harness/.applying" ]; then
    # apply-harness 规范流程写入：放行 + 增量同步克隆区（保持基线=现网）
    mkdir -p "$(dirname "$SNAP")" 2>/dev/null
    [ -f "$HARNESS_DIR/$FILE_PATH" ] && cp "$HARNESS_DIR/$FILE_PATH" "$SNAP" 2>/dev/null
    echo '{"decision":"allow","systemMessage":"[门禁] 允许配置区写入（apply-harness 规范流程，克隆区基线已同步）"}'
    exit 0
  fi
  if [ ! -f "$SNAP" ]; then
    # 配置区新增文件 = 直改，deny（提示走规范流程）
    node -e 'process.stdout.write(JSON.stringify({decision:"deny",reason:"[门禁] Harness 配置区新增文件 "+process.argv[1]+"：配置变更请通过 harness-standard / apply-harness 走规范流程，不要直改模板"}))' "$FILE_PATH" 2>/dev/null || echo '{"decision":"deny","reason":"[门禁] 配置区新增被阻止，请走规范流程"}'
    exit 0
  fi
  if ! diff -q "$HARNESS_DIR/$FILE_PATH" "$SNAP" >/dev/null 2>&1; then
    # 现网配置与快照不一致（已被改动）→ deny
    node -e 'process.stdout.write(JSON.stringify({decision:"deny",reason:"[门禁] Harness 配置区文件 "+process.argv[1]+" 与规范快照不一致——配置变更请通过 harness-standard / apply-harness 走规范流程，正在阻止进一步直改"}))' "$FILE_PATH" 2>/dev/null || echo '{"decision":"deny","reason":"[门禁] 配置区直改被阻止，请走规范流程"}'
    exit 0
  fi
  # 与快照一致（重复写入同一内容）→ 放行但提示
  node -e 'process.stdout.write(JSON.stringify({decision:"allow",systemMessage:"[门禁] 目标 "+process.argv[1]+" 属配置区且与本规范快照一致，如需变更请走规范流程"}))' "$FILE_PATH" 2>/dev/null || echo '{"decision":"allow"}'
  exit 0
fi

# 守卫 2：流程提示（有进行中的 change 时提示其 id，无则提示先建 change；活跃状态集与 stop.sh 一致）
ACTIVE_CHANGE="$(ls -d "$HARNESS_DIR"/.harness/changes/*/ 2>/dev/null | while read -r d; do
  id="$(basename "$d")"
  [ "$id" = "_TEMPLATE" ] && continue
  st="$(sed -n 's/^status:[[:space:]]*//p' "$d"change.md 2>/dev/null | head -1 | tr -d '\r')"
  case "$st" in coding|testing|reviewing|ci|verifying) printf '%s' "$id"; break ;; esac
done)"

if [ -n "$ACTIVE_CHANGE" ]; then
  node -e 'process.stdout.write(JSON.stringify({decision:"allow",systemMessage:"[门禁] 当前进行中 change: "+process.argv[1]}))' "$ACTIVE_CHANGE" 2>/dev/null || echo '{"decision":"allow"}'
else
  echo '{"decision":"allow","systemMessage":"[门禁] 未检测到进行中 change——源码改动应先在 .harness/changes/<id>/ 建变更卡（/harnessing）"}'
fi
exit 0