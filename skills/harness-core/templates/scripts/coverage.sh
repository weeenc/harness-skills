#!/usr/bin/env bash
# 覆盖率门禁 — coverage.sh [change-id]
#
# 跑 {{COV_CMD}} 并判定核心逻辑覆盖率 ≥ 80%（阈值可在 .harness/gate-config.json 的 coverage_threshold 调整）。
# 覆盖率阈值可在 .harness/gate-config.json 的 "coverage_threshold" 覆盖。
#
# 退出码: 0=通过  1=未达标  2=工具未安装(显式降级)  3=用法错误
set -uo pipefail

CHANGE_ID="${1:-}"
COV_CMD="{{COV_CMD}}"
COV_TOOL="{{COV_TOOL}}"
THRESHOLD="80"

# 可选配置覆盖
GATE_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gate-config.json"
if [ -f "$GATE_CONFIG" ]; then
  T="$(node -e 'const c=require(process.argv[1]);process.stdout.write(String(c.coverage_threshold||80))' "$GATE_CONFIG" 2>/dev/null || echo 80)"
  [ -n "$T" ] && THRESHOLD="$T"
fi

echo "== 覆盖率门禁（{{COV_TOOL}}，核心逻辑 ≥ ${THRESHOLD}%） =="
if [ -z "$COV_CMD" ] || [ "$COV_CMD" = "未验证" ]; then
  echo "[DEGRADED] coverage 工具未安装（{{COV_TOOL}}），**无法测量覆盖率**，该门禁降级人工核对（依据 unit-test-write 的 AC 覆盖清单）"
  rc=2
elif ! command -v "${COV_CMD%% *}" >/dev/null 2>&1; then
  echo "[DEGRADED] coverage 命令不可用（$COV_CMD 首词未安装），**无法测量覆盖率**，该门禁降级人工核对（依据 unit-test-write 的 AC 覆盖清单）"
  rc=2
elif ! "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check cov >/dev/null 2>&1; then
  echo "[DEGRADED] coverage 底层依赖未就绪（如 JaCoCo 插件未在 pom.xml 声明）——**无法测量覆盖率**，该门禁降级人工核对；缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check cov"
  rc=2
else
  echo "-- 运行: $COV_CMD"
  OUT="$(eval "$COV_CMD" 2>&1)"
  CMD_RC=$?
  printf '%s\n' "$OUT" | tail -25
  if [ "$CMD_RC" -ne 0 ]; then
    echo "[FAIL] $COV_CMD 执行失败或未达标（rc=$CMD_RC）——若工具已内嵌阈值判定（如 go test -cover），按命令结果为准"
    rc=1
  else
    # 辅助阈值判定：优先锚定汇总行（coverage:/All files/TOTAL/Statements/总覆盖率），
    # 避免表格类工具（jest/pytest --cov 等）把首行单文件百分比误当合计；
    # 汇总行数字允许带 %（go）或不带 %（jest/coverage.py 管道表格）
    PCT="$(printf '%s\n' "$OUT" \
      | grep -E 'coverage:|All files|TOTAL|Statements|总覆盖率' \
      | head -1 \
      | grep -oE '[0-9]+(\.[0-9]+)?%?' | head -1 | tr -d '%')"
    ANCHORED=0
    [ -n "$PCT" ] && ANCHORED=1
    if [ -z "$PCT" ]; then
      # 无汇总行：退回启发式（首百分比），输出 WARN 标注
      PCT="$(printf '%s\n' "$OUT" | grep -oE '[0-9]+(\.[0-9]+)?%' | head -1 | tr -d '%')"
    fi
    if [ -n "$PCT" ] && [ "$ANCHORED" -eq 0 ]; then
      echo "[WARN] 未匹配到汇总行（coverage:/All files/TOTAL），按输出首个百分比启发式判定"
    fi
    if [ -z "$PCT" ]; then
      echo "[DEGRADED] 无法从命令输出解析覆盖率百分比（无汇总行也无百分比）——无法自动判定，请按 {{COV_TOOL}} 报告人工核对"
      rc=2
    elif awk -v p="$PCT" -v t="$THRESHOLD" 'BEGIN{exit !(p+0 < t+0)}'; then
      echo "[FAIL] 覆盖率 $PCT% 低于阈值 ${THRESHOLD}%"
      rc=1
    else
      echo "[PASS] 覆盖率 $PCT% 达标（阈值判定以 {{COV_TOOL}} 报告为准）"
      rc=0
    fi
  fi
fi

if [ -n "$CHANGE_ID" ]; then
  "$(dirname "${BASH_SOURCE[0]}")/report.sh" coverage "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
fi
exit "$rc"
