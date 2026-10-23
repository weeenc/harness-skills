#!/usr/bin/env bash
# 静态缺陷分析 — static-analysis.sh [file|all] [change-id]
#
# 全量深度检测（Stop / 技能出口 / ⑤ CI 触发，跑 {{VET_CMD}} 与 {{LINT_CMD}} 的缺陷检查维度）
#
# 退出码: 0=通过  1=违规  2=工具未安装(显式降级)  3=用法错误
set -uo pipefail

TARGET="${1:-all}"
CHANGE_ID="${2:-}"
VET_CMD="{{VET_CMD}}"
LINT_CMD="{{LINT_CMD}}"
LINT_TOOL="{{LINT_TOOL}}"

echo "== 静态缺陷分析（{{LINT_TOOL}} / {{VET_CMD}}） =="
degraded=0
failed=0

if [ -n "$VET_CMD" ] && [ "$VET_CMD" != "未验证" ] && command -v "${VET_CMD%% *}" >/dev/null 2>&1; then
  if "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check vet >/dev/null 2>&1; then
    echo "-- 运行: $VET_CMD"
    if ! eval "$VET_CMD"; then
      echo "[FAIL] $VET_CMD 发现静态缺陷"
      failed=1
    else
      echo "[OK] $VET_CMD 通过"
    fi
  else
    echo "[DEGRADED] static-analysis 底层依赖未就绪——该维度降级人工核对；缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check vet"
    degraded=1
  fi
else
  echo "[DEGRADED] static-analysis 静态分析命令未配置或不可用（{{VET_CMD}}），该维度降级人工核对"
  degraded=1
fi

# {{LINT_CMD}} 中已含的缺陷维度（如 PMD/SpotBugs/staticcheck）在 check-style.sh 全量中已跑，
# 此处仅提示不重复执行；若 LINT_TOOL 未安装或底层依赖未就绪则一并显式降级。
if [ -z "$LINT_CMD" ] || [ "$LINT_CMD" = "未验证" ] || ! command -v "${LINT_CMD%% *}" >/dev/null 2>&1 || ! "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check lint >/dev/null 2>&1; then
  echo "[DEGRADED] static-analysis 依赖的 {{LINT_TOOL}} 未安装或底层依赖未就绪，缺陷检查降级人工核对"
  degraded=1
fi

rc=0
[ "$failed" -eq 1 ] && rc=1
[ "$degraded" -eq 1 ] && [ "$failed" -eq 0 ] && rc=2

if [ -n "$CHANGE_ID" ]; then
  "$(dirname "${BASH_SOURCE[0]}")/report.sh" static-analysis "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
fi

[ "$rc" -eq 2 ] && { echo "[DEGRADED] static-analysis 存在降级维度，需人工核对"; exit 2; }
[ "$rc" -eq 1 ] && { echo "[FAIL] static-analysis 未通过"; exit 1; }
echo "[PASS] static-analysis 通过"
exit 0
