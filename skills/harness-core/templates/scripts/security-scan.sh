#!/usr/bin/env bash
# 安全扫描门禁 — security-scan.sh [change-id]
#
# 跑 {{SECURITY_CMD}}（依赖漏洞扫描）+ 内置硬编码凭据/危险操作扫描。
#
# 退出码: 0=通过  1=违规  2=工具未安装(显式降级)  3=用法错误
set -uo pipefail

CHANGE_ID="${1:-}"
SECURITY_CMD="{{SECURITY_CMD}}"

echo "== 安全扫描门禁 =="
failed=0
degraded=0

# 1) 依赖漏洞扫描（{{SECURITY_CMD}}）
if [ -n "$SECURITY_CMD" ] && [ "$SECURITY_CMD" != "未验证" ] && command -v "${SECURITY_CMD%% *}" >/dev/null 2>&1; then
  echo "-- 运行: $SECURITY_CMD"
  if ! eval "$SECURITY_CMD"; then
    echo "[FAIL] 依赖漏洞扫描发现风险（{{SECURITY_CMD}}）"
    failed=1
  else
    echo "[OK] 依赖漏洞扫描通过"
  fi
elif [ -n "$SECURITY_CMD" ] && [ "$SECURITY_CMD" != "未验证" ] && ! "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check sec >/dev/null 2>&1; then
  echo "[DEGRADED] security-scan 底层依赖未就绪——依赖漏洞扫描降级人工核对；缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check sec"
  degraded=1
else
  echo "[DEGRADED] security-scan 依赖漏洞扫描未配置或不可用（{{SECURITY_CMD}}），该维度降级人工核对（依赖版本一致、禁快照版本）"
  degraded=1
fi

# 2) 内置硬编码凭据扫描（git 跟踪的源码文件；逐文件传参避免路径拆分，空列表短路防 stdin 挂起）
echo "-- 硬编码凭据扫描（排除环境变量引用）"
SEC_FILES="$(git ls-files 2>/dev/null | grep -E '\.(java|go|py|rs|php|js|ts|jsx|tsx|vue|properties|yml|yaml)$' || true)"
if [ -n "$SEC_FILES" ]; then
  HITS="$(printf '%s\n' "$SEC_FILES" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -nE "password[[:space:]]*=[[:space:]]*[\"'][^$]|secret[[:space:]]*=[[:space:]]*[\"'][^$]|api[_-]?key[[:space:]]*=[[:space:]]*[\"'][^$]" "$f" 2>/dev/null
  done | grep -vE '\$\{|getenv|os\.environ|System\.getenv|example|mock' || true)"
  if [ -n "$HITS" ]; then
    printf '%s\n' "$HITS" | head -20
    echo "[FAIL] 发现疑似硬编码凭据（见上）"
    failed=1
  else
    echo "[OK] 未发现硬编码凭据"
  fi
else
  echo "[OK] 无待扫描文件（git 未跟踪源码或仓库为空）"
fi

rc=0
[ "$failed" -eq 1 ] && rc=1
[ "$degraded" -eq 1 ] && [ "$failed" -eq 0 ] && rc=2

if [ -n "$CHANGE_ID" ]; then
  "$(dirname "${BASH_SOURCE[0]}")/report.sh" security-scan "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
fi

[ "$rc" -eq 2 ] && { echo "[DEGRADED] security-scan 存在降级维度，需人工核对"; exit 2; }
[ "$rc" -eq 1 ] && { echo "[FAIL] security-scan 未通过"; exit 1; }
echo "[PASS] security-scan 通过"
exit 0
