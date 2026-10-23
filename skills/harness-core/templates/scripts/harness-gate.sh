#!/usr/bin/env bash
# 确定性门禁总入口 — .harness/scripts/harness-gate.sh
#
# 用法: harness-gate.sh <gate> [file|all] [change-id]
#   gate: check-style | static-analysis | coverage | arch-check | security-scan | review-check
#   [file|all]: 仅 check-style / static-analysis 使用（static-analysis 无单文件模式，all 固定）
#   [change-id]: 证据落盘目录；coverage/arch-check/security-scan/review-check 为单参脚本，
#                第二参可直接作 change-id 传入（兼容 `harness-gate.sh coverage <id>` 两参调用）
#
# 退出码: 0=通过  1=违规  2=工具未安装/无法测量(显式降级)  3=用法错误
set -uo pipefail

GATE="${1:?用法: harness-gate.sh <gate> [file|all] [change-id]}"
TARGET="${2:-all}"
CHANGE_ID="${3:-}"

# 解析 .harness 根目录（本脚本位于 .harness/scripts/ 下）
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$HARNESS_DIR/scripts"

case "$GATE" in
  check-style)      exec "$SCRIPTS_DIR/check-style.sh" "$TARGET" "$CHANGE_ID" ;;
  static-analysis) exec "$SCRIPTS_DIR/static-analysis.sh" all "${3:-${2:-}}" ;;
  coverage)        exec "$SCRIPTS_DIR/coverage.sh" "${3:-${2:-}}" ;;
  arch-check)      exec "$SCRIPTS_DIR/arch-check.sh" "${3:-${2:-}}" ;;
  security-scan)   exec "$SCRIPTS_DIR/security-scan.sh" "${3:-${2:-}}" ;;
  review-check)    exec "$SCRIPTS_DIR/review-check.sh" "${3:-${2:-}}" ;;
  *)
    echo "未知门禁: $GATE（可选: check-style | static-analysis | coverage | arch-check | security-scan | review-check）" >&2
    exit 3
    ;;
esac
