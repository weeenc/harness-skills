#!/usr/bin/env bash
# 评审报告结构门禁 — review-check.sh [change-id]
#
# 校验 .harness/changes/<id>/review.md 的双轴结构合规性：
#   1) 文件存在
#   2) 含 `## Spec 轴报告` 与 `## Standards 轴报告` 两个轴节头（前缀匹配，兼容带括号后缀）
#   3) 总览含"审查范围"标注
#   4) 两轴各有 `### 🔴 严重问题` 节；非空 🔴 列表项的每一行须带引用
#      （规范文件 .md / 行号 / L\d+ / hunk / change.md，保证结论可回溯）
#
# 说明: 本门禁只机械断言"报告结构"，双轴内容质量由评审子智能体负责。
#       降级路径（宿主无 subagent 原语）同样要求节头与引用合规——结构与降级无关。
#
# 退出码: 0=通过  1=违规  3=用法错误
set -uo pipefail

CHANGE_ID="${1:-}"
if [ -z "$CHANGE_ID" ]; then
  echo "用法: review-check.sh <change-id>" >&2
  exit 3
fi

REVIEW_FILE=".harness/changes/${CHANGE_ID}/review.md"
echo "== 评审报告结构门禁 (review-check) =="
echo "-- 检查: ${REVIEW_FILE}"

failed=0

# 1) 文件存在
if [ ! -f "$REVIEW_FILE" ]; then
  echo "[FAIL] review.md 不存在: ${REVIEW_FILE}"
  exit 1
fi

# 2) 双轴节头（前缀匹配，兼容 `## Spec 轴报告（需求匹配）` 等后缀写法）
SPEC_HEADER="$(grep -nE '^## Spec 轴报告' "$REVIEW_FILE" | head -1 || true)"
STD_HEADER="$(grep -nE '^## Standards 轴报告' "$REVIEW_FILE" | head -1 || true)"
if [ -z "$SPEC_HEADER" ]; then
  echo "[FAIL] 缺少 '## Spec 轴报告' 节（双轴子智能体未派发或报告不完整）"
  failed=1
else
  echo "[OK] Spec 轴节头: ${SPEC_HEADER}"
fi
if [ -z "$STD_HEADER" ]; then
  echo "[FAIL] 缺少 '## Standards 轴报告' 节（双轴子智能体未派发或报告不完整）"
  failed=1
else
  echo "[OK] Standards 轴节头: ${STD_HEADER}"
fi

# 3) 总览含"审查范围"
if grep -q '审查范围' "$REVIEW_FILE"; then
  echo "[OK] 总览已标注审查范围"
else
  echo "[FAIL] 总览缺少 '审查范围' 标注"
  failed=1
fi

# 4) 两轴 🔴 节存在 + 非空引用校验
for AXIS in "Spec 轴报告" "Standards 轴报告"; do
  # 该轴下是否有 🔴 严重问题节
  RED_SECTION="$(awk -v axis="$AXIS" '
    $0 ~ "^## " axis { in_axis=1; next }
    in_axis && $0 ~ /^## / { in_axis=0 }
    in_axis && $0 ~ /^### 🔴 严重问题/ { found=1; next }
    in_axis && found && /^### / { found=0 }
    in_axis && found && /^[-*] / { print }
  ' "$REVIEW_FILE")"
  if [ -n "$RED_SECTION" ]; then
    # 非空 🔴 条目行必须带引用特征（.md 引用 / 具体行号 L\d+ / hunk: / change.md）
    # 注意: 裸"行号"字样不作数（可能只是叙述性文字），须是 .md 文件引用或 L\d+ 具体行号或 hunk: 前缀
    BAD="$(printf '%s\n' "$RED_SECTION" | grep -vE '\.md[:： ]|[Ll][0-9]+|hunk[:：]|change\.md' || true)"
    if [ -n "$BAD" ]; then
      echo "[FAIL] ${AXIS} 的 🔴 严重问题存在无引用条目（须注明 规范文件.md / L<行号> / hunk: / change.md）:"
      printf '%s\n' "$BAD" | head -10
      failed=1
    else
      echo "[OK] ${AXIS} 的 🔴 条目均已带引用"
    fi
  else
    # 节头缺失与节内无 🔴 条目无法区分：以节头为准（节头存在即合规，可为空=0 严重问题）
    if grep -qE "^## ${AXIS}" "$REVIEW_FILE" && awk -v axis="$AXIS" '
        $0 ~ "^## " axis { in_axis=1; next }
        in_axis && $0 ~ /^## / { in_axis=0 }
        in_axis && $0 ~ /^### 🔴 严重问题/ { found=1 }
        in_axis && found { print }
      ' "$REVIEW_FILE" | grep -q '^### 🔴 严重问题'; then
      echo "[OK] ${AXIS} 的 🔴 严重问题节为空（0 严重问题）"
    elif grep -qE "^## ${AXIS}" "$REVIEW_FILE"; then
      echo "[OK] ${AXIS} 未报告 🔴 严重问题"
    else
      echo "[FAIL] ${AXIS} 缺少 🔴 严重问题节"
      failed=1
    fi
  fi
done

# 5) 汇总退出
if [ "$failed" -eq 1 ]; then
  echo "[FAIL] review-check 未通过"
  exit 1
fi

echo "[PASS] review-check 通过"
exit 0