#!/usr/bin/env bash
# 代码风格深度检测 — check-style.sh [file|all] [change-id]
#
# file: 单文件增量检测（PostToolUse 每次写文件后触发，快速内置检查）
# all:  全量深度检测（Stop / 技能出口 / ⑤ CI 触发，跑 {{LINT_CMD}}）
#
# 退出码: 0=通过  1=违规  2=工具未安装(显式降级)  3=用法错误
set -uo pipefail

TARGET="${1:-all}"
CHANGE_ID="${2:-}"
LINT_CMD="{{LINT_CMD}}"
LINT_TOOL="{{LINT_TOOL}}"
FILE_LIMIT="{{FILE_LIMIT}}"

# ---------- 内置增量检查（单文件，任何语言通用） ----------
check_file() {
  local f="$1" limit="${FILE_LIMIT:-800}" lines
  if [ ! -f "$f" ]; then
    echo "[FAIL] 文件不存在: $f" >&2
    return 1
  fi
  lines="$(wc -l < "$f" | tr -d ' ')"
  if [ "${lines:-0}" -gt "$limit" ]; then
    echo "[FAIL] 单文件行数超限: $f 共 $lines 行（上限 $limit）"
    return 1
  fi
  # 尾随空白（输出命中位置，不丢弃）
  TRAIL="$(grep -nE '[ \t]+$' "$f" | head -5)"
  if [ -n "$TRAIL" ]; then
    printf '[FAIL] 尾随空白: %s\n%s\n' "$f" "$TRAIL"
    return 1
  fi
  # TODO/FIXME 遗留在非注释场景（简单启发式：整行 TODO/FIXME 且非许可证头）
  TODO_HITS="$(grep -nE '^\s*(TODO|FIXME|XXX|HACK)' "$f" | head -5)"
  if [ -n "$TODO_HITS" ]; then
    printf '[FAIL] 未清理的 TODO/FIXME: %s\n%s\n' "$f" "$TODO_HITS"
    return 1
  fi
  # 硬编码凭据（排除环境变量引用）
  if grep -nE 'password\s*=\s*["\x27]|secret\s*=\s*["\x27]|api[_-]?key\s*=\s*["\x27]' "$f" \
      | grep -vE '\$\{|getenv|os\.environ|System\.getenv' | head -5 > /dev/null; then
    echo "[FAIL] 疑似硬编码凭据: $f（首 5 处见上）"
    return 1
  fi
  echo "[OK] $f 通过增量检查（$lines 行）"
  return 0
}

# ---------- 全量深度检测 ----------
check_all() {
  local failed=0 degraded=0
  echo "== 全量代码风格深度检测 =="
  if [ -z "$LINT_CMD" ] || [ "$LINT_CMD" = "未验证" ]; then
    echo "[DEGRADED] check-style 工具未安装（$LINT_TOOL），该门禁降级人工核对（依据 .harness/rules/编码规范.md）"
    degraded=1
  elif ! command -v "${LINT_CMD%% *}" >/dev/null 2>&1; then
    echo "[DEGRADED] check-style 命令不可用（$LINT_CMD 首词未安装），该门禁降级人工核对"
    degraded=1
  else
    # 预检底层依赖（运行器/工具/项目组件声明）——避免缺插件导致的 BUILD FAILURE 被误判为风格违规
    local dep_rc
    "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check lint >/dev/null 2>&1
    dep_rc=$?
    if [ "$dep_rc" -ne 0 ]; then
      echo "[DEGRADED] check-style 底层依赖未就绪（rc=$dep_rc）——该门禁降级人工核对，缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check lint"
      degraded=1
    else
      echo "-- 运行: $LINT_CMD"
      if ! eval "$LINT_CMD"; then
        echo "[FAIL] {{LINT_CMD}} 检测到违规"
        failed=1
      else
        echo "[OK] {{LINT_TOOL}} 全量通过"
      fi
    fi
  fi

  # 全量行数上限扫描（git 跟踪文件，排除 .harness 与常见产物目录）
  echo "-- 单文件行数上限扫描（≤$FILE_LIMIT 行）"
  local over=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local l; l="$(wc -l < "$f" | tr -d ' ')"
    if [ "${l:-0}" -gt "$FILE_LIMIT" ]; then
      echo "[FAIL] $f: $l 行（上限 $FILE_LIMIT）"
      over=1
    fi
  done < <(git ls-files 2>/dev/null | grep -vE '^\.harness/|^(vendor|node_modules|target|dist|build|\.venv|venv)/' || true)
  [ "$over" -eq 1 ] && failed=1

  [ "$failed" -eq 1 ] && return 1
  [ "$degraded" -eq 1 ] && return 2
  echo "[PASS] check-style 全量通过"
  return 0
}

# ---------- 入口 ----------
if [ "$TARGET" = "all" ]; then
  rc=0; check_all || rc=$?
  if [ -n "$CHANGE_ID" ]; then
    "$(dirname "${BASH_SOURCE[0]}")/report.sh" check-style "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
  fi
  exit "$rc"
fi

# 单文件：先跑内置增量检查；若 {{LINT_CMD}} 可用，额外补跑一次全量 lint（可能较慢，失败仅提示不阻断；
# 深度清零由出口门禁 / Stop hook 的全量检测承担）
rc=0
check_file "$TARGET" || rc=$?
if [ "$rc" -eq 0 ] && [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "未验证" ] && command -v "${LINT_CMD%% *}" >/dev/null 2>&1; then
  if eval "$LINT_CMD" > /dev/null 2>&1; then
    echo "[OK] {{LINT_TOOL}} 单文件调用通过"
  else
    # 全量 lint 失败可能是存量问题，只提示不阻断单文件增量
    echo "[WARN] {{LINT_TOOL}} 全量仍有告警（存量或新引入，需在出口门禁前清零）"
  fi
fi
exit "$rc"
