#!/usr/bin/env bash
# 架构约束门禁 — arch-check.sh [change-id]
#
# 跑 {{ARCH_TEST_CMD}} 校验模块依赖方向 / 分层不越级等。
#
# 退出码: 0=通过  1=违规  2=工具未安装(显式降级)  3=用法错误
set -uo pipefail

CHANGE_ID="${1:-}"
ARCH_TEST_CMD="{{ARCH_TEST_CMD}}"
ARCH_TEST_TOOL="{{ARCH_TEST_TOOL}}"

echo "== 架构约束门禁（{{ARCH_TEST_TOOL}}） =="
if [ -z "$ARCH_TEST_CMD" ] || [ "$ARCH_TEST_CMD" = "未验证" ]; then
  echo "[DEGRADED] arch-check 工具未安装（{{ARCH_TEST_TOOL}}），架构约束降级人工评审（依据 .harness/rules/工程结构.md 铁律）"
  rc=2
elif ! command -v "${ARCH_TEST_CMD%% *}" >/dev/null 2>&1; then
  echo "[DEGRADED] arch-check 命令不可用（$ARCH_TEST_CMD 首词未安装），架构约束降级人工评审（依据 .harness/rules/工程结构.md 铁律）"
  rc=2
elif ! "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check arch >/dev/null 2>&1; then
  echo "[DEGRADED] arch-check 底层依赖未就绪——架构约束降级人工评审；缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check arch"
  rc=2
else
  echo "-- 运行: $ARCH_TEST_CMD"
  if ! eval "$ARCH_TEST_CMD"; then
    echo "[FAIL] 架构约束违规（依赖方向 / 分层越级）"
    rc=1
  else
    echo "[PASS] 架构约束通过"
    rc=0
  fi
fi

if [ -n "$CHANGE_ID" ]; then
  "$(dirname "${BASH_SOURCE[0]}")/report.sh" arch-check "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
fi
exit "$rc"
